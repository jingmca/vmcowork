# Claude CLI 参数完全支持指南

> Cowork Sandbox v0.4.0+ 支持所有 Claude CLI 参数的透传

## 概述

从 v0.4.0 开始，`cowork ask` 命令支持所有 Claude CLI 参数，让您可以完全利用 Claude Code 的所有功能。

## 参数映射

### Cowork 专用参数

这些参数由 cowork 处理，不会传递给 Claude：

| 参数 | 说明 | 示例 |
|------|------|------|
| `--project <name>` | 指定项目目录 | `cowork ask --project myapp "task"` |
| `--proj <name>` | `--project` 的缩写 | `cowork ask --proj myapp "task"` |

**注意**：旧的 `-p <project>` 语法已废弃，请使用 `--project`。

### Claude CLI 参数

所有其他参数都直接传递给 Claude，包括但不限于：

## 常用 Claude 参数

### 1. 对话管理

```bash
# 继续之前的对话
cowork ask -c "继续之前的任务"
cowork ask --continue "继续之前的任务"

# 恢复特定会话
cowork ask -r <session-id> "在特定会话中工作"
cowork ask --resume <session-id> "在特定会话中工作"

# 使用特定会话 ID
cowork ask --session-id <uuid> "使用指定 ID"
```

### 2. 模型选择

```bash
# 使用 Opus 模型（更强大）
cowork ask --model opus "复杂的推理任务"

# 使用 Haiku 模型（更快）
cowork ask --model haiku "简单任务"

# 使用 Sonnet（默认）
cowork ask --model sonnet "平衡任务"

# 指定完整模型名
cowork ask --model claude-opus-4-5-20251101 "使用特定版本"
```

### 3. 预算控制

```bash
# 设置最大预算（美元）
cowork ask --max-budget-usd 1.0 "限制成本的任务"

# 设置回退模型（当主模型过载时）
cowork ask --fallback-model haiku "任务"
```

### 4. 系统提示

```bash
# 自定义系统提示
cowork ask --system-prompt "You are a Python expert" "写代码"

# 追加系统提示
cowork ask --append-system-prompt "Use type hints" "写代码"
```

### 5. 工具控制

```bash
# 允许特定工具
cowork ask --allowed-tools "Bash,Edit,Read" "任务"

# 禁用特定工具
cowork ask --disallowed-tools "Bash" "只读任务"

# 禁用所有工具
cowork ask --tools "" "只对话"

# 使用所有默认工具
cowork ask --tools "default" "任务"
```

### 6. 目录访问

```bash
# 添加额外可访问目录
cowork ask --add-dir /some/path "访问额外目录"

# 多个目录
cowork ask --add-dir /path1 /path2 "访问多个目录"
```

### 7. 输出格式

```bash
# JSON 输出
cowork ask --output-format json "获取结构化输出"

# 流式 JSON 输出
cowork ask --output-format stream-json "获取实时流"

# 纯文本输出（默认）
cowork ask --output-format text "任务"
```

### 8. 结构化输出

```bash
# 使用 JSON Schema 验证输出
cowork ask --json-schema '{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}' "生成用户对象"
```

### 9. MCP 服务器配置

```bash
# 加载 MCP 服务器配置
cowork ask --mcp-config ./mcp-config.json "使用 MCP 服务器"

# 多个配置
cowork ask --mcp-config config1.json config2.json "任务"

# 仅使用指定配置
cowork ask --strict-mcp-config --mcp-config my-config.json "任务"
```

### 10. 代理和插件

```bash
# 使用特定代理
cowork ask --agent reviewer "审查代码"

# 自定义代理
cowork ask --agents '{"reviewer":{"description":"Reviews code","prompt":"You are a code reviewer"}}' "任务"

# 加载插件
cowork ask --plugin-dir /path/to/plugins "任务"
```

### 11. 调试和日志

```bash
# 启用调试模式
cowork ask --debug "任务"
cowork ask -d "任务"

# 过滤调试输出
cowork ask --debug api,hooks "任务"
cowork ask -d "!statsig,!file" "任务"

# 详细模式
cowork ask --verbose "任务"
```

### 12. 权限和设置

```bash
# 权限模式
cowork ask --permission-mode acceptEdits "任务"
cowork ask --permission-mode bypassPermissions "任务"
cowork ask --permission-mode plan "任务"

# 允许绕过权限选项
cowork ask --allow-dangerously-skip-permissions "任务"

# 自定义设置
cowork ask --settings ./custom-settings.json "任务"
cowork ask --settings '{"key":"value"}' "任务"

# 选择设置来源
cowork ask --setting-sources user,project "任务"
```

## 组合使用示例

### 示例 1: 项目中使用 Opus 模型并设置预算

```bash
cowork ask \
  --project my-web-app \
  --model opus \
  --max-budget-usd 2.0 \
  "创建一个完整的用户认证系统"
```

### 示例 2: 继续对话并限制工具使用

```bash
cowork ask \
  --project my-web-app \
  -c \
  --allowed-tools "Edit,Read" \
  "修改认证系统，添加 2FA 支持"
```

### 示例 3: 使用自定义系统提示和 JSON 输出

```bash
cowork ask \
  --system-prompt "You are a security expert" \
  --output-format json \
  "分析这个系统的安全漏洞"
```

### 示例 4: 调试模式下使用特定代理

```bash
cowork ask \
  --project backend-api \
  --agent reviewer \
  --debug api \
  -c \
  "审查最近的 API 变更"
```

### 示例 5: 结构化输出用于自动化

```bash
cowork ask \
  --output-format json \
  --json-schema '{"type":"object","properties":{"summary":{"type":"string"},"files_changed":{"type":"array","items":{"type":"string"}}}}' \
  "总结项目中的最近变更"
```

## Python API 使用

```python
from host.controller import CoworkController, SandboxConfig

# 创建控制器
controller = CoworkController(SandboxConfig())

# 基础用法
result = controller.ask_claude("write hello world")

# 使用项目目录
result = controller.ask_claude(
    "create a flask app",
    project="my-web-app"
)

# 继续对话
result = controller.ask_claude(
    "add authentication",
    project="my-web-app",
    continue_conversation=True
)

# 传递额外的 Claude 参数
result = controller.ask_claude(
    "complex task",
    project="my-app",
    claude_args=[
        "--model", "opus",
        "--max-budget-usd", "2.0",
        "--system-prompt", "You are an expert",
        "--allowed-tools", "Bash,Edit,Read"
    ]
)

# 使用所有选项
result = controller.ask_claude(
    prompt="create API endpoints",
    project="backend",
    continue_conversation=True,
    allowed_tools=["Bash", "Edit", "Read"],
    claude_args=[
        "--model", "opus",
        "--max-budget-usd", "1.5",
        "--system-prompt", "You are a backend expert",
        "--debug", "api"
    ]
)

if result.success:
    print(result.output)
else:
    print(f"Error: {result.error}")
```

## 参数优先级

当相同功能的参数以不同方式指定时，优先级如下：

1. **`claude_args` (Python)** / **命令行直接参数 (Bash)** - 最高优先级
2. **专用参数** (如 `allowed_tools`, `continue_conversation`)
3. **配置文件** (.env, settings.json)
4. **默认值**

示例：

```python
# 这里 claude_args 中的 --allowed-tools 会覆盖 allowed_tools 参数
controller.ask_claude(
    "task",
    allowed_tools=["Bash"],  # 会被覆盖
    claude_args=["--allowed-tools", "Edit,Read"]  # 实际生效
)
```

## 迁移指南

### 从旧版本迁移

**v0.3.x 及更早版本：**

```bash
# 旧语法（已废弃）
cowork ask -p myproject "task"
cowork ask -p myproject -c "continue"
```

**v0.4.0+ 新语法：**

```bash
# 新语法
cowork ask --project myproject "task"
cowork ask --proj myproject "task"           # 使用缩写
cowork ask --project myproject -c "continue"  # -c 保持不变
```

**Python API：**

```python
# 旧版本
result = controller.ask_claude("task", project="myapp")

# 新版本（向后兼容）
result = controller.ask_claude("task", project="myapp")

# 新版本（使用额外参数）
result = controller.ask_claude(
    "task",
    project="myapp",
    claude_args=["--model", "opus"]
)
```

## 常见问题

### Q: `-c` 参数有冲突吗？

**A:** 没有冲突。cowork 的 `-c` 和 Claude 的 `-c`/`--continue` 语义相同，都是继续对话。cowork 只是简单地将 `-c` 传递给 Claude。

### Q: 为什么改了项目参数？

**A:** 因为 Claude CLI 使用 `-p` 表示 `--print` 模式（非交互模式），而 cowork 总是使用这个模式。为了避免混淆并支持完整的 Claude 参数，我们将 cowork 的项目参数改为 `--project`。

### Q: 所有 Claude 参数都支持吗？

**A:** 是的！除了 `--project` 被 cowork 使用外，所有其他 Claude CLI 参数都可以正常使用。参见 `claude --help` 获取完整列表。

### Q: 如何知道 Claude 收到了什么参数？

**A:** 使用调试模式：

```bash
cowork ask --debug "task"
```

### Q: 参数中的特殊字符如何处理？

**A:** Bash 中使用引号：

```bash
# 正确
cowork ask --system-prompt "You're an expert" "task"

# 使用单引号避免转义
cowork ask --json-schema '{"type":"object"}' "task"
```

## 最佳实践

### 1. 使用项目目录组织工作

```bash
# 为每个项目创建独立目录
cowork ask --project frontend "任务"
cowork ask --project backend "任务"
cowork ask --project docs "任务"
```

### 2. 预算控制

```bash
# 对昂贵任务设置预算上限
cowork ask --max-budget-usd 0.5 --model opus "任务"
```

### 3. 合理选择模型

- **Haiku**: 简单任务、快速响应
- **Sonnet**: 日常开发、平衡性能
- **Opus**: 复杂推理、高质量输出

### 4. 调试时启用详细输出

```bash
cowork ask --debug --verbose "任务"
```

### 5. 使用结构化输出进行自动化

```bash
# 输出可以直接解析的 JSON
cowork ask --output-format json "生成配置"  | jq .
```

## 参考资料

- [Claude CLI 官方文档](https://docs.anthropic.com/claude/docs/claude-cli)
- [Cowork Sandbox README](../README.md)
- [完整使用指南](./USAGE.md)

## 示例脚本

查看 `examples/` 目录获取更多示例：

- `examples/basic_usage.py` - Python API 基础示例
- `examples/advanced_parameters.py` - 高级参数使用（待添加）
- `examples/automation.sh` - 自动化脚本示例（待添加）
