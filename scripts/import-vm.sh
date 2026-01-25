#!/bin/bash
#
# import-vm.sh - Import VM from pre-built package
# Usage: ./scripts/import-vm.sh <package-file> [vm-name]
#

set -e

PKG_FILE="${1:-cowork-sandbox-apple-silicon.tar.gz}"
VM_NAME="${2:-sandbox}"
LIMA_VM_DIR="$HOME/.lima/$VM_NAME"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${YELLOW}→${NC} $1"; }
log_pass() { echo -e "${GREEN}✓${NC} $1"; }
log_fail() { echo -e "${RED}✗${NC} $1"; exit 1; }

# Check if package exists
if [ ! -f "$PKG_FILE" ]; then
    log_fail "Package file not found: $PKG_FILE"
fi

# Check if Lima is installed
if ! command -v limactl &> /dev/null; then
    log_fail "Lima is not installed. Run: brew install lima"
fi

# Check if VM already exists
if [ -d "$LIMA_VM_DIR" ]; then
    log_info "VM '$VM_NAME' already exists."
    read -p "Delete and replace? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Stopping and deleting existing VM..."
        limactl stop "$VM_NAME" 2>/dev/null || true
        limactl delete "$VM_NAME" -f 2>/dev/null || true
    else
        log_info "Cancelled"
        exit 0
    fi
fi

# Extract package
log_info "Extracting package: $PKG_FILE"

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

tar -xzf "$PKG_FILE" -C "$TMP_DIR"

# Check package contents
if [ ! -d "$TMP_DIR/vm" ]; then
    log_fail "Invalid package: missing 'vm' directory"
fi

# Show metadata if available
if [ -f "$TMP_DIR/metadata.json" ]; then
    log_info "Package info:"
    cat "$TMP_DIR/metadata.json" | jq -r '
        "  Created: \(.created // "unknown")",
        "  Includes: \(.includes // [] | join(", "))"
    ' 2>/dev/null || true
fi

# Copy VM files
log_info "Importing VM to $LIMA_VM_DIR"
mkdir -p "$LIMA_VM_DIR"
cp -r "$TMP_DIR/vm"/* "$LIMA_VM_DIR/"

log_pass "VM imported successfully"

# Start VM
log_info "Starting VM..."
if limactl start "$VM_NAME"; then
    log_pass "VM '$VM_NAME' is ready!"
    echo ""
    echo "Usage:"
    echo "  cowork status"
    echo "  cowork ask \"hello\""
else
    log_fail "Failed to start VM. Check: limactl list"
fi
