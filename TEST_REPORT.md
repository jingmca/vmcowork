# Cowork Sandbox 测试执行报告

测试日期：2026-01-25
测试环境：macOS + Lima VM
Claude Code 版本：2.1.19

## 测试概述

本测试旨在验证 Cowork Sandbox v0.4.0 的所有功能，包括：
- 基础文件操作
- 项目管理功能
- 高级参数支持
- 代码编辑能力
- 持续对话功能

## 测试环境

- **宿主机**: macOS (Apple Silicon)
- **VM**: Ubuntu 22.04 ARM64 (Lima)
- **Python**: 3.10.12
- **Node.js**: v22.22.0
- **Claude Code**: 2.1.19
- **Workspace**: /workspace

## 测试用例 (20个)

### 第一组：基础文件操作 (5个)

| # | 测试名称 | 命令 | 预期结果 | 实际结果 | 状态 |
|---|---------|------|---------|---------|------|
| 1 | 创建 hello.py | `cowork ask "创建 hello.py"` | 文件存在 | | ⬜ |
| 2 | 创建工具文件 | `cowork ask "创建 utils 文件"` | 3个文件存在 | | ⬜ |
| 3 | 创建目录结构 | `cowork ask "创建目录"` | 4个目录存在 | | ⬜ |
| 4 | 创建配置文件 | `cowork ask "创建 config.json"` | JSON文件存在 | | ⬜ |
| 5 | 创建 README | `cowork ask "创建 README.md"` | Markdown存在 | | ⬜ |

### 第二组：项目管理功能 (5个)

| # | 测试名称 | 命令 | 预期结果 | 实际结果 | 状态 |
|---|---------|------|---------|---------|------|
| 6 | 创建 Web 应用 | `cowork ask --project webapp "Flask"` | webapp目录存在 | | ⬜ |
| 7 | 继续开发 Web | `cowork ask --project webapp -c "模板"` | 模板文件存在 | | ⬜ |
| 8 | 创建 API 服务 | `cowork ask --project api-service "FastAPI"` | api目录存在 | | ⬜ |
| 9 | 创建 CLI 工具 | `cowork ask --project cli-tool "argparse"` | cli目录存在 | | ⬜ |
| 10 | 继续开发 CLI | `cowork ask --project cli-tool -c "子命令"` | 更新的代码 | | ⬜ |

### 第三组：高级参数测试 (5个)

| # | 测试名称 | 命令 | 预期结果 | 实际结果 | 状态 |
|---|---------|------|---------|---------|------|
| 11 | Haiku 模型 | `cowork ask --model haiku "calculator"` | 文件存在 | | ⬜ |
| 12 | 系统提示 | `cowork ask --system-prompt "expert" "code"` | 高质量代码 | | ⬜ |
| 13 | 限制工具 | `cowork ask --allowed-tools Read "分析"` | 只读操作 | | ⬜ |
| 14 | JSON 输出 | `cowork ask --output-format json "列表"` | JSON格式 | | ⬜ |
| 15 | 组合参数 | `cowork ask --project x --model haiku "任务"` | 正常工作 | | ⬜ |

### 第四组：代码操作 (3个)

| # | 测试名称 | 命令 | 预期结果 | 实际结果 | 状态 |
|---|---------|------|---------|---------|------|
| 16 | 修改文件 | `cowork ask "修改 hello.py"` | 文件已修改 | | ⬜ |
| 17 | 重构代码 | `cowork ask "重构 math_utils"` | 代码改进 | | ⬜ |
| 18 | 添加测试 | `cowork ask --project webapp -c "测试"` | 测试文件 | | ⬜ |

### 第五组：查看和清理 (2个)

| # | 测试名称 | 命令 | 预期结果 | 实际结果 | 状态 |
|---|---------|------|---------|---------|------|
| 19 | 列出文件 | `cowork ask "列出所有文件"` | 文件列表 | | ⬜ |
| 20 | 创建总结 | `cowork ask "创建 SUMMARY.md"` | 总结文件 | | ⬜ |

## 测试执行方式

### 自动化测试

```bash
# 运行完整测试套件
./run_tests.sh
```

### 手动测试

参考 `TEST_CASES.md` 文件，逐个执行测试命令。

## 验证命令

```bash
# 查看 workspace 内容
./scripts/cowork exec "ls -la /workspace/"

# 查看测试目录
./scripts/cowork exec "ls -la /workspace/test-cases/"

# 查看项目目录
./scripts/cowork exec "ls -la /workspace/webapp/"

# 查看文件内容
./scripts/cowork exec "cat /workspace/test-cases/hello.py"

# 进入 VM 手动检查
./scripts/cowork shell
```

## 测试结果统计

- **总计**: 20 个测试
- **通过**: 0
- **失败**: 0
- **未执行**: 20
- **成功率**: 0%

## 发现的问题

_待记录_

## 改进建议

_待记录_

## 测试环境清理

```bash
# 清理所有测试数据
./scripts/cowork exec "rm -rf /workspace/test-cases /workspace/webapp /workspace/api-service /workspace/cli-tool /workspace/combined"

# 验证清理
./scripts/cowork exec "ls -la /workspace/"
```

## 附注

- 所有操作仅在 /workspace 目录内进行
- 不会影响宿主机文件系统
- VM 可以随时重建而不影响测试
- 测试数据可以轻松清理

## 测试脚本

1. `run_tests.sh` - 自动化测试脚本（推荐）
2. `TEST_CASES.md` - 手动测试指南
3. `test_comprehensive.sh` - 备用测试脚本

## 下一步

1. 执行 `./run_tests.sh` 开始测试
2. 记录每个测试的结果
3. 更新本报告中的状态
4. 总结发现的问题
5. 提出改进建议
