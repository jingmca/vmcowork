#!/bin/bash
#
# Cowork Sandbox Test Suite
# 自动化功能测试脚本
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

print_header() {
    echo -e "${BLUE}╭─────────────────────────────────────╮${NC}"
    echo -e "${BLUE}│    Cowork Sandbox Test Suite        │${NC}"
    echo -e "${BLUE}╰─────────────────────────────────────╯${NC}"
    echo ""
}

print_test() {
    echo -e "${YELLOW}→ Test:${NC} $1"
}

print_pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((PASSED_TESTS++))
}

print_fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((FAILED_TESTS++))
}

run_test() {
    local test_name="$1"
    local test_command="$2"

    ((TOTAL_TESTS++))
    print_test "$test_name"

    if eval "$test_command" > /dev/null 2>&1; then
        print_pass "$test_name"
        return 0
    else
        print_fail "$test_name"
        return 1
    fi
}

print_summary() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "Total Tests:  $TOTAL_TESTS"
    echo -e "${GREEN}Passed:       $PASSED_TESTS${NC}"
    echo -e "${RED}Failed:       $FAILED_TESTS${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"

    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        return 1
    fi
}

# ============================================
# Test Suite
# ============================================

print_header

echo "Prerequisites Check:"
echo ""

# Test 1: Lima installed
run_test "Lima is installed" "command -v limactl"

# Test 2: Python installed
run_test "Python 3 is installed" "command -v python3"

# Test 3: jq installed
run_test "jq is installed" "command -v jq"

# Test 4: cowork script exists
run_test "cowork script exists" "test -x $PROJECT_DIR/scripts/cowork"

# Test 5: controller.py exists
run_test "controller.py exists" "test -f $PROJECT_DIR/host/controller.py"

# Test 6: sandbox.yaml exists
run_test "sandbox.yaml exists" "test -f $PROJECT_DIR/sandbox.yaml"

echo ""
echo "VM Status Tests:"
echo ""

# Test 7: Check if VM can be listed
run_test "Can list VMs" "limactl list --json"

# Test 8: Check VM status function
run_test "VM status command works" "$PROJECT_DIR/scripts/cowork status"

# Test 9: Check if VM is running
if limactl list --json 2>/dev/null | grep -q '"name":"sandbox"'; then
    VM_STATUS=$(limactl list --json | jq -r '.status' 2>/dev/null || echo "unknown")
    if [ "$VM_STATUS" == "Running" ]; then
        print_pass "VM is running"
        ((PASSED_TESTS++))
        ((TOTAL_TESTS++))
        VM_RUNNING=true
    else
        print_fail "VM is not running (status: $VM_STATUS)"
        ((FAILED_TESTS++))
        ((TOTAL_TESTS++))
        VM_RUNNING=false
    fi
else
    echo -e "${YELLOW}! SKIP: VM 'sandbox' does not exist${NC}"
    VM_RUNNING=false
fi

if [ "$VM_RUNNING" = true ]; then
    echo ""
    echo "VM Functionality Tests:"
    echo ""

    # Test 10: Execute simple command in VM
    run_test "Execute command in VM" "$PROJECT_DIR/scripts/cowork exec 'echo test'"

    # Test 11: Check Python in VM
    run_test "Python available in VM" "$PROJECT_DIR/scripts/cowork exec 'python3 --version'"

    # Test 12: Check Node.js in VM
    run_test "Node.js available in VM" "$PROJECT_DIR/scripts/cowork exec 'node --version'"

    # Test 13: Check workspace directory
    run_test "Workspace directory exists" "$PROJECT_DIR/scripts/cowork exec 'test -d /workspace'"

    # Test 14: Write and read file test
    echo ""
    echo "File I/O Tests:"
    echo ""

    TEST_FILE="/workspace/test_$$.txt"
    TEST_CONTENT="Hello from test suite"

    if $PROJECT_DIR/scripts/cowork exec "echo '$TEST_CONTENT' > $TEST_FILE" > /dev/null 2>&1; then
        print_pass "Write file to workspace"
        ((PASSED_TESTS++))
        ((TOTAL_TESTS++))

        READ_CONTENT=$($PROJECT_DIR/scripts/cowork exec "cat $TEST_FILE" 2>/dev/null)
        if [ "$READ_CONTENT" == "$TEST_CONTENT" ]; then
            print_pass "Read file from workspace"
            ((PASSED_TESTS++))
            ((TOTAL_TESTS++))
        else
            print_fail "Read file from workspace"
            ((FAILED_TESTS++))
            ((TOTAL_TESTS++))
        fi

        # Cleanup
        $PROJECT_DIR/scripts/cowork exec "rm -f $TEST_FILE" > /dev/null 2>&1
    else
        print_fail "Write file to workspace"
        ((FAILED_TESTS++))
        ((TOTAL_TESTS++))
    fi

    # Test 15: Python controller status
    echo ""
    echo "Python Controller Tests:"
    echo ""

    run_test "Python controller --status" "python3 $PROJECT_DIR/host/controller.py --status"

    # Test 16: Python controller --exec
    run_test "Python controller --exec" "python3 $PROJECT_DIR/host/controller.py --exec 'echo test'"

    # Test 17: Check if Claude Code is installed
    echo ""
    echo "Claude Code Tests:"
    echo ""

    if $PROJECT_DIR/scripts/cowork exec "command -v claude" > /dev/null 2>&1; then
        print_pass "Claude Code is installed in VM"
        ((PASSED_TESTS++))
        ((TOTAL_TESTS++))

        # Test 18: Check Claude version
        run_test "Claude Code version check" "$PROJECT_DIR/scripts/cowork exec 'claude --version'"
    else
        print_fail "Claude Code is not installed in VM"
        ((FAILED_TESTS++))
        ((TOTAL_TESTS++))
    fi

    # Test 19: Project directory creation
    echo ""
    echo "Project Directory Tests:"
    echo ""

    TEST_PROJECT="test_project_$$"
    if $PROJECT_DIR/scripts/cowork exec "mkdir -p /workspace/$TEST_PROJECT && echo 'test' > /workspace/$TEST_PROJECT/test.txt" > /dev/null 2>&1; then
        print_pass "Create project directory"
        ((PASSED_TESTS++))
        ((TOTAL_TESTS++))

        if $PROJECT_DIR/scripts/cowork exec "test -f /workspace/$TEST_PROJECT/test.txt" > /dev/null 2>&1; then
            print_pass "Access files in project directory"
            ((PASSED_TESTS++))
            ((TOTAL_TESTS++))
        else
            print_fail "Access files in project directory"
            ((FAILED_TESTS++))
            ((TOTAL_TESTS++))
        fi

        # Cleanup
        $PROJECT_DIR/scripts/cowork exec "rm -rf /workspace/$TEST_PROJECT" > /dev/null 2>&1
    else
        print_fail "Create project directory"
        ((FAILED_TESTS++))
        ((TOTAL_TESTS++))
    fi

else
    echo ""
    echo -e "${YELLOW}⚠ Skipping VM functionality tests (VM not running)${NC}"
    echo -e "${YELLOW}  Run './scripts/cowork init' to create and start the VM${NC}"
fi

# Print final summary
print_summary
exit_code=$?

echo ""
echo "For detailed logs, check:"
echo "  ~/.lima/sandbox/serial*.log"
echo ""

exit $exit_code
