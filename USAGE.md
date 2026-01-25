# VMCowork 使用指南

## 快速开始

### 安装

```bash
curl -fsSL https://raw.githubusercontent.com/jingmca/vmcowork/main/install.sh | bash
```

### 配置 API

```bash
# 添加到 ~/.zshrc 或 ~/.bashrc
export ANTHROPIC_AUTH_TOKEN="your-api-token"
export ANTHROPIC_BASE_URL="https://your-api-endpoint"

# 重新加载
source ~/.zshrc
```

### 开始使用

```bash
# 最简单的方式 - 使用 claude-sandbox
claude-sandbox -p "write hello world in python"

# 交互模式
claude-sandbox
```

## 命令详解

### claude-sandbox

`claude-sandbox` 是 `claude` 命令的沙盒版本，在隔离的 Linux VM 中运行。

```bash
# 基本用法
claude-sandbox -p "prompt"           # 打印模式
claude-sandbox                        # 交互模式

# 指定工作目录（宿主机路径）
claude-sandbox --workingdir ~/Projects/myapp -p "add tests"
claude-sandbox --wd ~/Downloads/code -p "review this code"

# 使用 Claude Code 的所有参数
claude-sandbox -p "hello" --output-format stream-json --verbose
claude-sandbox --model sonnet -p "quick task"
claude-sandbox -c -p "continue previous"
claude-sandbox --plan -p "design architecture"

# 不使用 --dangerously-skip-permissions
claude-sandbox --no-dangerously-skip-permissions -p "task"
```

**注意**：默认会自动添加 `--dangerously-skip-permissions`，因为在沙盒环境中运行。

### cowork

`cowork` 是完整的 CLI 工具，包含 VM 管理和 Claude 命令。

#### VM 管理

```bash
cowork init                 # 创建并启动 VM
cowork start                # 启动 VM
cowork stop                 # 停止 VM
cowork status               # 查看状态
cowork list                 # 列出所有 VM
cowork delete               # 删除 VM

cowork shell                # 进入 VM shell
cowork exec "command"       # 在 VM 中执行命令
```

#### Claude 命令

```bash
# cowork ask - 非交互模式（自动添加 -p）
cowork ask "write a function"
cowork ask -c "add error handling"
cowork ask --project myapp "create flask app"
cowork ask --workingdir ~/Projects/app "add tests"

# cowork claude - 交互模式
cowork claude
cowork claude -p "single query"
cowork claude --workingdir ~/Downloads/code
```

#### 高级选项

```bash
# 使用不同的 VM
cowork --vm-name myvm ask "hello"

# 创建带代理的 VM
cowork --proxy 192.168.5.2:7890 init

# 创建带自定义挂载的 VM
cowork --mount ~/project:/workspace init

# 组合使用
cowork --vm-name dev --proxy 192.168.5.2:7890 --mount ~/dev:/workspace init
```

## 工作目录

### 默认目录

- `/workspace` - VM 中的默认工作目录
- `~/Downloads/cowork-workspace` - 宿主机挂载目录（映射到 `/workspace`）

### --project 参数

在 `/workspace` 下创建子目录：

```bash
cowork ask --project myapp "create flask app"
# 工作目录: /workspace/myapp

cowork ask --project myapp -c "add tests"
# 继续在 /workspace/myapp 工作
```

### --workingdir 参数

使用宿主机的任意目录（必须在 `~` 下）：

```bash
claude-sandbox --workingdir ~/Projects/app -p "add tests"
# 实际工作目录: /tmp/lima/Projects/app

cowork ask --workingdir ~/Downloads/code "review this"
# 实际工作目录: /tmp/lima/Downloads/code
```

**原理**：宿主机的 `~` 挂载到 VM 的 `/tmp/lima`，所以 `~/Projects/app` 变成 `/tmp/lima/Projects/app`。

## Python API

```python
from host.controller import CoworkController, SandboxConfig

# 基本用法
controller = CoworkController()
result = controller.ask_claude("write hello world")
print(result.output)

# 带配置
config = SandboxConfig(
    vm_name="sandbox",
    proxy_host="192.168.5.2",
    proxy_port=7890,
)
controller = CoworkController(config)

# 使用项目目录
result = controller.ask_claude("create app", project="myapp")

# 使用宿主机路径
result = controller.ask_claude("add tests", workingdir="~/Projects/app")

# 继续对话
result = controller.ask_claude("add error handling", continue_conversation=True)

# 使用 Claude 选项
result = controller.ask_claude(
    "design a REST API",
    claude_args=["--plan"]
)

# 执行 VM 命令
result = controller.execute_in_vm("ls -la /workspace")
print(result.output)

# VM 管理
controller.create_vm()
controller.start_vm()
controller.stop_vm()
info = controller.get_vm_info()
```

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `ANTHROPIC_AUTH_TOKEN` | API Token | - |
| `ANTHROPIC_BASE_URL` | API 端点 | - |
| `COWORK_VM_NAME` | VM 名称 | sandbox |
| `COWORK_WORKSPACE` | 工作目录 | /workspace |
| `COWORK_PROXY_HOST` | 代理主机 | - |
| `COWORK_PROXY_PORT` | 代理端口 | 7890 |
| `COWORK_MOUNT` | 自定义挂载 | - |

## 多 VM 管理

```bash
# 创建多个独立的沙盒
cowork --vm-name proj-a --mount ~/project-a:/workspace init
cowork --vm-name proj-b --mount ~/project-b:/workspace init

# 在不同沙盒中工作
cowork --vm-name proj-a ask "analyze this code"
cowork --vm-name proj-b ask "write tests"

# 查看所有沙盒
cowork list

# 删除特定沙盒
cowork --vm-name proj-a delete
```

## 故障排除

### VM 无法启动

```bash
limactl list                # 检查状态
cowork delete               # 删除 VM
cowork init                 # 重新创建
```

### Claude 命令未找到

```bash
cowork shell
npm install -g @anthropic-ai/claude-code
```

### 网络问题

```bash
cowork exec "curl -I https://google.com"
cowork stop && cowork start
```

### 查看 VM 日志

```bash
tail -f ~/.lima/sandbox/serial.log
```

## 配置继承

如果没有设置 API 环境变量，VM 中的 Claude Code 会使用宿主机的 `~/.claude/settings.json` 配置。

优先级：环境变量 > settings.json
