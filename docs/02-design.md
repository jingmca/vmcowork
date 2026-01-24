# Cowork Sandbox 设计方案

> macOS 上复刻 Claude Code Cowork 模式的设计文档

## 1. 项目目标

在 macOS 上实现一个类似 Claude Code Cowork 模式的沙箱环境，用于安全地执行 Claude Code 生成的代码。

### 1.1 核心需求

- 在隔离的 Linux VM 中运行 Claude Code
- Host 能够与 VM 中的 Claude Code 通信
- 支持交互式和非交互式（-p 模式）两种使用方式
- 文件可在 Host 和 VM 之间共享

### 1.2 非目标（MVP 阶段）

- 不实现 Bubblewrap 二级沙箱
- 不实现 Seccomp 系统调用过滤
- 不实现网络代理审计层
- 不实现自定义 Virtualization.framework 集成

## 2. 技术选型

### 2.1 方案对比

| 方案 | 优点 | 缺点 | 复杂度 |
|------|------|------|--------|
| **Lima (选用)** | 封装完善、易用、社区活跃 | 依赖第三方工具 | ⭐ |
| Tart | 专为 Apple Silicon 设计 | 功能较少 | ⭐⭐ |
| 原生 Virtualization.framework | 完全控制、性能最优 | 需要大量 Swift 开发 | ⭐⭐⭐⭐ |
| Docker Desktop | 生态成熟 | 资源占用大、商业限制 | ⭐⭐ |

**选择 Lima 的理由**：
1. 开源免费
2. 直接基于 Apple Virtualization.framework
3. 配置简单（YAML）
4. 内置文件共享支持
5. 活跃的社区维护

### 2.2 通信方案对比

| 方案 | 优点 | 缺点 | 适用场景 |
|------|------|------|----------|
| **SSH + claude -p (选用)** | 简单、可靠、无需开发 | 有连接开销 | MVP |
| SSH + 交互式 | 支持完整 TUI | 需要 PTY 处理 | 交互模式 |
| Virtio-vsock | 高性能、低延迟 | 需要开发 agent | 生产环境 |
| 共享文件 | 实现简单 | 不适合实时通信 | 文件传输 |

**选择 SSH + claude -p 的理由**：
1. Lima 内置 SSH 支持
2. Claude Code 的 -p 模式天然支持非交互
3. 无需额外开发 agent
4. 易于调试和测试

## 3. 系统架构

### 3.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                         macOS Host                              │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    用户接口层                             │  │
│  │  ┌────────────────┐  ┌────────────────────────────────┐  │  │
│  │  │  cowork CLI    │  │  controller.py (Python SDK)    │  │  │
│  │  │  (Bash 脚本)    │  │  - CoworkController 类         │  │  │
│  │  └───────┬────────┘  └───────────────┬────────────────┘  │  │
│  └──────────┼───────────────────────────┼───────────────────┘  │
│             │                           │                       │
│             └─────────────┬─────────────┘                       │
│                           │                                     │
│  ┌────────────────────────┼─────────────────────────────────┐  │
│  │                   Lima 管理层                             │  │
│  │                        │                                  │  │
│  │            limactl shell / limactl start                  │  │
│  │                        │                                  │  │
│  └────────────────────────┼─────────────────────────────────┘  │
│                           │ SSH                                 │
│  ┌────────────────────────┼─────────────────────────────────┐  │
│  │               共享目录  │                                 │  │
│  │     ~/cowork-workspace ◄──────────────────────┐          │  │
│  └────────────────────────┼──────────────────────┼──────────┘  │
└───────────────────────────┼──────────────────────┼──────────────┘
                            │                      │
════════════════════════════╪══════════════════════╪══════════════
                            │                      │
┌───────────────────────────┼──────────────────────┼──────────────┐
│                    Ubuntu 22.04 VM               │              │
│                           │                      │              │
│  ┌────────────────────────▼───────────────────┐  │              │
│  │              Claude Code CLI               │  │              │
│  │                                            │  │              │
│  │   claude -p "prompt"  (非交互模式)          │  │              │
│  │   claude              (交互模式)           │  │              │
│  └────────────────────────────────────────────┘  │              │
│                                                  │              │
│  ┌────────────────────────────────────────────┐  │              │
│  │              /workspace ◄─────────────────────┘              │
│  │         (挂载的共享目录)                    │                │
│  └────────────────────────────────────────────┘                │
│                                                                 │
│  Pre-installed: Python 3.10, Node.js 22, GCC, Java 11          │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 组件说明

#### Host 端组件

| 组件 | 文件 | 职责 |
|------|------|------|
| CLI 工具 | `scripts/cowork` | 命令行入口，封装常用操作 |
| Python 控制器 | `host/controller.py` | 程序化 API，供其他程序调用 |
| VM 配置 | `sandbox.yaml` | Lima VM 的配置定义 |

#### VM 端组件

| 组件 | 说明 |
|------|------|
| Ubuntu 22.04 | 基础操作系统 |
| Claude Code CLI | Anthropic 官方 CLI 工具 |
| 开发工具链 | Python, Node.js, GCC 等 |
| /workspace | 共享工作目录 |

### 3.3 数据流

#### 非交互模式（-p 模式）

```
User Input          Host                    VM
    │                 │                      │
    │  "write hello"  │                      │
    │────────────────►│                      │
    │                 │  ssh + claude -p     │
    │                 │─────────────────────►│
    │                 │                      │ Claude Code
    │                 │                      │ 执行任务
    │                 │     stdout/stderr    │
    │                 │◄─────────────────────│
    │   结果输出      │                      │
    │◄────────────────│                      │
```

#### 交互模式

```
User                Host                    VM
  │                   │                      │
  │  cowork claude    │                      │
  │──────────────────►│                      │
  │                   │  ssh -t              │
  │                   │─────────────────────►│
  │                   │                      │
  │◄──────────────────┼──────────────────────┤
  │     PTY 双向转发（终端交互）              │
  │──────────────────►├─────────────────────►│
  │                   │                      │
```

## 4. 详细设计

### 4.1 VM 配置 (sandbox.yaml)

```yaml
# 资源配置（对标 Cowork 模式）
cpus: 4
memory: "4GiB"
disk: "10GiB"

# 镜像选择
images:
  - location: "ubuntu-22.04-server-cloudimg-arm64.img"
    arch: "aarch64"

# 文件共享
mounts:
  - location: "~/cowork-workspace"
    writable: true
    mountPoint: "/workspace"

# 初始化脚本
provision:
  - mode: system
    script: |
      # 安装系统依赖
      apt-get install -y python3 nodejs gcc ...
  - mode: user
    script: |
      # 安装 Claude Code
      npm install -g @anthropic-ai/claude-code
```

### 4.2 Controller API 设计

```python
class CoworkController:
    """VM 中 Claude Code 的控制器"""

    def __init__(self, config: SandboxConfig):
        """初始化控制器"""

    def is_vm_running(self) -> bool:
        """检查 VM 是否运行中"""

    def start_vm(self) -> bool:
        """启动 VM"""

    def stop_vm(self) -> bool:
        """停止 VM"""

    def ask_claude(self, prompt: str, **options) -> ExecutionResult:
        """
        向 Claude Code 发送请求（-p 模式）

        Args:
            prompt: 发送给 Claude 的提示
            working_dir: 工作目录
            timeout: 超时时间

        Returns:
            ExecutionResult: 包含 output, error, exit_code
        """

    def execute_in_vm(self, command: str) -> ExecutionResult:
        """在 VM 中执行 shell 命令"""

    def read_file(self, path: str) -> ExecutionResult:
        """读取 VM 中的文件"""

    def write_file(self, path: str, content: str) -> ExecutionResult:
        """写入 VM 中的文件"""
```

### 4.3 CLI 命令设计

```bash
cowork <command> [options]

命令：
  init      # 初始化 VM（首次使用）
  start     # 启动 VM
  stop      # 停止 VM
  status    # 查看状态
  shell     # 进入 VM shell
  claude    # 启动交互式 Claude Code
  ask       # 非交互式询问 Claude
  exec      # 在 VM 中执行命令
  delete    # 删除 VM

示例：
  cowork init
  cowork ask "write a python script to download a webpage"
  cowork exec "python3 /workspace/download.py"
```

## 5. 安全设计

### 5.1 当前安全边界（MVP）

```
┌─────────────────────────────────────────┐
│            macOS Host                   │
│  ┌───────────────────────────────────┐  │
│  │  仅 ~/cowork-workspace 共享       │  │
│  │  其他 Host 文件不可访问           │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
                    │
           VM 边界 (安全屏障)
                    │
┌─────────────────────────────────────────┐
│            Ubuntu VM                    │
│  - 完整 Linux 权限                      │
│  - 可访问网络                           │
│  - 可读写 /workspace                    │
└─────────────────────────────────────────┘
```

### 5.2 风险评估

| 风险 | 级别 | 缓解措施 |
|------|------|----------|
| VM 内代码破坏 | 低 | VM 可重建，数据在共享目录 |
| VM 逃逸攻击 | 极低 | 依赖 Apple Virtualization 安全性 |
| 网络攻击 | 中 | VM 有完整网络，可后续添加代理 |
| 资源耗尽 | 低 | Lima 有资源限制配置 |

### 5.3 后续安全增强（非 MVP）

1. **添加 Bubblewrap**
   ```bash
   # 在 VM 内执行代码时增加隔离
   bwrap --unshare-all --ro-bind /usr /usr ... -- python code.py
   ```

2. **添加网络代理**
   ```bash
   # Host 端启动代理
   mitmproxy --mode regular --listen-port 3128
   # VM 内配置代理
   export HTTP_PROXY=http://host:3128
   ```

3. **添加 Seccomp 过滤**
   ```c
   // 限制系统调用
   seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(read), 0);
   // 白名单模式
   ```

## 6. 实现计划

### Phase 1: MVP（当前）

- [x] Lima VM 配置
- [x] 基础 CLI 工具
- [x] Python Controller
- [x] 文档

### Phase 2: 增强

- [ ] 添加 PTY 代理实现完整交互式支持
- [ ] 添加 Bubblewrap 二级沙箱
- [ ] 添加网络代理层
- [ ] 添加日志和监控

### Phase 3: 生产级

- [ ] 使用 vsock 替代 SSH 提升性能
- [ ] 添加 Seccomp 过滤
- [ ] 使用原生 Virtualization.framework
- [ ] 添加 VM 快照/恢复功能

## 7. 使用场景

### 7.1 开发者使用

```bash
# 初始化沙箱
cowork init

# 让 Claude 在沙箱中写代码
cowork ask "create a web scraper for news sites"

# 查看生成的代码
cowork exec "cat /workspace/scraper.py"

# 运行代码（安全隔离）
cowork exec "python3 /workspace/scraper.py"
```

### 7.2 程序集成

```python
from host.controller import CoworkController

controller = CoworkController()

# 自动化任务
tasks = [
    "create a data processing pipeline",
    "add unit tests",
    "optimize for performance"
]

for task in tasks:
    result = controller.ask_claude(task)
    print(f"Task: {task}")
    print(f"Result: {result.output}")
```

## 8. 测试计划

### 8.1 功能测试

- [ ] VM 启动/停止
- [ ] Claude Code 安装验证
- [ ] 非交互模式执行
- [ ] 交互模式执行
- [ ] 文件共享读写

### 8.2 安全测试

- [ ] 验证 VM 无法访问 Host 文件系统
- [ ] 验证资源限制生效
- [ ] 测试异常恢复

## 9. 附录

### 9.1 文件结构

```
cowork-sandbox/
├── docs/
│   ├── 01-research.md      # 调研文档
│   └── 02-design.md        # 设计文档（本文件）
├── host/
│   └── controller.py       # Python 控制器
├── scripts/
│   └── cowork              # CLI 工具
├── sandbox.yaml            # Lima VM 配置
└── README.md               # 使用说明
```

### 9.2 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| COWORK_VM_NAME | sandbox | VM 名称 |
| COWORK_WORKSPACE | /workspace | 工作目录 |

### 9.3 依赖项

| 依赖 | 版本 | 安装方式 |
|------|------|----------|
| Lima | latest | `brew install lima` |
| Python | 3.8+ | 系统自带 |
| jq | latest | `brew install jq` |
