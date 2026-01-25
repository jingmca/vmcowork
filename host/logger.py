#!/usr/bin/env python3
"""
Cowork Sandbox 日志系统

提供统一的日志接口，支持：
- 控制台输出
- 文件日志
- 结构化日志（JSON）
- 日志级别控制
- 日志归档
"""

import os
import sys
import json
import logging
import logging.handlers
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, Any
from dataclasses import dataclass, asdict


@dataclass
class LogConfig:
    """日志配置"""
    log_dir: str = "~/.cowork/logs"
    console_level: str = "INFO"
    file_level: str = "DEBUG"
    max_bytes: int = 10 * 1024 * 1024  # 10MB
    backup_count: int = 5
    json_format: bool = False


class CoworkLogger:
    """Cowork Sandbox 日志器"""

    def __init__(self, name: str, config: Optional[LogConfig] = None):
        self.name = name
        self.config = config or LogConfig()
        self.logger = logging.getLogger(name)
        self.logger.setLevel(logging.DEBUG)
        self.logger.handlers = []  # 清空已有 handlers

        # 确保日志目录存在
        self.log_dir = Path(self.config.log_dir).expanduser()
        self.log_dir.mkdir(parents=True, exist_ok=True)

        # 设置处理器
        self._setup_console_handler()
        self._setup_file_handler()

        if self.config.json_format:
            self._setup_json_handler()

    def _setup_console_handler(self):
        """设置控制台处理器"""
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(getattr(logging, self.config.console_level))

        # 彩色格式
        console_format = ColoredFormatter(
            '%(asctime)s [%(levelname)s] %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        console_handler.setFormatter(console_format)
        self.logger.addHandler(console_handler)

    def _setup_file_handler(self):
        """设置文件处理器（带日志轮转）"""
        log_file = self.log_dir / f"{self.name}.log"

        file_handler = logging.handlers.RotatingFileHandler(
            log_file,
            maxBytes=self.config.max_bytes,
            backupCount=self.config.backup_count,
            encoding='utf-8'
        )
        file_handler.setLevel(getattr(logging, self.config.file_level))

        file_format = logging.Formatter(
            '%(asctime)s [%(levelname)s] %(name)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        file_handler.setFormatter(file_format)
        self.logger.addHandler(file_handler)

    def _setup_json_handler(self):
        """设置 JSON 格式处理器"""
        json_file = self.log_dir / f"{self.name}.json.log"

        json_handler = logging.handlers.RotatingFileHandler(
            json_file,
            maxBytes=self.config.max_bytes,
            backupCount=self.config.backup_count,
            encoding='utf-8'
        )
        json_handler.setLevel(logging.DEBUG)
        json_handler.setFormatter(JsonFormatter())
        self.logger.addHandler(json_handler)

    def debug(self, msg: str, **kwargs):
        """调试日志"""
        self._log(logging.DEBUG, msg, kwargs)

    def info(self, msg: str, **kwargs):
        """信息日志"""
        self._log(logging.INFO, msg, kwargs)

    def warning(self, msg: str, **kwargs):
        """警告日志"""
        self._log(logging.WARNING, msg, kwargs)

    def error(self, msg: str, **kwargs):
        """错误日志"""
        self._log(logging.ERROR, msg, kwargs)

    def critical(self, msg: str, **kwargs):
        """严重错误日志"""
        self._log(logging.CRITICAL, msg, kwargs)

    def _log(self, level: int, msg: str, extra: Dict[str, Any]):
        """内部日志方法"""
        if extra:
            # 将额外信息附加到消息
            extra_str = " | ".join(f"{k}={v}" for k, v in extra.items())
            msg = f"{msg} | {extra_str}"
        self.logger.log(level, msg)

    def log_operation(self, operation: str, status: str, **details):
        """记录操作日志"""
        msg = f"Operation: {operation} | Status: {status}"
        if details:
            detail_str = " | ".join(f"{k}={v}" for k, v in details.items())
            msg += f" | {detail_str}"
        self.info(msg)

    def log_error(self, operation: str, error: Exception, **context):
        """记录错误日志"""
        msg = f"Operation: {operation} | Error: {type(error).__name__}: {error}"
        if context:
            context_str = " | ".join(f"{k}={v}" for k, v in context.items())
            msg += f" | {context_str}"
        self.error(msg)


class ColoredFormatter(logging.Formatter):
    """彩色日志格式化器"""

    COLORS = {
        'DEBUG': '\033[36m',      # Cyan
        'INFO': '\033[32m',       # Green
        'WARNING': '\033[33m',    # Yellow
        'ERROR': '\033[31m',      # Red
        'CRITICAL': '\033[35m',   # Magenta
    }
    RESET = '\033[0m'

    def format(self, record):
        # 保存原始 levelname
        levelname = record.levelname
        # 添加颜色
        if levelname in self.COLORS:
            record.levelname = f"{self.COLORS[levelname]}{levelname}{self.RESET}"
        # 格式化
        result = super().format(record)
        # 恢复原始 levelname
        record.levelname = levelname
        return result


class JsonFormatter(logging.Formatter):
    """JSON 格式化器"""

    def format(self, record):
        log_data = {
            'timestamp': datetime.fromtimestamp(record.created).isoformat(),
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
            'module': record.module,
            'function': record.funcName,
            'line': record.lineno,
        }

        if record.exc_info:
            log_data['exception'] = self.formatException(record.exc_info)

        return json.dumps(log_data, ensure_ascii=False)


# 全局日志器实例
_loggers: Dict[str, CoworkLogger] = {}


def get_logger(name: str, config: Optional[LogConfig] = None) -> CoworkLogger:
    """获取日志器实例（单例模式）"""
    if name not in _loggers:
        _loggers[name] = CoworkLogger(name, config)
    return _loggers[name]


# 便捷函数
def debug(msg: str, **kwargs):
    """全局调试日志"""
    get_logger('cowork').debug(msg, **kwargs)


def info(msg: str, **kwargs):
    """全局信息日志"""
    get_logger('cowork').info(msg, **kwargs)


def warning(msg: str, **kwargs):
    """全局警告日志"""
    get_logger('cowork').warning(msg, **kwargs)


def error(msg: str, **kwargs):
    """全局错误日志"""
    get_logger('cowork').error(msg, **kwargs)


def critical(msg: str, **kwargs):
    """全局严重错误日志"""
    get_logger('cowork').critical(msg, **kwargs)


if __name__ == '__main__':
    # 测试日志系统
    print("Testing logger system...\n")

    # 测试基础日志
    logger = get_logger('test', LogConfig(console_level='DEBUG'))

    logger.debug("This is a debug message")
    logger.info("This is an info message")
    logger.warning("This is a warning message")
    logger.error("This is an error message")
    logger.critical("This is a critical message")

    # 测试带额外信息的日志
    logger.info("VM operation", vm_name="sandbox", operation="start")

    # 测试操作日志
    logger.log_operation("vm_start", "success", vm_name="sandbox", duration="2.5s")
    logger.log_operation("vm_start", "failed", vm_name="sandbox", error="timeout")

    # 测试错误日志
    try:
        raise ValueError("Test error")
    except Exception as e:
        logger.log_error("test_operation", e, context="unit test")

    print(f"\n✓ Logs written to: {logger.log_dir}")
