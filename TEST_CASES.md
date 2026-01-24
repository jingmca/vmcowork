# Cowork Sandbox 20个测试用例

测试环境：Tmux CC 窗口
测试目录：~/cowork-workspace/test-cases
注意：所有操作仅在 Workspace 内进行

## 准备工作

```bash
# 确保在项目根目录
cd /Users/ten/Downloads/cowork-sandbox

# 确保 VM 正在运行
./scripts/cowork status

# 如果未运行，启动 VM
./scripts/cowork start
```

## 测试用例列表

### 第一组：基础文件操作 (5个)

#### 测试 1: 创建简单 Python 脚本
```bash
./scripts/cowork ask "在 /workspace/test-cases 目录下创建一个 hello.py，打印 'Hello from Cowork Sandbox'"
```

#### 测试 2: 创建多个工具文件
```bash
./scripts/cowork ask "创建三个 Python 工具文件：math_utils.py (数学函数), string_utils.py (字符串处理), file_utils.py (文件操作)"
```

#### 测试 3: 创建项目目录结构
```bash
./scripts/cowork ask "创建标准项目结构：src/, tests/, docs/, config/ 目录"
```

#### 测试 4: 创建配置文件
```bash
./scripts/cowork ask "创建一个 config.json 文件，包含数据库配置示例"
```

#### 测试 5: 创建 README
```bash
./scripts/cowork ask "创建一个 README.md，描述这个测试项目"
```

---

### 第二组：项目管理功能 (5个)

#### 测试 6: 创建 Web 应用项目
```bash
./scripts/cowork ask --project webapp "创建一个简单的 Flask Web 应用，包含基础路由"
```

#### 测试 7: 继续开发 - 添加模板
```bash
./scripts/cowork ask --project webapp -c "添加 HTML 模板文件"
```

#### 测试 8: 创建 API 服务项目
```bash
./scripts/cowork ask --project api-service "使用 FastAPI 创建用户管理 API"
```

#### 测试 9: 创建 CLI 工具项目
```bash
./scripts/cowork ask --project cli-tool "创建命令行工具，使用 argparse"
```

#### 测试 10: 继续开发 - 添加子命令
```bash
./scripts/cowork ask --project cli-tool -c "添加 list 和 search 子命令"
```

---

### 第三组：高级参数测试 (5个)

#### 测试 11: 使用 Haiku 模型
```bash
./scripts/cowork ask --model haiku "创建一个简单的计算器 calculator.py"
```

#### 测试 12: 自定义系统提示
```bash
./scripts/cowork ask --system-prompt "You are a Python expert focusing on clean code" "创建 data_processor.py 遵循最佳实践"
```

#### 测试 13: 限制工具使用（只读）
```bash
./scripts/cowork ask --allowed-tools "Read" "分析当前项目结构并总结"
```

#### 测试 14: JSON 输出格式
```bash
./scripts/cowork ask --output-format json "列出所有创建的 Python 文件" > /workspace/test-cases/output.json
```

#### 测试 15: 组合参数
```bash
./scripts/cowork ask --project combined --model haiku --system-prompt "Write efficient code" "创建一个 utils 模块"
```

---

### 第四组：代码操作 (3个)

#### 测试 16: 修改现有文件
```bash
./scripts/cowork ask -c "给 hello.py 添加错误处理和日志记录"
```

#### 测试 17: 重构代码
```bash
./scripts/cowork ask "重构 math_utils.py，添加类型注解和文档字符串"
```

#### 测试 18: 添加单元测试
```bash
./scripts/cowork ask --project webapp -c "为路由函数添加单元测试"
```

---

### 第五组：查看和清理 (2个)

#### 测试 19: 列出创建的内容
```bash
./scripts/cowork ask "列出 /workspace/test-cases 下所有创建的文件和文件夹"
```

#### 测试 20: 创建测试总结
```bash
./scripts/cowork ask "创建 TEST_SUMMARY.md，记录本次测试中创建的所有内容"
```

---

## 验证方法

在每个测试后，可以使用以下命令验证：

```bash
# 查看 workspace 内容
./scripts/cowork exec "ls -la /workspace/test-cases"

# 查看特定文件
./scripts/cowork exec "cat /workspace/test-cases/hello.py"

# 查看项目目录
./scripts/cowork exec "ls -la /workspace/webapp"

# 进入 VM 手动检查
./scripts/cowork shell
cd /workspace/test-cases
ls -la
cat TEST_SUMMARY.md
exit
```

## 测试结果记录

| 测试编号 | 测试名称 | 状态 | 备注 |
|---------|---------|------|------|
| 1 | 创建 hello.py | ⬜ | |
| 2 | 创建工具文件 | ⬜ | |
| 3 | 创建目录结构 | ⬜ | |
| 4 | 创建配置文件 | ⬜ | |
| 5 | 创建 README | ⬜ | |
| 6 | Web 应用项目 | ⬜ | |
| 7 | 继续开发 Web | ⬜ | |
| 8 | API 服务项目 | ⬜ | |
| 9 | CLI 工具项目 | ⬜ | |
| 10 | 继续开发 CLI | ⬜ | |
| 11 | Haiku 模型 | ⬜ | |
| 12 | 自定义提示 | ⬜ | |
| 13 | 限制工具 | ⬜ | |
| 14 | JSON 输出 | ⬜ | |
| 15 | 组合参数 | ⬜ | |
| 16 | 修改文件 | ⬜ | |
| 17 | 重构代码 | ⬜ | |
| 18 | 添加测试 | ⬜ | |
| 19 | 列出内容 | ⬜ | |
| 20 | 测试总结 | ⬜ | |

✓ = 通过  ✗ = 失败  ⬜ = 未测试

## 清理测试数据

测试完成后，可以清理测试数据：

```bash
# 在 VM 中删除测试目录
./scripts/cowork exec "rm -rf /workspace/test-cases /workspace/webapp /workspace/api-service /workspace/cli-tool /workspace/combined"

# 或者手动进入清理
./scripts/cowork shell
rm -rf /workspace/test-cases /workspace/webapp /workspace/api-service /workspace/cli-tool /workspace/combined
exit
```
