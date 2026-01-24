#!/usr/bin/env python3
"""
网络代理监控工具

功能：
1. 监控 VM 的网络流量
2. 记录所有 HTTP/HTTPS 请求
3. 提供实时日志和统计信息
4. 支持流量过滤和告警
"""

import os
import sys
import json
import socket
import threading
import logging
import time
from datetime import datetime
from typing import Dict, List, Optional, Set
from dataclasses import dataclass, field, asdict
from collections import defaultdict
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
import http.client


@dataclass
class RequestLog:
    """HTTP 请求日志"""
    timestamp: str
    method: str
    url: str
    host: str
    path: str
    status_code: Optional[int] = None
    response_size: int = 0
    duration_ms: float = 0.0
    error: Optional[str] = None


@dataclass
class ProxyStats:
    """代理统计信息"""
    total_requests: int = 0
    successful_requests: int = 0
    failed_requests: int = 0
    total_bytes: int = 0
    unique_hosts: Set[str] = field(default_factory=set)
    requests_by_host: Dict[str, int] = field(default_factory=lambda: defaultdict(int))
    start_time: float = field(default_factory=time.time)

    def to_dict(self) -> dict:
        """转换为字典（用于 JSON 序列化）"""
        return {
            "total_requests": self.total_requests,
            "successful_requests": self.successful_requests,
            "failed_requests": self.failed_requests,
            "total_bytes": self.total_bytes,
            "unique_hosts": list(self.unique_hosts),
            "requests_by_host": dict(self.requests_by_host),
            "uptime_seconds": time.time() - self.start_time,
        }


class ProxyMonitor:
    """代理监控器"""

    def __init__(self, log_file: Optional[str] = None, verbose: bool = False):
        self.log_file = log_file
        self.verbose = verbose
        self.stats = ProxyStats()
        self.request_logs: List[RequestLog] = []
        self.max_logs = 1000  # 最多保留的日志数量

        # 设置日志
        self.logger = logging.getLogger("ProxyMonitor")
        self.logger.setLevel(logging.DEBUG if verbose else logging.INFO)

        # 控制台输出
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setFormatter(
            logging.Formatter('%(asctime)s [%(levelname)s] %(message)s')
        )
        self.logger.addHandler(console_handler)

        # 文件输出
        if log_file:
            file_handler = logging.FileHandler(log_file)
            file_handler.setFormatter(
                logging.Formatter('%(asctime)s [%(levelname)s] %(message)s')
            )
            self.logger.addHandler(file_handler)

    def log_request(self, req_log: RequestLog):
        """记录请求"""
        # 更新统计信息
        self.stats.total_requests += 1
        self.stats.unique_hosts.add(req_log.host)
        self.stats.requests_by_host[req_log.host] += 1

        if req_log.error:
            self.stats.failed_requests += 1
        else:
            self.stats.successful_requests += 1
            self.stats.total_bytes += req_log.response_size

        # 保存日志
        self.request_logs.append(req_log)
        if len(self.request_logs) > self.max_logs:
            self.request_logs.pop(0)

        # 输出日志
        if req_log.error:
            self.logger.warning(
                f"{req_log.method} {req_log.url} - ERROR: {req_log.error}"
            )
        else:
            self.logger.info(
                f"{req_log.method} {req_log.url} - {req_log.status_code} "
                f"({req_log.response_size} bytes, {req_log.duration_ms:.0f}ms)"
            )

    def get_stats(self) -> dict:
        """获取统计信息"""
        return self.stats.to_dict()

    def get_recent_logs(self, count: int = 100) -> List[dict]:
        """获取最近的日志"""
        return [asdict(log) for log in self.request_logs[-count:]]

    def export_logs(self, output_file: str):
        """导出日志到文件"""
        data = {
            "stats": self.get_stats(),
            "logs": self.get_recent_logs(len(self.request_logs)),
        }
        with open(output_file, 'w') as f:
            json.dump(data, f, indent=2)
        self.logger.info(f"Logs exported to {output_file}")


class ProxyHandler(BaseHTTPRequestHandler):
    """HTTP 代理处理器"""

    monitor: ProxyMonitor = None  # 将由主程序设置

    def do_GET(self):
        """处理 GET 请求"""
        self._proxy_request('GET')

    def do_POST(self):
        """处理 POST 请求"""
        self._proxy_request('POST')

    def do_HEAD(self):
        """处理 HEAD 请求"""
        self._proxy_request('HEAD')

    def do_PUT(self):
        """处理 PUT 请求"""
        self._proxy_request('PUT')

    def do_DELETE(self):
        """处理 DELETE 请求"""
        self._proxy_request('DELETE')

    def do_CONNECT(self):
        """处理 CONNECT 请求（HTTPS 隧道）"""
        # 对于 HTTPS，我们只记录连接，不解密内容
        host, port = self.path.split(':')
        port = int(port)

        req_log = RequestLog(
            timestamp=datetime.now().isoformat(),
            method='CONNECT',
            url=f"https://{host}:{port}",
            host=host,
            path=self.path,
        )

        start_time = time.time()

        try:
            # 建立到目标服务器的连接
            target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            target_socket.connect((host, port))

            # 发送成功响应
            self.send_response(200, 'Connection Established')
            self.end_headers()

            req_log.status_code = 200
            req_log.duration_ms = (time.time() - start_time) * 1000

            # 双向转发数据
            client_socket = self.connection
            self._tunnel(client_socket, target_socket)

        except Exception as e:
            req_log.error = str(e)
            self.send_error(502, f"Proxy Error: {e}")
        finally:
            if self.monitor:
                self.monitor.log_request(req_log)

    def _proxy_request(self, method: str):
        """代理 HTTP 请求"""
        parsed_url = urlparse(self.path)

        # 如果没有 scheme，尝试从 Host 头获取
        if not parsed_url.netloc:
            host = self.headers.get('Host', '')
            path = self.path
        else:
            host = parsed_url.netloc
            path = parsed_url.path or '/'
            if parsed_url.query:
                path += '?' + parsed_url.query

        req_log = RequestLog(
            timestamp=datetime.now().isoformat(),
            method=method,
            url=f"http://{host}{path}",
            host=host,
            path=path,
        )

        start_time = time.time()

        try:
            # 建立连接
            conn = http.client.HTTPConnection(host, timeout=30)

            # 转发请求头
            headers = dict(self.headers)
            headers.pop('Proxy-Connection', None)

            # 读取请求体
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length) if content_length > 0 else None

            # 发送请求
            conn.request(method, path, body=body, headers=headers)

            # 获取响应
            response = conn.getresponse()
            req_log.status_code = response.status

            # 转发响应头
            self.send_response(response.status)
            for header, value in response.getheaders():
                if header.lower() not in ('transfer-encoding',):
                    self.send_header(header, value)
            self.end_headers()

            # 转发响应体
            response_data = response.read()
            req_log.response_size = len(response_data)
            self.wfile.write(response_data)

            req_log.duration_ms = (time.time() - start_time) * 1000

            conn.close()

        except Exception as e:
            req_log.error = str(e)
            req_log.duration_ms = (time.time() - start_time) * 1000
            try:
                self.send_error(502, f"Proxy Error: {e}")
            except:
                pass
        finally:
            if self.monitor:
                self.monitor.log_request(req_log)

    def _tunnel(self, client_socket, target_socket):
        """双向转发数据（用于 HTTPS 隧道）"""
        def forward(source, destination):
            try:
                while True:
                    data = source.recv(8192)
                    if not data:
                        break
                    destination.sendall(data)
            except:
                pass
            finally:
                try:
                    source.close()
                    destination.close()
                except:
                    pass

        # 创建两个线程进行双向转发
        client_to_target = threading.Thread(
            target=forward, args=(client_socket, target_socket)
        )
        target_to_client = threading.Thread(
            target=forward, args=(target_socket, client_socket)
        )

        client_to_target.daemon = True
        target_to_client.daemon = True

        client_to_target.start()
        target_to_client.start()

        # 等待其中一个方向结束
        client_to_target.join()
        target_to_client.join()

    def log_message(self, format, *args):
        """禁用默认日志输出"""
        pass


def run_proxy_server(
    host: str = '0.0.0.0',
    port: int = 7890,
    log_file: Optional[str] = None,
    verbose: bool = False,
):
    """启动代理服务器"""
    # 创建监控器
    monitor = ProxyMonitor(log_file=log_file, verbose=verbose)
    ProxyHandler.monitor = monitor

    # 创建服务器
    server = HTTPServer((host, port), ProxyHandler)

    monitor.logger.info(f"Proxy server listening on {host}:{port}")
    monitor.logger.info(f"Configure VM to use: http://192.168.5.2:{port}")
    if log_file:
        monitor.logger.info(f"Logging to: {log_file}")

    # 启动统计输出线程
    def print_stats():
        while True:
            time.sleep(60)  # 每分钟输出一次统计
            stats = monitor.get_stats()
            monitor.logger.info(
                f"Stats: {stats['total_requests']} requests, "
                f"{stats['unique_hosts']} unique hosts, "
                f"{stats['total_bytes'] / 1024 / 1024:.2f} MB transferred"
            )

    stats_thread = threading.Thread(target=print_stats, daemon=True)
    stats_thread.start()

    # 启动服务器
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        monitor.logger.info("\nShutting down proxy server...")

        # 导出最终日志
        if log_file:
            export_file = log_file.replace('.log', '_export.json')
            monitor.export_logs(export_file)

        server.shutdown()
        monitor.logger.info("Proxy server stopped")


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(
        description='Network Proxy Monitor for Cowork Sandbox'
    )
    parser.add_argument(
        '--host',
        default='0.0.0.0',
        help='Bind address (default: 0.0.0.0)'
    )
    parser.add_argument(
        '--port',
        type=int,
        default=7890,
        help='Bind port (default: 7890)'
    )
    parser.add_argument(
        '--log-file',
        help='Log file path (optional)'
    )
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Enable verbose logging'
    )

    args = parser.parse_args()

    run_proxy_server(
        host=args.host,
        port=args.port,
        log_file=args.log_file,
        verbose=args.verbose,
    )
