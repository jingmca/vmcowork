.PHONY: help init start stop status test clean install proxy

# Default target
help:
	@echo "Cowork Sandbox - 可用命令:"
	@echo ""
	@echo "  make install    - 安装依赖 (Lima, jq)"
	@echo "  make init       - 初始化 VM"
	@echo "  make start      - 启动 VM"
	@echo "  make stop       - 停止 VM"
	@echo "  make status     - 查看 VM 状态"
	@echo "  make test       - 运行测试套件"
	@echo "  make example    - 运行 Python 示例"
	@echo "  make proxy      - 启动网络代理监控"
	@echo "  make clean      - 删除 VM"
	@echo "  make help       - 显示此帮助信息"

# Install dependencies
install:
	@echo "安装依赖..."
	@command -v brew >/dev/null 2>&1 || { echo "错误: 需要 Homebrew"; exit 1; }
	@command -v limactl >/dev/null 2>&1 || brew install lima
	@command -v jq >/dev/null 2>&1 || brew install jq
	@echo "✓ 依赖安装完成"

# Initialize VM
init:
	@echo "初始化 VM..."
	@./scripts/cowork init

# Start VM
start:
	@echo "启动 VM..."
	@./scripts/cowork start

# Stop VM
stop:
	@echo "停止 VM..."
	@./scripts/cowork stop

# Show status
status:
	@./scripts/cowork status

# Run tests
test:
	@echo "运行测试套件..."
	@./scripts/test.sh

# Run Python example
example:
	@echo "运行 Python 示例..."
	@python3 examples/basic_usage.py

# Start proxy monitor
proxy:
	@echo "启动网络代理监控..."
	@./scripts/cowork proxy -l proxy.log -v

# Clean up VM
clean:
	@echo "警告: 这将删除 VM 和所有数据"
	@read -p "确认删除? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		./scripts/cowork delete; \
	fi

# Setup environment
setup:
	@if [ ! -f .env ]; then \
		echo "创建 .env 文件..."; \
		cp .env.example .env; \
		echo "请编辑 .env 文件并填入 API 凭证"; \
	else \
		echo ".env 文件已存在"; \
	fi
