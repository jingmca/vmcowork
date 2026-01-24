# Cowork Sandbox 使用指南

## 快速开始

### 1. 安装依赖

```bash
# 安装 Lima
brew install lima
```

### 2. 初始化 VM

```bash
# 创建并启动 sandbox VM
./scripts/cowork init
```

### 3. 配置 API 凭证

```bash
# 设置环境变量
export ANTHROPIC_AUTH_TOKEN="your-token"
export ANTHROPIC_BASE_URL="https://your-api-endpoint"
```

## 基本用法

### 命令行模式（cowork 脚本）

```bash
# 查看 VM 状态
./scripts/cowork status

# 新对话
./scripts/cowork ask "写一个 hello world 程序"

# 继续上一个对话
./scripts/cowork ask -c "添加错误处理"

# 在项目目录中工作
./scripts/cowork ask -p myproject "创建一个 Python 项目"
./scripts/cowork ask -p myproject -c "添加单元测试"

# 交互式模式
./scripts/cowork claude

# 在 VM 中执行命令
./scripts/cowork exec "python3 /workspace/script.py"

# 进入 VM shell
./scripts/cowork shell
```

### Python API 模式

```python
from host.controller import CoworkController, SandboxConfig

# 基础配置
config = SandboxConfig(
    vm_name="sandbox",
    working_dir="/workspace",
    timeout=300,
    anthropic_auth_token="your-token",
    anthropic_base_url="https://your-api-endpoint"
)

controller = CoworkController(config)

# 新对话
result = controller.ask_claude("写一个 hello world 程序")
print(result.output)

# 继续对话
result = controller.ask_claude(
    "添加错误处理",
    continue_conversation=True
)

# 在项目目录中工作
result = controller.ask_claude(
    "创建一个 Python 项目",
    project="myproject"
)

result = controller.ask_claude(
    "添加单元测试",
    project="myproject",
    continue_conversation=True
)

# 执行命令
result = controller.execute_in_vm("python3 /workspace/script.py")

# 读取文件
result = controller.read_file("/workspace/output.txt")

# 写入文件
result = controller.write_file("/workspace/config.json", '{"key": "value"}')
```

## 高级功能

### 项目目录管理

Claude Code 的对话上下文保存在项目目录中。使用 `-p` 参数可以为不同项目维护独立的对话历史：

```bash
# 项目 A
./scripts/cowork ask -p projectA "创建一个 web 服务"
./scripts/cowork ask -p projectA -c "添加 API 端点"

# 项目 B（独立的对话上下文）
./scripts/cowork ask -p projectB "创建一个爬虫"
./scripts/cowork ask -p projectB -c "添加代理支持"
```

项目目录位于 `/workspace/{project_name}`，会自动创建。

### 环境变量配置

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `COWORK_VM_NAME` | VM 名称 | `sandbox` |
| `COWORK_WORKSPACE` | 工作目录 | `/workspace` |
| `ANTHROPIC_AUTH_TOKEN` | API 认证令牌 | 无 |
| `ANTHROPIC_BASE_URL` | API 端点 | 无 |

### VM 管理

```bash
# 启动 VM
./scripts/cowork start

# 停止 VM
./scripts/cowork stop

# 查看状态
./scripts/cowork status

# 删除 VM（会删除所有数据）
./scripts/cowork delete
```

## 工作流示例

### 开发一个完整项目

```bash
# 1. 初始化项目
./scripts/cowork ask -p webapp "创建一个 Flask web 应用，包含基础结构"

# 2. 添加功能
./scripts/cowork ask -p webapp -c "添加用户注册和登录功能"

# 3. 添加测试
./scripts/cowork ask -p webapp -c "添加单元测试"

# 4. 运行测试
./scripts/cowork exec "cd /workspace/webapp && python -m pytest"

# 5. 查看生成的文件
./scripts/cowork exec "ls -la /workspace/webapp"

# 6. 在本地访问项目文件
ls ~/cowork-workspace/webapp
```

### 数据处理任务

```python
from host.controller import CoworkController

controller = CoworkController()

# 让 Claude 生成数据处理脚本
result = controller.ask_claude(
    "创建一个 CSV 数据清洗脚本",
    project="data-cleaning"
)

# 将数据文件复制到 workspace
controller.execute_in_vm(
    "cp /Users/ten/data/input.csv /workspace/data-cleaning/"
)

# 运行脚本
result = controller.execute_in_vm(
    "cd /workspace/data-cleaning && python clean_data.py"
)

# 获取结果
result = controller.read_file("/workspace/data-cleaning/output.csv")
with open("cleaned_data.csv", "w") as f:
    f.write(result.output)
```

## 安全特性

### 当前实现的安全层

1. **VM 隔离**：代码在 Ubuntu 22.04 VM 中运行，与宿主机完全隔离
2. **文件共享限制**：仅 `~/cowork-workspace` 目录被挂载到 VM
3. **代理配置**：所有网络流量可通过宿主机 7890 端口代理
4. **权限跳过**：使用 `--dangerously-skip-permissions` 在沙箱中给予 Claude 完整权限

### 安全注意事项

- VM 内的代码可以访问网络（通过代理）
- VM 可以读写 `/workspace` 目录
- 定期备份重要文件
- 不要在 `/workspace` 中存储敏感信息

## 故障排查

### VM 启动失败

```bash
# 查看 Lima 日志
limactl list
tail -f ~/.lima/sandbox/serial*.log

# 重新创建 VM
./scripts/cowork delete
./scripts/cowork init
```

### Claude Code 认证失败

确保设置了正确的环境变量：

```bash
echo $ANTHROPIC_AUTH_TOKEN
echo $ANTHROPIC_BASE_URL
```

### 文件访问问题

VM 中的 `/workspace` 对应宿主机的 `~/cowork-workspace`：

```bash
# 在宿主机查看
ls ~/cowork-workspace

# 在 VM 中查看
./scripts/cowork exec "ls /workspace"
```

## 性能优化

### 减少 VM 启动时间

VM 首次启动需要下载镜像和安装软件包，后续启动会快很多。

### 使用 JSON 输出

```bash
python3 host/controller.py --json "创建文件" | jq .
```

### 批量任务处理

```python
tasks = [
    "任务 1",
    "任务 2",
    "任务 3"
]

for task in tasks:
    result = controller.ask_claude(task, project="batch-job")
    print(f"完成: {task}")
```

## 限制和已知问题

1. **Claude Code 需要手动登录**：首次使用需要在 VM 中运行 `claude` 并完成认证
2. **网络依赖**：需要访问外部 API
3. **资源占用**：VM 占用 4 核 CPU、4GB 内存、10GB 磁盘
4. **中文支持**：终端需要支持 UTF-8

## 下一步计划

根据设计文档 Phase 2 和 Phase 3：

- [ ] 添加 Bubblewrap 二级沙箱
- [ ] 添加网络代理审计层
- [ ] 添加日志和监控
- [ ] 使用 vsock 替代 SSH
- [ ] 添加 VM 快照/恢复功能

## 参考资料

- [设计文档](docs/02-design.md)
- [调研报告](docs/01-research.md)
- [Lima 官方文档](https://github.com/lima-vm/lima)
