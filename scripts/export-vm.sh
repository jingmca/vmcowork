#!/bin/bash
#
# export-vm.sh - Export configured VM as a distributable package
# Usage: ./scripts/export-vm.sh [vm-name] [output-file]
#

set -e

VM_NAME="${1:-sandbox}"
OUTPUT_FILE="${2:-cowork-sandbox-apple-silicon.tar.gz}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[DONE]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

# Check if Lima is installed
if ! command -v limactl &> /dev/null; then
    log_fail "Lima is not installed"
    exit 1
fi

# Check if VM exists
if ! limactl list --json | jq -e "if type == \"array\" then .[] else . end | select(.name == \"$VM_NAME\")" > /dev/null 2>&1; then
    log_fail "VM '$VM_NAME' not found"
    exit 1
fi

# Stop VM if running
log_info "Stopping VM '$VM_NAME'..."
limactl stop "$VM_NAME" 2>/dev/null || true

VM_DIR="$HOME/.lima/$VM_NAME"

if [ ! -d "$VM_DIR" ]; then
    log_fail "VM directory not found: $VM_DIR"
    exit 1
fi

log_info "Exporting VM from: $VM_DIR"
log_info "Output file: $OUTPUT_FILE"

# Create temp directory for export
EXPORT_DIR=$(mktemp -d)
trap "rm -rf $EXPORT_DIR" EXIT

# Copy VM files (exclude socket files and logs)
log_info "Copying VM files..."
mkdir -p "$EXPORT_DIR/vm"
cp -r "$VM_DIR"/*.yaml "$EXPORT_DIR/vm/" 2>/dev/null || true
cp -r "$VM_DIR"/basedisk "$EXPORT_DIR/vm/" 2>/dev/null || true
cp -r "$VM_DIR"/diffdisk "$EXPORT_DIR/vm/" 2>/dev/null || true
cp -r "$VM_DIR"/cidata* "$EXPORT_DIR/vm/" 2>/dev/null || true

# Create metadata
cat > "$EXPORT_DIR/metadata.json" << EOF
{
  "name": "$VM_NAME",
  "arch": "aarch64",
  "os": "ubuntu-22.04",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "lima_version": "$(limactl --version | head -1)",
  "includes": ["python3", "nodejs", "claude-code", "pandas", "sqlite3"]
}
EOF

# Compress
log_info "Compressing (this may take a while)..."
cd "$EXPORT_DIR"
tar -czf "$OLDPWD/$OUTPUT_FILE" .

cd "$OLDPWD"
SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)

log_pass "Export complete!"
echo ""
echo "Output: $OUTPUT_FILE ($SIZE)"
echo ""
echo "To use this package:"
echo "  1. Download and extract to ~/.lima/$VM_NAME/"
echo "  2. Run: limactl start $VM_NAME"
echo "  3. Or use: ./scripts/install.sh"
