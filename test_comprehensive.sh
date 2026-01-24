#!/bin/bash
# Cowork Sandbox 综合测试用例
# 在 Workspace 中测试各种功能

set -e

WORKSPACE="$HOME/cowork-workspace"
TEST_DIR="$WORKSPACE/cowork-tests"

echo "=========================================="
echo "Cowork Sandbox 综合测试 (20个用例)"
echo "=========================================="
echo ""
echo "测试目录: $TEST_DIR"
echo ""

# 确保 Workspace 存在
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# 测试计数器
PASSED=0
FAILED=0
TOTAL=20

run_test() {
    local test_num=$1
    local test_name=$2
    local test_cmd=$3

    echo "[$test_num/$TOTAL] 测试: $test_name"
    echo "命令: $test_cmd"

    if eval "$test_cmd"; then
        echo "✓ 通过"
        ((PASSED++))
    else
        echo "✗ 失败"
        ((FAILED++))
    fi
    echo ""
}

# ==========================================
# 测试用例
# ==========================================

echo "=== 第一组：基础文件操作 ==="
echo ""

# 测试 1: 创建简单 Python 脚本
run_test 1 "创建 Hello World Python 脚本" \
    "tmux send-keys -t cc 'cd $TEST_DIR && ./scripts/cowork ask \"create a simple hello.py that prints hello world\"' Enter && sleep 5"

# 测试 2: 创建多个文件
run_test 2 "创建多个 Python 文件" \
    "tmux send-keys -t cc './scripts/cowork ask \"create three python files: math_utils.py, string_utils.py, file_utils.py with basic functions\"' Enter && sleep 5"

# 测试 3: 创建目录结构
run_test 3 "创建项目目录结构" \
    "tmux send-keys -t cc './scripts/cowork ask \"create a project structure with folders: src/, tests/, docs/, config/\"' Enter && sleep 5"

# 测试 4: 写入配置文件
run_test 4 "创建 JSON 配置文件" \
    "tmux send-keys -t cc './scripts/cowork ask \"create a config.json with sample configuration\"' Enter && sleep 5"

# 测试 5: 创建 README
run_test 5 "创建 README.md" \
    "tmux send-keys -t cc './scripts/cowork ask \"create a README.md for this test project\"' Enter && sleep 5"

echo "=== 第二组：项目管理功能 ==="
echo ""

# 测试 6: 使用项目目录 - webapp
run_test 6 "项目: 创建 Web 应用" \
    "tmux send-keys -t cc './scripts/cowork ask --project webapp \"create a simple flask app with routes\"' Enter && sleep 8"

# 测试 7: 项目持续 - webapp
run_test 7 "项目: 继续开发 (添加模板)" \
    "tmux send-keys -t cc './scripts/cowork ask --project webapp -c \"add html templates\"' Enter && sleep 8"

# 测试 8: 新项目 - api
run_test 8 "项目: 创建 API 服务" \
    "tmux send-keys -t cc './scripts/cowork ask --project api \"create a FastAPI service with user endpoints\"' Enter && sleep 8"

# 测试 9: 新项目 - cli
run_test 9 "项目: 创建 CLI 工具" \
    "tmux send-keys -t cc './scripts/cowork ask --project cli-tool \"create a command-line tool using argparse\"' Enter && sleep 8"

# 测试 10: 项目持续 - cli
run_test 10 "项目: 继续开发 (添加功能)" \
    "tmux send-keys -t cc './scripts/cowork ask --project cli-tool -c \"add subcommands for list and search\"' Enter && sleep 8"

echo "=== 第三组：高级参数测试 ==="
echo ""

# 测试 11: 使用不同模型
run_test 11 "参数: 使用 Haiku 模型" \
    "tmux send-keys -t cc './scripts/cowork ask --model haiku \"create a simple calculator.py\"' Enter && sleep 5"

# 测试 12: 自定义系统提示
run_test 12 "参数: 自定义系统提示" \
    "tmux send-keys -t cc './scripts/cowork ask --system-prompt \"You are a Python expert\" \"create best practices code for data_processor.py\"' Enter && sleep 8"

# 测试 13: 限制工具使用
run_test 13 "参数: 限制工具 (只读)" \
    "tmux send-keys -t cc './scripts/cowork ask --allowed-tools \"Read\" \"analyze the project structure\"' Enter && sleep 5"

# 测试 14: JSON 输出格式
run_test 14 "参数: JSON 输出格式" \
    "tmux send-keys -t cc './scripts/cowork ask --output-format json \"list all python files created\" > output.json' Enter && sleep 5"

# 测试 15: 组合参数使用
run_test 15 "参数: 组合使用多个参数" \
    "tmux send-keys -t cc './scripts/cowork ask --project combined-test --model haiku --system-prompt \"Write clean code\" \"create a utils module\"' Enter && sleep 8"

echo "=== 第四组：代码操作 ==="
echo ""

# 测试 16: 修改现有文件
run_test 16 "代码: 修改现有文件" \
    "tmux send-keys -t cc './scripts/cowork ask -c \"add error handling to hello.py\"' Enter && sleep 5"

# 测试 17: 重构代码
run_test 17 "代码: 重构代码" \
    "tmux send-keys -t cc './scripts/cowork ask \"refactor math_utils.py to add type hints\"' Enter && sleep 5"

# 测试 18: 添加测试
run_test 18 "代码: 添加单元测试" \
    "tmux send-keys -t cc './scripts/cowork ask --project webapp -c \"add unit tests for routes\"' Enter && sleep 8"

echo "=== 第五组：清理操作 ==="
echo ""

# 测试 19: 列出所有创建的文件
run_test 19 "查看: 列出创建的文件" \
    "tmux send-keys -t cc './scripts/cowork ask \"list all files and folders created in this session\"' Enter && sleep 5"

# 测试 20: 创建测试报告
run_test 20 "文档: 创建测试总结" \
    "tmux send-keys -t cc './scripts/cowork ask \"create a TEST_SUMMARY.md documenting what was created\"' Enter && sleep 5"

echo ""
echo "=========================================="
echo "测试完成!"
echo "=========================================="
echo "通过: $PASSED / $TOTAL"
echo "失败: $FAILED / $TOTAL"
echo ""
echo "测试目录: $TEST_DIR"
echo "查看结果: cd $TEST_DIR && ls -la"
echo ""
