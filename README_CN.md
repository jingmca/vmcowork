# VMCowork

在隔离的 Linux 虚拟机中运行 Claude Code 的 macOS 沙箱环境。

[English / 英文文档](README.md)

## 一键安装 (Apple Silicon)

### 标准安装（从零构建）

```bash
curl -fsSL https://raw.githubusercontent.com/jingmca/vmcowork/main/install.sh | bash
```

安装脚本会自动完成：
- 安装 Lima 和 jq（通过 Homebrew 或直接下载二进制文件）
- 克隆仓库到 `~/.vmcowork/`
- 下载预构建 VM 包（如有）或从零构建
- 部署 CUI（Claude UI）Web 界面
- 自动配置 PATH

### 导入安装（从预构建镜像）

如果你有预构建的 VM 镜像（通过 `cowork export` 导出），可以跳过构建步骤：

```bash
# 一键安装 + 导入本地镜像
curl -fsSL https://raw.githubusercontent.com/jingmca/vmcowork/main/install.sh | bash -s -- --import /path/to/image.tar.gz

# 通过环境变量指定镜像
COWORK_IMPORT_IMAGE=/path/to/image.tar.gz curl -fsSL https://raw.githubusercontent.com/jingmca/vmcowork/main/install.sh | bash

# 安装时不部署 CUI
curl -fsSL https://raw.githubusercontent.com/jingmca/vmcowork/main/install.sh | bash -s -- --no-cui
```

已安装用户可以直接使用 `cowork import`：

```bash
cowork import ~/Downloads/cowork-sandbox-20250101.tar.gz
```

### 安装后配置

```bash
# 配置 API 凭证（必需）
export ANTHROPIC_AUTH_TOKEN="your-api-token"
export ANTHROPIC_BASE_URL="https://your-api-endpoint"

# 重新加载 shell
source ~/.zshrc  # 或 ~/.bashrc

# 开始使用（可直接替代 claude 命令）
claude-sandbox -p "write hello world in python"
claude-sandbox  # 交互模式
```

## 网络代理（可选）

如果需要代理才能访问 API：

```bash
export HTTP_PROXY="http://127.0.0.1:7890"
export HTTPS_PROXY="http://127.0.0.1:7890"
```

## 使用方法

### claude-sandbox（推荐）

可直接替代 `claude` 命令，在隔离 VM 中运行：

```bash
# 单次查询
claude-sandbox -p "write a function"

# 交互模式
claude-sandbox

# 指定工作目录
claude-sandbox --workingdir ~/Projects/myapp -p "add tests"

# 支持所有 Claude Code 选项
claude-sandbox -p "hello" --output-format stream-json --verbose
claude-sandbox --model sonnet -p "quick task"
```

### cowork CLI

完整的 CLI 工具，支持 VM 管理：

```bash
cowork init                 # 创建并启动沙箱
cowork list                 # 列出所有沙箱
cowork status               # 查看沙箱状态
cowork stop                 # 停止沙箱
cowork delete               # 删除沙箱

cowork shell                # 进入 VM Shell
cowork exec "command"       # 在 VM 中执行命令

cowork export -o image.tar.gz  # 导出 VM 镜像
cowork import image.tar.gz     # 导入 VM 镜像
```

### Claude 命令

```bash
# 新建对话
cowork ask "write a function"

# 继续对话
cowork ask -c "add error handling"

# 在项目目录中工作
cowork ask --project myapp "create flask app"
cowork ask --project myapp -c "add tests"

# 交互模式
cowork claude
```

### CUI（Claude UI）- Web 界面

CUI 提供基于浏览器的 Claude 聊天界面，API 服务运行在沙箱 VM 内部。

#### 快速开始

```bash
# 1. 一键部署（部署代码 + 启动 API 服务）
cowork cui-setup

# 2. 在宿主机启动 Web UI
cowork cui-web start

# 3. 打开终端输出的访问地址（包含 token）
#    示例：http://localhost:3000#token=abc123def456
```

#### 访问令牌（Token）

CUI 服务每次启动时会生成随机访问令牌，用于安全认证。令牌会显示在终端输出中：

```
✓ CUI server started on port 3001

  Access URL: http://localhost:3000#token=<your-token>
```

直接在浏览器中打开该 URL 即可。如果丢失了 token，可以通过以下方式找回：

```bash
cowork cui-server status    # 显示包含 token 的访问地址
cowork cui-server logs      # 查看服务日志中的 token
```

#### CUI 完整流程

```
步骤 1: cowork cui-setup
        ├── 在 VM 中克隆 CUI 代码到 /workspace/cui
        ├── npm install（Linux 依赖）
        ├── npm run build
        └── 启动 API 服务 → 生成访问 token

步骤 2: cowork cui-web start
        ├── 在宿主机 ~/.vmcowork/cui-web/ 初始化 Web UI
        ├── npm install（macOS 依赖，与 VM 隔离）
        └── 启动 Vite 开发服务器（端口 3000）

步骤 3: 浏览器访问 http://localhost:3000#token=xxx
        ├── Web UI（宿主机:3000）→ API Server（VM:3001）
        └── API Server → Claude Code CLI → Claude API
```

#### CUI 命令参考

```bash
# 管理 API 服务（运行在 VM 内）
cowork cui-server start        # 启动 API 服务（端口 3001）
cowork cui-server stop         # 停止 API 服务
cowork cui-server restart      # 重启 API 服务（会生成新 token）
cowork cui-server status       # 查看服务状态和访问地址
cowork cui-server logs         # 查看服务日志

# 管理 Web UI（运行在宿主机）
cowork cui-web start           # 启动 Web UI（端口 3000）
cowork cui-web stop            # 停止 Web UI
cowork cui-web update          # 更新 CUI 源码并重新安装依赖

# 健康检查
cowork cui-health              # 检查所有 CUI 服务状态
```

### 多沙箱

创建独立的沙箱环境：

```bash
# 为项目 A 创建沙箱
cowork --vm-name proj-a --mount ~/project-a:/workspace init

# 为项目 B 创建沙箱
cowork --vm-name proj-b --mount ~/project-b:/workspace init

# 使用指定沙箱
cowork --vm-name proj-a ask "analyze this code"
cowork --vm-name proj-b ask "write tests"

# 列出所有沙箱
cowork list
```

### 代理配置

创建沙箱时配置网络代理：

```bash
cowork --proxy 192.168.5.2:7890 init
cowork --vm-name dev --proxy 192.168.5.2:7890 --mount ~/dev:/workspace init
```

## 命令参考

### claude-sandbox

```
claude-sandbox [选项] [claude-选项]

Cowork 选项:
  --workingdir, --wd <path>          宿主机工作路径（例如 ~/Projects/app）
  --no-dangerously-skip-permissions  不自动添加 --dangerously-skip-permissions

所有 Claude Code CLI 选项均可直接透传:
  -p, --print           单次输出模式
  -c, --continue        继续上次对话
  --model <model>       指定模型（opus, sonnet, haiku）
  --plan                计划模式（不执行）
  --output-format       输出格式（text, json, stream-json）
  --verbose             详细输出
  --allowedTools <t>    指定允许的工具
  ... 更多选项见 'claude --help'
```

### cowork

```
cowork [选项] <命令> [参数]

全局选项:
  --vm-name <name>      VM 名称（默认: sandbox）
  --proxy <host:port>   VM 网络代理（仅用于 init）
  --mount <host:vm>     自定义挂载目录（仅用于 init）

VM 管理:
  init      创建并启动沙箱 VM
  import    从预构建镜像导入 VM（tar.gz）
  export    导出 VM 为镜像文件
  list      列出所有 VM
  start     启动 VM
  stop      停止 VM
  status    查看 VM 状态
  config    查看/修改 VM 配置
  delete    删除 VM

  shell     进入 VM Shell
  exec      在 VM 中执行命令

Claude 命令:
  claude    交互式 Claude 会话（支持所有 claude 选项）
  ask       非交互式查询（自动添加 -p）

CUI 命令:
  cui-setup     一键部署 CUI（部署 + 启动服务）
  cui-deploy    部署 CUI 到沙箱 /workspace
  cui-server    管理 CUI API 服务 [start|stop|restart|status|logs]
  cui-web       管理宿主机 Web UI [start|stop|update]
  cui-health    检查所有 CUI 服务健康状态

Ask/Claude 选项:
  --project <name>                   在 /workspace/<name> 中工作
  --workingdir <path>                在宿主机路径中工作
  --no-dangerously-skip-permissions  不自动添加 --dangerously-skip-permissions
  （所有 Claude CLI 选项均可透传）

Export 选项:
  -o, --output <file>   输出文件路径

Config 选项:
  --mount <host:vm>       添加挂载目录
  --remove-mount <vm>     按 VM 路径移除挂载
  --proxy <host:port>     设置代理
  --no-proxy              移除代理
```

## 环境变量

| 变量 | 说明 |
|------|------|
| `COWORK_VM_NAME` | 默认 VM 名称 |
| `COWORK_PROXY_HOST` | 代理主机 |
| `COWORK_PROXY_PORT` | 代理端口（默认: 7890） |
| `COWORK_MOUNT` | 挂载路径（格式: host:vm） |
| `COWORK_IMPORT_IMAGE` | 预构建镜像路径（用于 install.sh） |
| `COWORK_CUI_REPO` | CUI Git 仓库地址 |
| `COWORK_CUI_PORT` | CUI API 服务端口（默认: 3001） |
| `COWORK_CUI_WEB_PORT` | CUI Web UI 端口（默认: 3000） |
| `COWORK_CUI_LOCAL` | 宿主机 CUI Web 源码路径（默认: ~/.vmcowork/cui-web） |
| `COWORK_INSTALL_CUI` | 安装时是否部署 CUI（默认: true） |
| `ANTHROPIC_API_KEY` | Claude API Key |
| `ANTHROPIC_AUTH_TOKEN` | Claude API Token |
| `ANTHROPIC_BASE_URL` | Claude API 端点地址 |

## VM 规格

| 资源 | 配置 |
|------|------|
| 操作系统 | Ubuntu 22.04 LTS |
| 架构 | ARM64 / AMD64 |
| CPU | 4 核 |
| 内存 | 4 GB |
| 磁盘 | 10 GB |

### 预装软件

- Python 3.10 + pip
- Node.js 22.x LTS
- Claude Code CLI
- GCC, Make, CMake
- Git, curl, wget
- ripgrep, fd, jq

## 架构

```
┌─────────────────────────────────────────────────────────────┐
│                      macOS 宿主机                            │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  cowork CLI / controller.py                         │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  CUI Web UI (Vite, 端口 3000)                       │   │
│  │  ~/.vmcowork/cui-web/                               │   │
│  └─────────────────────────────────────────────────────┘   │
│                           │ Lima/SSH                        │
└───────────────────────────┼─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Ubuntu 22.04 VM                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Claude Code CLI（隔离环境）                          │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  CUI API Server（端口 3001）                         │   │
│  │  /workspace/cui/                                    │   │
│  └─────────────────────────────────────────────────────┘   │
│  /workspace ← 从宿主机挂载                                  │
└─────────────────────────────────────────────────────────────┘
```

## 项目结构

```
cowork-sandbox/
├── scripts/
│   ├── claude-sandbox      # Node.js 包装器（用于 spawn 兼容性）
│   ├── claude-sandbox.sh   # Bash 实现
│   ├── cowork              # 完整 CLI 工具
│   └── import-vm.sh        # VM 镜像导入工具
├── host/
│   └── controller.py       # Python API
├── sandbox.yaml            # Lima VM 配置
├── install.sh              # 一键安装脚本
└── tests/                  # 测试脚本
```

## 常见问题

### VM 无法启动

```bash
limactl list                # 检查状态
cowork delete               # 删除 VM
cowork init                 # 重新创建
```

### 找不到 Claude

```bash
cowork shell
npm install -g @anthropic-ai/claude-code
```

### 网络问题

```bash
cowork exec "curl -I https://google.com"
cowork stop && cowork start
```

### CUI 无法使用

```bash
cowork cui-health              # 检查所有服务
cowork cui-server logs         # 查看服务日志
cowork cui-server restart      # 重启 API 服务
cowork cui-deploy              # 重新部署 CUI
```

### CUI Token 丢失

```bash
# 查看当前 token
cowork cui-server status

# 或重启服务生成新 token
cowork cui-server restart
```

## 许可证

MIT
