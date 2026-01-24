#!/bin/bash
# 自动化测试脚本 - 在 workspace 中执行 20 个测试用例

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试计数
TOTAL=20
PASSED=0
FAILED=0

# 测试结果数组
declare -a TEST_RESULTS

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Cowork Sandbox 综合测试 (20个用例)  ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# 测试函数
run_test() {
    local test_num=$1
    local test_name=$2
    local test_cmd=$3
    local verify_cmd=$4
    local wait_time=${5:-15}

    echo -e "${YELLOW}[$test_num/$TOTAL]${NC} $test_name"
    echo -e "${BLUE}命令:${NC} $test_cmd"

    # 执行命令
    eval "$test_cmd" 2>&1 | head -5

    # 等待执行完成
    echo -e "${YELLOW}等待 ${wait_time}秒...${NC}"
    sleep $wait_time

    # 验证结果
    if [ -n "$verify_cmd" ]; then
        echo -e "${BLUE}验证:${NC} $verify_cmd"
        if eval "$verify_cmd" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ 通过${NC}"
            ((PASSED++))
            TEST_RESULTS[$test_num]="✓"
        else
            echo -e "${RED}✗ 失败${NC}"
            ((FAILED++))
            TEST_RESULTS[$test_num]="✗"
        fi
    else
        echo -e "${YELLOW}⊙ 已执行（未验证）${NC}"
        TEST_RESULTS[$test_num]="⊙"
    fi

    echo ""
}

# 第一组：基础文件操作
echo -e "${BLUE}=== 第一组：基础文件操作 ===${NC}"
echo ""

run_test 1 "创建 hello.py" \
    "./scripts/cowork ask \"在 /workspace/test-cases 创建 hello.py，打印 Hello from Cowork\"" \
    "./scripts/cowork exec 'test -f /workspace/test-cases/hello.py'" \
    20

run_test 2 "创建工具文件" \
    "./scripts/cowork ask \"创建 math_utils.py, string_utils.py, file_utils.py 在 /workspace/test-cases\"" \
    "./scripts/cowork exec 'test -f /workspace/test-cases/math_utils.py'" \
    20

run_test 3 "创建目录结构" \
    "./scripts/cowork ask \"在 /workspace/test-cases 创建 src/, tests/, docs/, config/ 目录\"" \
    "./scripts/cowork exec 'test -d /workspace/test-cases/src'" \
    15

run_test 4 "创建配置文件" \
    "./scripts/cowork ask \"创建 /workspace/test-cases/config.json 包含数据库配置\"" \
    "./scripts/cowork exec 'test -f /workspace/test-cases/config.json'" \
    15

run_test 5 "创建 README" \
    "./scripts/cowork ask \"创建 /workspace/test-cases/README.md 描述项目\"" \
    "./scripts/cowork exec 'test -f /workspace/test-cases/README.md'" \
    15

# 第二组：项目管理
echo -e "${BLUE}=== 第二组：项目管理功能 ===${NC}"
echo ""

run_test 6 "创建 Web 应用" \
    "./scripts/cowork ask --project webapp \"创建 Flask 应用\"" \
    "./scripts/cowork exec 'test -d /workspace/webapp'" \
    25

run_test 7 "继续开发 Web" \
    "./scripts/cowork ask --project webapp -c \"添加 HTML 模板\"" \
    "./scripts/cowork exec 'ls /workspace/webapp/*.html || ls /workspace/webapp/templates/*.html'" \
    25

run_test 8 "创建 API 服务" \
    "./scripts/cowork ask --project api-service \"创建 FastAPI 用户 API\"" \
    "./scripts/cowork exec 'test -d /workspace/api-service'" \
    25

run_test 9 "创建 CLI 工具" \
    "./scripts/cowork ask --project cli-tool \"创建 argparse CLI 工具\"" \
    "./scripts/cowork exec 'test -d /workspace/cli-tool'" \
    25

run_test 10 "继续开发 CLI" \
    "./scripts/cowork ask --project cli-tool -c \"添加 list 和 search 子命令\"" \
    "" \
    25

# 第三组：高级参数
echo -e "${BLUE}=== 第三组：高级参数测试 ===${NC}"
echo ""

run_test 11 "使用 Haiku 模型" \
    "./scripts/cowork ask --model haiku \"创建 calculator.py 在 /workspace/test-cases\"" \
    "./scripts/cowork exec 'test -f /workspace/test-cases/calculator.py'" \
    20

run_test 12 "自定义系统提示" \
    "./scripts/cowork ask --system-prompt \"Python expert\" \"创建 data_processor.py 在 /workspace/test-cases\"" \
    "./scripts/cowork exec 'test -f /workspace/test-cases/data_processor.py'" \
    20

run_test 13 "限制工具（只读）" \
    "./scripts/cowork ask --allowed-tools Read \"分析 /workspace/test-cases 结构\"" \
    "" \
    15

run_test 14 "JSON 输出" \
    "./scripts/cowork ask --output-format json \"列出 /workspace/test-cases Python 文件\"" \
    "" \
    15

run_test 15 "组合参数" \
    "./scripts/cowork ask --project combined --model haiku \"创建 utils 模块\"" \
    "./scripts/cowork exec 'test -d /workspace/combined'" \
    25

# 第四组：代码操作
echo -e "${BLUE}=== 第四组：代码操作 ===${NC}"
echo ""

run_test 16 "修改 hello.py" \
    "./scripts/cowork ask \"给 /workspace/test-cases/hello.py 添加错误处理\"" \
    "" \
    20

run_test 17 "重构 math_utils" \
    "./scripts/cowork ask \"给 /workspace/test-cases/math_utils.py 添加类型注解\"" \
    "" \
    20

run_test 18 "添加单元测试" \
    "./scripts/cowork ask --project webapp -c \"添加单元测试\"" \
    "" \
    25

# 第五组：查看和总结
echo -e "${BLUE}=== 第五组：查看和清理 ===${NC}"
echo ""

run_test 19 "列出创建的文件" \
    "./scripts/cowork ask \"列出 /workspace 下所有测试相关目录\"" \
    "" \
    15

run_test 20 "创建测试总结" \
    "./scripts/cowork ask \"创建 /workspace/test-cases/TEST_SUMMARY.md 总结所有创建的内容\"" \
    "./scripts/cowork exec 'test -f /workspace/test-cases/TEST_SUMMARY.md'" \
    20

# 打印测试结果
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}            测试完成报告              ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo -e "总计: $TOTAL 个测试"
echo -e "${GREEN}通过: $PASSED${NC}"
echo -e "${RED}失败: $FAILED${NC}"
echo -e "未验证: $((TOTAL - PASSED - FAILED))"
echo ""

# 打印详细结果表格
echo -e "${BLUE}详细结果：${NC}"
echo "┌──────┬───────────────────────────┬────────┐"
echo "│ 编号 │ 测试名称                  │ 结果   │"
echo "├──────┼───────────────────────────┼────────┤"

test_names=(
    "创建 hello.py"
    "创建工具文件"
    "创建目录结构"
    "创建配置文件"
    "创建 README"
    "创建 Web 应用"
    "继续开发 Web"
    "创建 API 服务"
    "创建 CLI 工具"
    "继续开发 CLI"
    "使用 Haiku 模型"
    "自定义系统提示"
    "限制工具"
    "JSON 输出"
    "组合参数"
    "修改 hello.py"
    "重构 math_utils"
    "添加单元测试"
    "列出文件"
    "创建总结"
)

for i in {1..20}; do
    printf "│ %4d │ %-25s │ %s      │\n" $i "${test_names[$i-1]}" "${TEST_RESULTS[$i]:-⊙}"
done

echo "└──────┴───────────────────────────┴────────┘"
echo ""

# 显示创建的内容
echo -e "${BLUE}查看创建的内容：${NC}"
echo "./scripts/cowork exec 'ls -la /workspace/'"
echo "./scripts/cowork exec 'ls -la /workspace/test-cases/'"
echo "./scripts/cowork exec 'cat /workspace/test-cases/TEST_SUMMARY.md'"
echo ""

# 清理提示
echo -e "${YELLOW}清理测试数据：${NC}"
echo "./scripts/cowork exec 'rm -rf /workspace/test-cases /workspace/webapp /workspace/api-service /workspace/cli-tool /workspace/combined'"
echo ""
