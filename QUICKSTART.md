# 快速入门指南

5 分钟上手 Cowork Sandbox

## 步骤 1: 安装 Lima（1 分钟）

```bash
brew install lima
```

## 步骤 2: 配置 API（1 分钟）

```bash
cd cowork-sandbox

# 复制配置模板
cp .env.example .env

# 编辑配置（添加你的 API Token 和 URL）
nano .env
```

在 `.env` 中填入：
```bash
ANTHROPIC_AUTH_TOKEN=your-token-here
ANTHROPIC_BASE_URL=https://your-api-endpoint
```

加载环境变量：
```bash
source .env
```

## 步骤 3: 初始化 VM（2-3 分钟）

```bash
./scripts/cowork init
```

这会自动：
- 下载 Ubuntu 镜像
- 创建虚拟机
- 安装开发工具
- 安装 Claude Code

## 步骤 4: 开始使用（立即）

```bash
# 问一个问题
./scripts/cowork ask "写一个 Python hello world"

# 继续对话
./scripts/cowork ask -c "添加命令行参数支持"

# 在项目中工作
./scripts/cowork ask -p myapp "创建一个 Flask 应用"
```

## 常见命令

```bash
# 查看状态
./scripts/cowork status

# 进入 VM
./scripts/cowork shell

# 执行命令
./scripts/cowork exec "ls /workspace"

# 交互式模式
./scripts/cowork claude
```

## 验证安装

运行测试：
```bash
./scripts/test.sh
```

## 下一步

查看详细文档：
- [USAGE.md](USAGE.md) - 完整使用指南
- [examples/basic_usage.py](examples/basic_usage.py) - Python API 示例

## 故障排查

### VM 启动失败

```bash
# 删除并重建
./scripts/cowork delete
./scripts/cowork init
```

### 环境变量未生效

```bash
# 确认已加载
echo $ANTHROPIC_AUTH_TOKEN

# 重新加载
source .env
```

### Claude Code 未安装

```bash
# 进入 VM 手动安装
./scripts/cowork shell
npm install -g @anthropic-ai/claude-code
```

## 需要帮助？

查看 [CONTRIBUTING.md](CONTRIBUTING.md) 了解如何报告问题。
