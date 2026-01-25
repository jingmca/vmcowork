#!/bin/bash
#
# Test: Isolated Sandbox Mode
# Verifies that two independent VMs can mount different directories to the same path
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COWORK="$PROJECT_DIR/scripts/cowork"

# Test configuration
WORK_DIR="$HOME/cowork-test-isolated"
DIR_A="$WORK_DIR/project-a"
DIR_B="$WORK_DIR/project-b"
VM_A="sandbox-test-a"
VM_B="sandbox-test-b"
TEST_FILE="config.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

cleanup() {
    log_info "Cleaning up test resources..."

    # Stop and delete test VMs
    limactl stop "$VM_A" 2>/dev/null || true
    limactl stop "$VM_B" 2>/dev/null || true
    limactl delete "$VM_A" -f 2>/dev/null || true
    limactl delete "$VM_B" -f 2>/dev/null || true

    # Remove test directories
    rm -rf "$WORK_DIR"

    log_info "Cleanup complete"
}

# Parse arguments
if [ "$1" == "--cleanup" ]; then
    cleanup
    exit 0
fi

echo "=============================================="
echo "  Isolated Sandbox Mode Test"
echo "=============================================="
echo ""

# Step 1: Prepare test directories and files
log_info "Step 1: Creating test directories and files..."

mkdir -p "$DIR_A"
mkdir -p "$DIR_B"

# Create same-named file with different content
echo "This is Project A - Content from directory A" > "$DIR_A/$TEST_FILE"
echo "This is Project B - Content from directory B" > "$DIR_B/$TEST_FILE"

log_info "Created $DIR_A/$TEST_FILE with content: 'This is Project A...'"
log_info "Created $DIR_B/$TEST_FILE with content: 'This is Project B...'"
log_pass "Test files created"
echo ""

# Step 2: Create two independent VMs with different mounts
log_info "Step 2: Creating two independent sandbox VMs..."
log_info "This may take several minutes for first-time VM creation..."
echo ""

log_info "Creating VM '$VM_A' with mount: $DIR_A -> /workspace"
$COWORK --vm-name "$VM_A" --mount "$DIR_A:/workspace" init

echo ""
log_info "Creating VM '$VM_B' with mount: $DIR_B -> /workspace"
$COWORK --vm-name "$VM_B" --mount "$DIR_B:/workspace" init

log_pass "Both VMs created"
echo ""

# Step 3: Verify file contents in each VM
log_info "Step 3: Verifying file contents in each VM..."
echo ""

# Read file from VM A
log_info "Reading /workspace/$TEST_FILE from VM '$VM_A'..."
CONTENT_A=$(limactl shell "$VM_A" -- cat "/workspace/$TEST_FILE" 2>/dev/null)
echo "  Content: '$CONTENT_A'"

# Read file from VM B
log_info "Reading /workspace/$TEST_FILE from VM '$VM_B'..."
CONTENT_B=$(limactl shell "$VM_B" -- cat "/workspace/$TEST_FILE" 2>/dev/null)
echo "  Content: '$CONTENT_B'"
echo ""

# Step 4: Validate results
log_info "Step 4: Validating isolation..."
echo ""

PASSED=true

# Check VM A has correct content
if [[ "$CONTENT_A" == *"Project A"* ]]; then
    log_pass "VM '$VM_A' correctly shows Project A content"
else
    log_fail "VM '$VM_A' has unexpected content: '$CONTENT_A'"
    PASSED=false
fi

# Check VM B has correct content
if [[ "$CONTENT_B" == *"Project B"* ]]; then
    log_pass "VM '$VM_B' correctly shows Project B content"
else
    log_fail "VM '$VM_B' has unexpected content: '$CONTENT_B'"
    PASSED=false
fi

# Check contents are different
if [[ "$CONTENT_A" != "$CONTENT_B" ]]; then
    log_pass "Contents are different (isolation verified)"
else
    log_fail "Contents are the same (isolation failed)"
    PASSED=false
fi

echo ""
echo "=============================================="
if [ "$PASSED" = true ]; then
    log_pass "ALL TESTS PASSED - Isolated sandbox mode works correctly!"
    echo ""
    echo "Summary:"
    echo "  - VM '$VM_A' sees: $DIR_A mounted at /workspace"
    echo "  - VM '$VM_B' sees: $DIR_B mounted at /workspace"
    echo "  - Same path (/workspace/$TEST_FILE) shows different content"
    echo ""
    echo "To cleanup test resources, run:"
    echo "  $0 --cleanup"
else
    log_fail "SOME TESTS FAILED"
    echo ""
    echo "To cleanup and retry, run:"
    echo "  $0 --cleanup"
fi
echo "=============================================="

exit $([ "$PASSED" = true ] && echo 0 || echo 1)
