# 网络代理监控使用指南

## 功能概述

网络代理监控工具是 Cowork Sandbox Phase 2 的核心功能之一，用于监控和记录虚拟机的网络流量。

## 特性

- **实时监控**：监控所有经过代理的 HTTP/HTTPS 请求
- **详细日志**：记录请求方法、URL、状态码、响应大小、耗时等
- **统计信息**：自动统计请求数量、独立主机、流量大小
- **日志导出**：支持导出 JSON 格式的完整日志
- **HTTPS 支持**：支持 HTTPS CONNECT 隧道（记录连接，不解密）

## 快速开始

### 1. 启动代理监控

```bash
# 基础模式（仅控制台输出）
./scripts/cowork proxy

# 带文件日志
./scripts/cowork proxy -l proxy.log

# 详细模式（更多调试信息）
./scripts/cowork proxy -l proxy.log -v
```

### 2. 在另一个终端中使用 VM

```bash
# 启动 VM（如果还没启动）
./scripts/cowork start

# 使用 Claude Code（流量会被监控）
./scripts/cowork ask "download a webpage with requests"
```

### 3. 查看监控日志

代理监控会实时输出日志：

```
2026-01-25 10:30:15 [INFO] Proxy server listening on 0.0.0.0:7890
2026-01-25 10:30:15 [INFO] Configure VM to use: http://192.168.5.2:7890
2026-01-25 10:31:20 [INFO] GET http://example.com/ - 200 (1256 bytes, 245ms)
2026-01-25 10:31:22 [INFO] CONNECT https://api.anthropic.com:443 - 200 (0 bytes, 102ms)
2026-01-25 10:32:00 [INFO] Stats: 15 requests, 8 unique hosts, 2.45 MB transferred
```

### 4. 停止监控

按 `Ctrl+C` 停止监控。如果启用了日志文件，会自动导出完整日志到 `*_export.json`。

## 工作原理

### 架构

```
┌──────────────────────────────────────────────┐
│             macOS Host                       │
│                                              │
│  ┌────────────────────────────────────────┐ │
│  │  proxy_monitor.py (0.0.0.0:7890)       │ │
│  │  - 监听代理请求                         │ │
│  │  - 记录流量日志                         │ │
│  │  - 统计信息                             │ │
│  └────────────┬───────────────────────────┘ │
└───────────────┼─────────────────────────────┘
                │ HTTP Proxy
┌───────────────┼─────────────────────────────┐
│  Ubuntu VM    ▼                             │
│                                              │
│  http_proxy=http://192.168.5.2:7890         │
│  https_proxy=http://192.168.5.2:7890        │
│                                              │
│  ┌────────────────────────────────────────┐ │
│  │  Claude Code / curl / wget / pip       │ │
│  │  所有网络请求通过代理                    │ │
│  └────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

### 处理流程

1. **HTTP 请求**：
   - VM 发送请求到代理（192.168.5.2:7890）
   - 代理解析请求，转发到目标服务器
   - 记录请求和响应信息
   - 将响应返回给 VM

2. **HTTPS 请求**：
   - VM 发送 CONNECT 请求建立隧道
   - 代理建立到目标服务器的连接
   - 记录连接信息（不解密内容）
   - 双向转发加密数据

## 日志格式

### 控制台输出

```
2026-01-25 10:31:20 [INFO] GET http://example.com/page - 200 (1256 bytes, 245ms)
                             ↑    ↑                        ↑    ↑          ↑
                          方法   URL                   状态码  大小       耗时
```

### JSON 导出格式

```json
{
  "stats": {
    "total_requests": 150,
    "successful_requests": 145,
    "failed_requests": 5,
    "total_bytes": 5242880,
    "unique_hosts": 12,
    "requests_by_host": {
      "api.anthropic.com": 50,
      "pypi.org": 30,
      "github.com": 20
    },
    "uptime_seconds": 3600
  },
  "logs": [
    {
      "timestamp": "2026-01-25T10:31:20.123456",
      "method": "GET",
      "url": "http://example.com/page",
      "host": "example.com",
      "path": "/page",
      "status_code": 200,
      "response_size": 1256,
      "duration_ms": 245.3,
      "error": null
    }
  ]
}
```

## 使用场景

### 1. 安全审计

监控 Claude Code 访问了哪些外部资源：

```bash
# 启动监控并记录日志
./scripts/cowork proxy -l security_audit.log

# 让 Claude 执行任务
./scripts/cowork ask "install some python packages"

# 查看访问了哪些站点
grep "unique_hosts" security_audit_export.json
```

### 2. 性能分析

分析网络请求的性能：

```bash
# 启动详细监控
./scripts/cowork proxy -l perf.log -v

# 执行任务
./scripts/cowork ask "download data from multiple APIs"

# 查看慢请求
grep "duration_ms" perf_export.json | sort -rn | head -10
```

### 3. 故障排查

查看网络请求失败的原因：

```bash
# 启动监控
./scripts/cowork proxy -l debug.log -v

# 执行可能失败的任务
./scripts/cowork ask "fetch data from unavailable API"

# 查看错误
grep "ERROR" debug.log
```

### 4. 流量统计

了解数据使用情况：

```bash
# 监控一段时间
./scripts/cowork proxy -l traffic.log

# 任务结束后查看统计
cat traffic_export.json | jq '.stats'
```

## 高级用法

### 自定义端口

如果 7890 端口被占用，可以修改 `sandbox.yaml`：

```yaml
env:
  http_proxy: "http://192.168.5.2:8888"
  https_proxy: "http://192.168.5.2:8888"
```

然后使用自定义端口启动：

```bash
python3 host/proxy_monitor.py --port 8888
```

### 程序化使用

在 Python 脚本中使用：

```python
from host.proxy_monitor import run_proxy_server
import threading

# 在后台线程启动代理
proxy_thread = threading.Thread(
    target=run_proxy_server,
    kwargs={
        'host': '0.0.0.0',
        'port': 7890,
        'log_file': 'my_proxy.log',
        'verbose': True
    },
    daemon=True
)
proxy_thread.start()

# 执行其他任务
# ...
```

### 过滤和分析

使用 jq 分析导出的日志：

```bash
# 统计每个主机的请求数
cat proxy_export.json | jq '.stats.requests_by_host'

# 查找失败的请求
cat proxy_export.json | jq '.logs[] | select(.error != null)'

# 查找慢请求（>1秒）
cat proxy_export.json | jq '.logs[] | select(.duration_ms > 1000)'

# 统计流量最大的请求
cat proxy_export.json | jq '.logs[] | select(.response_size > 0) | {url, size: .response_size}' | jq -s 'sort_by(.size) | reverse | .[0:10]'
```

## 限制和注意事项

### 当前限制

1. **HTTPS 内容不可见**：
   - HTTPS 使用 CONNECT 隧道，内容加密
   - 只能看到连接到了哪个主机，无法看到具体请求内容
   - 如需查看 HTTPS 内容，需要使用 mitmproxy（需要证书配置）

2. **日志数量限制**：
   - 内存中最多保留 1000 条日志
   - 超过后会丢弃旧日志
   - 可通过修改 `max_logs` 参数调整

3. **性能影响**：
   - 代理会增加少量延迟（通常 <50ms）
   - 对大文件传输可能有明显影响

### 安全考虑

1. **代理暴露在网络上**：
   - 默认监听 `0.0.0.0`，可被同网络设备访问
   - 建议仅在本地网络使用
   - 生产环境应添加认证

2. **日志包含敏感信息**：
   - URL 可能包含 token 或密钥
   - 建议保护日志文件权限
   - 不要将日志上传到公共位置

## 故障排查

### 代理无法启动

```bash
# 检查端口是否被占用
lsof -i :7890

# 如果被占用，杀死进程或使用其他端口
kill <PID>
# 或
python3 host/proxy_monitor.py --port 8888
```

### VM 无法连接代理

```bash
# 检查 VM 是否正在运行
./scripts/cowork status

# 测试代理连接
./scripts/cowork exec "curl -x http://192.168.5.2:7890 http://example.com"

# 检查环境变量
./scripts/cowork exec "env | grep proxy"
```

### 日志文件未生成

```bash
# 确保有写权限
touch test.log && rm test.log

# 使用绝对路径
./scripts/cowork proxy -l /tmp/proxy.log
```

## 后续改进

Phase 3 计划中的改进：

- [ ] 支持 HTTPS 解密（mitmproxy 模式）
- [ ] Web UI 实时查看流量
- [ ] 流量统计图表
- [ ] 告警规则（访问可疑域名）
- [ ] 流量重放功能
- [ ] 更详细的性能分析

## 参考资料

- [HTTP 代理原理](https://developer.mozilla.org/en-US/docs/Web/HTTP/Proxy_servers_and_tunneling)
- [CONNECT 方法](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/CONNECT)
- [mitmproxy 文档](https://docs.mitmproxy.org/)
