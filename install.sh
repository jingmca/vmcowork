#!/bin/bash
#
# Cowork Sandbox - One-click installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/anthropics/cowork-sandbox/main/install.sh | bash
#
# Or:
#   wget -qO- https://raw.githubusercontent.com/anthropics/cowork-sandbox/main/install.sh | bash
#

set -e

# Configuration
REPO_URL="https://github.com/jingmca/vmcowork"  # Update with actual URL
REPO_BRANCH="main"
INSTALL_DIR="$HOME/.vmcowork"
VM_NAME="sandbox"
LIMA_VM_DIR="$HOME/.lima/$VM_NAME"

# Pre-built binaries (update URLs for actual releases)
LIMA_VERSION="1.0.6"
LIMA_ARM64_URL="https://github.com/lima-vm/lima/releases/download/v${LIMA_VERSION}/lima-${LIMA_VERSION}-Darwin-arm64.tar.gz"
JQ_ARM64_URL="https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-macos-arm64"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_banner() {
    echo ""
    echo -e "${BLUE}╭─────────────────────────────────────╮${NC}"
    echo -e "${BLUE}│     VMCowork Installer        │${NC}"
    echo -e "${BLUE}│     Claude Code in Isolated VM      │${NC}"
    echo -e "${BLUE}╰─────────────────────────────────────╯${NC}"
    echo ""
}

log_info() { echo -e "${YELLOW}→${NC} $1"; }
log_pass() { echo -e "${GREEN}✓${NC} $1"; }
log_fail() { echo -e "${RED}✗${NC} $1"; exit 1; }

check_system() {
    # Check macOS
    if [ "$(uname)" != "Darwin" ]; then
        log_fail "This installer is for macOS only"
    fi

    # Check architecture
    ARCH=$(uname -m)
    if [ "$ARCH" != "arm64" ] && [ "$ARCH" != "aarch64" ]; then
        log_fail "This installer is for Apple Silicon (arm64) only. Your arch: $ARCH"
    fi

    log_pass "System check passed (macOS Apple Silicon)"
}

install_lima() {
    if command -v limactl &> /dev/null; then
        log_pass "Lima is already installed: $(limactl --version | head -1)"
        return
    fi

    log_info "Installing Lima..."

    # Try Homebrew first (preferred)
    if command -v brew &> /dev/null; then
        brew install lima
        log_pass "Lima installed via Homebrew"
        return
    fi

    # Fallback: download binary directly
    log_info "Homebrew not found, downloading Lima binary..."

    local tmp_dir=$(mktemp -d)
    local lima_tar="$tmp_dir/lima.tar.gz"

    curl -fsSL -o "$lima_tar" "$LIMA_ARM64_URL" || log_fail "Failed to download Lima"

    mkdir -p "$INSTALL_DIR/bin"
    tar -xzf "$lima_tar" -C "$INSTALL_DIR"

    # Add to PATH for this session
    export PATH="$INSTALL_DIR/bin:$PATH"

    rm -rf "$tmp_dir"

    if command -v limactl &> /dev/null; then
        log_pass "Lima installed to $INSTALL_DIR/bin"
    else
        log_fail "Lima installation failed"
    fi
}

install_jq() {
    if command -v jq &> /dev/null; then
        log_pass "jq is already installed"
        return
    fi

    log_info "Installing jq..."

    # Try Homebrew first
    if command -v brew &> /dev/null; then
        brew install jq
        log_pass "jq installed via Homebrew"
        return
    fi

    # Fallback: download binary directly
    log_info "Downloading jq binary..."

    mkdir -p "$INSTALL_DIR/bin"
    curl -fsSL -o "$INSTALL_DIR/bin/jq" "$JQ_ARM64_URL" || log_fail "Failed to download jq"
    chmod +x "$INSTALL_DIR/bin/jq"

    export PATH="$INSTALL_DIR/bin:$PATH"

    if command -v jq &> /dev/null; then
        log_pass "jq installed to $INSTALL_DIR/bin"
    else
        log_fail "jq installation failed"
    fi
}

clone_repo() {
    if [ -d "$INSTALL_DIR/repo" ]; then
        log_info "Updating existing installation..."
        cd "$INSTALL_DIR/repo"
        git pull origin "$REPO_BRANCH" 2>/dev/null || true
        log_pass "Repository updated"
        return
    fi

    log_info "Downloading Cowork Sandbox..."

    mkdir -p "$INSTALL_DIR"

    if command -v git &> /dev/null; then
        git clone --depth 1 -b "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR/repo"
        log_pass "Repository cloned"
    else
        # Fallback: download as zip
        log_info "Git not found, downloading as archive..."
        local zip_url="$REPO_URL/archive/refs/heads/$REPO_BRANCH.zip"
        local tmp_zip=$(mktemp)

        curl -fsSL -o "$tmp_zip" "$zip_url" || log_fail "Failed to download repository"

        unzip -q "$tmp_zip" -d "$INSTALL_DIR"
        mv "$INSTALL_DIR/cowork-sandbox-$REPO_BRANCH" "$INSTALL_DIR/repo"
        rm "$tmp_zip"

        log_pass "Repository downloaded"
    fi
}

download_prebuilt_vm() {
    local pkg_file="cowork-sandbox-apple-silicon.tar.gz"
    local pkg_url="$REPO_URL/releases/latest/download/$pkg_file"
    local pkg_path="$INSTALL_DIR/$pkg_file"

    # Skip if already have VM
    if [ -d "$LIMA_VM_DIR" ]; then
        log_info "VM already exists, skipping download"
        return 0
    fi

    # Check if package already downloaded
    if [ -f "$pkg_path" ]; then
        log_info "Using cached pre-built package"
        return 0
    fi

    log_info "Downloading pre-built VM package (this speeds up installation)..."

    if curl -fsSL -o "$pkg_path" "$pkg_url" 2>/dev/null; then
        log_pass "Downloaded pre-built VM package"
        return 0
    else
        log_info "Pre-built package not available, will build from scratch"
        return 1
    fi
}

install_prebuilt_vm() {
    local pkg_path="$INSTALL_DIR/cowork-sandbox-apple-silicon.tar.gz"

    if [ ! -f "$pkg_path" ]; then
        return 1
    fi

    if [ -d "$LIMA_VM_DIR" ]; then
        log_info "VM already exists"
        return 0
    fi

    log_info "Extracting VM package..."

    local tmp_dir=$(mktemp -d)
    tar -xzf "$pkg_path" -C "$tmp_dir"

    if [ -d "$tmp_dir/vm" ]; then
        mkdir -p "$LIMA_VM_DIR"
        cp -r "$tmp_dir/vm"/* "$LIMA_VM_DIR/"
        log_pass "VM extracted"
    fi

    rm -rf "$tmp_dir"
    return 0
}

build_vm() {
    log_info "Building VM from scratch (this may take 5-10 minutes)..."
    log_info "You can monitor progress in another terminal:"
    echo "    tail -f ~/.lima/$VM_NAME/provision.log"
    echo ""

    mkdir -p "$HOME/Downloads/cowork-workspace"

    cd "$INSTALL_DIR/repo"
    limactl start --name="$VM_NAME" sandbox.yaml

    log_pass "VM built successfully"
}

start_vm() {
    local status
    status=$(limactl list --json 2>/dev/null | jq -r "if type == \"array\" then .[] | select(.name == \"$VM_NAME\") | .status else if .name == \"$VM_NAME\" then .status else \"NotFound\" end end" 2>/dev/null || echo "NotFound")

    if [ "$status" == "Running" ]; then
        log_pass "VM is running"
        return 0
    fi

    if [ "$status" == "Stopped" ]; then
        log_info "Starting VM..."
        limactl start "$VM_NAME"
        log_pass "VM started"
        return 0
    fi

    # VM doesn't exist
    return 1
}

setup_path() {
    local cowork_bin="$INSTALL_DIR/repo/scripts"
    local shell_rc=""

    # Detect shell
    case "$SHELL" in
        */zsh)  shell_rc="$HOME/.zshrc" ;;
        */bash) shell_rc="$HOME/.bashrc" ;;
        *)      shell_rc="$HOME/.profile" ;;
    esac

    # Check if already in PATH
    if grep -q "cowork-sandbox" "$shell_rc" 2>/dev/null; then
        return
    fi

    # Add to shell config
    echo "" >> "$shell_rc"
    echo "# Cowork Sandbox" >> "$shell_rc"
    echo "export PATH=\"$cowork_bin:\$PATH\"" >> "$shell_rc"

    if [ -d "$INSTALL_DIR/bin" ]; then
        echo "export PATH=\"$INSTALL_DIR/bin:\$PATH\"" >> "$shell_rc"
    fi

    log_pass "Added to PATH in $shell_rc"
}

print_success() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  To start using Cowork Sandbox:"
    echo ""
    echo "  1. Configure API credentials (required):"
    echo ""
    echo -e "     ${YELLOW}export ANTHROPIC_AUTH_TOKEN=\"your-api-token\"${NC}"
    echo -e "     ${YELLOW}export ANTHROPIC_BASE_URL=\"https://your-api-endpoint\"${NC}"
    echo ""
    echo "  2. Reload your shell or run:"
    echo ""
    echo -e "     ${YELLOW}source ~/.zshrc${NC}  # or ~/.bashrc"
    echo ""
    echo "  3. Start using Claude in sandbox:"
    echo ""
    echo -e "     ${YELLOW}claude-sandbox -p \"write hello world in python\"${NC}"
    echo -e "     ${YELLOW}claude-sandbox  # interactive mode${NC}"
    echo ""
    echo "  Or use the cowork wrapper:"
    echo ""
    echo -e "     ${YELLOW}cowork ask \"write hello world in python\"${NC}"
    echo ""
    echo "  Optional - If you need network proxy:"
    echo ""
    echo -e "     ${YELLOW}export HTTP_PROXY=\"http://127.0.0.1:7890\"${NC}"
    echo -e "     ${YELLOW}export HTTPS_PROXY=\"http://127.0.0.1:7890\"${NC}"
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Main
main() {
    print_banner

    check_system
    install_lima
    install_jq
    clone_repo

    # Try pre-built package first
    if download_prebuilt_vm && install_prebuilt_vm; then
        start_vm || build_vm
    else
        start_vm || build_vm
    fi

    setup_path
    print_success
}

main "$@"
