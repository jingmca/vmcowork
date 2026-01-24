# Contributing to Cowork Sandbox

感谢您对 Cowork Sandbox 的兴趣！本文档提供了如何为项目做出贡献的指南。

## 开发设置

### 1. Fork 和 Clone

```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/cowork-sandbox.git
cd cowork-sandbox
```

### 2. 安装依赖

```bash
# Install Lima
brew install lima

# Install jq (for JSON parsing in tests)
brew install jq
```

### 3. 创建开发环境

```bash
# Copy environment template
cp .env.example .env

# Edit with your API credentials
nano .env

# Initialize VM
./scripts/cowork init
```

### 4. 运行测试

```bash
# Run test suite
./scripts/test.sh

# Test Python controller
python3 examples/basic_usage.py
```

## 开发工作流

### 分支策略

- `main` - 稳定版本
- `develop` - 开发分支
- `feature/*` - 新功能分支
- `bugfix/*` - Bug 修复分支

### 提交代码

1. 创建功能分支

```bash
git checkout -b feature/your-feature-name
```

2. 进行更改并提交

```bash
git add .
git commit -m "feat: add your feature description"
```

提交信息格式：
- `feat:` - 新功能
- `fix:` - Bug 修复
- `docs:` - 文档更新
- `test:` - 测试相关
- `refactor:` - 代码重构
- `chore:` - 构建/工具相关

3. 推送并创建 Pull Request

```bash
git push origin feature/your-feature-name
```

## 代码风格

### Bash 脚本

- 使用 `#!/bin/bash` shebang
- 使用 `set -e` 在错误时退出
- 函数名使用 `snake_case`
- 添加注释说明复杂逻辑

示例：
```bash
#!/bin/bash
set -e

# Print colored output
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Main function
main() {
    print_success "Operation completed"
}
```

### Python 代码

- 遵循 PEP 8
- 使用类型提示
- 使用 docstring 记录函数

示例：
```python
def ask_claude(
    self,
    prompt: str,
    project: Optional[str] = None
) -> ExecutionResult:
    """
    Send a prompt to Claude Code.

    Args:
        prompt: The prompt to send
        project: Optional project directory

    Returns:
        ExecutionResult with output
    """
    pass
```

## 测试

### 添加测试

在 `scripts/test.sh` 中添加测试用例：

```bash
# Test your new feature
run_test "Feature description" "your-test-command"
```

### 运行测试

```bash
# Run all tests
./scripts/test.sh

# Run specific test (manually)
./scripts/cowork exec "your test command"
```

## 文档

### 更新文档

如果添加新功能，请更新：

1. **README.md** - 主要文档
2. **USAGE.md** - 详细使用指南
3. **帮助信息** - `scripts/cowork` 中的 help 函数
4. **API 文档** - `host/controller.py` 中的 docstring

### 文档风格

- 使用清晰的标题和子标题
- 提供代码示例
- 包含预期输出
- 添加故障排查建议

## 功能请求优先级

根据设计文档，以下是功能优先级：

### Phase 2（高优先级）

- [ ] 添加 PTY 代理实现完整交互式支持
- [ ] 添加 Bubblewrap 二级沙箱
- [ ] 添加网络代理审计层
- [ ] 添加日志和监控功能

### Phase 3（中优先级）

- [ ] 使用 vsock 替代 SSH 提升性能
- [ ] 添加 Seccomp 系统调用过滤
- [ ] 使用原生 Virtualization.framework
- [ ] 添加 VM 快照/恢复功能

### 其他改进（低优先级）

- [ ] 添加更多编程语言支持
- [ ] 改进错误处理和提示
- [ ] 添加性能监控
- [ ] 创建 Web UI

## Pull Request 检查清单

提交 PR 前，请确保：

- [ ] 代码通过所有测试 (`./scripts/test.sh`)
- [ ] 添加了必要的文档
- [ ] 提交信息清晰描述了更改
- [ ] 代码符合项目风格
- [ ] 没有引入安全漏洞
- [ ] 更新了 CHANGELOG（如适用）

## 报告 Bug

### Bug 报告模板

```markdown
## 描述
[简要描述问题]

## 重现步骤
1. 运行 `./scripts/cowork init`
2. 执行 `...`
3. 观察到错误

## 预期行为
[应该发生什么]

## 实际行为
[实际发生了什么]

## 环境信息
- macOS 版本：
- Lima 版本：`limactl --version`
- Python 版本：`python3 --version`

## 日志
```
[粘贴相关日志]
```
```

### 查看日志

```bash
# Lima logs
tail -f ~/.lima/sandbox/serial*.log

# VM logs
./scripts/cowork exec "journalctl -xe"
```

## 安全问题

如果发现安全漏洞，请**不要**公开报告。请通过邮件联系维护者。

## 社区

### 行为准则

- 尊重所有贡献者
- 提供建设性反馈
- 专注于问题本身
- 欢迎新手提问

### 获取帮助

- 查看 [USAGE.md](USAGE.md)
- 查看已有的 Issues
- 创建新 Issue 提问

## 发布流程

（仅限维护者）

1. 更新版本号
2. 更新 CHANGELOG
3. 创建 Git tag
4. 发布 Release notes

## 参考资料

- [Lima 文档](https://github.com/lima-vm/lima)
- [Apple Virtualization.framework](https://developer.apple.com/documentation/virtualization)
- [Claude Code 文档](https://www.anthropic.com/claude-code)
- [设计文档](docs/02-design.md)

## 许可证

通过贡献代码，您同意您的贡献将在 MIT 许可证下授权。
