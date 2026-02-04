#!/bin/bash
#
# Cowork Sandbox - One-click installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/jingmca/vmcowork/main/install.sh | bash
#
# Or:
#   wget -qO- https://raw.githubusercontent.com/jingmca/vmcowork/main/install.sh | bash
#
# Import pre-built image:
#   COWORK_IMPORT_IMAGE=/path/to/image.tar.gz bash install.sh
#   # Or use command line argument:
#   ./install.sh --import /path/to/image.tar.gz
#

set -e

# Configuration
REPO_URL="https://github.com/jingmca/vmcowork"
REPO_BRANCH="main"
INSTALL_DIR="$HOME/.vmcowork"
VM_NAME="sandbox"
LIMA_VM_DIR="$HOME/.lima/$VM_NAME"

# Import mode - user can specify a pre-built image file
IMPORT_IMAGE="${COWORK_IMPORT_IMAGE:-}"  # Path to pre-built image file

# CUI Configuration
CUI_REPO="${COWORK_CUI_REPO:-https://github.com/jingmca/cui.git}"
CUI_DIR="/workspace/cui"
CUI_SERVER_PORT="${COWORK_CUI_PORT:-3001}"
CUI_WEB_PORT="${COWORK_CUI_WEB_PORT:-3000}"
INSTALL_CUI="${COWORK_INSTALL_CUI:-true}"  # Install CUI by default

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
    echo -e "${BLUE}│     VMCowork Installer              │${NC}"
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

# Import VM from user-specified image file
import_vm_image() {
    local image_path="$1"

    if [ -z "$image_path" ]; then
        return 1
    fi

    # Validate image file exists
    if [ ! -f "$image_path" ]; then
        log_fail "Import image not found: $image_path"
    fi

    # Check if VM already exists
    if [ -d "$LIMA_VM_DIR" ]; then
        log_info "VM already exists at $LIMA_VM_DIR"
        echo ""
        echo -e "${YELLOW}Options:${NC}"
        echo "  1. Delete existing VM first: limactl delete $VM_NAME"
        echo "  2. Or skip import and use existing VM"
        echo ""
        read -p "Delete existing VM and import? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Stopping and deleting existing VM..."
            limactl stop "$VM_NAME" 2>/dev/null || true
            limactl delete "$VM_NAME" 2>/dev/null || true
            rm -rf "$LIMA_VM_DIR"
        else
            log_info "Using existing VM"
            return 0
        fi
    fi

    log_info "Importing VM from: $image_path"

    # Detect image format and import
    local file_ext="${image_path##*.}"
    local tmp_dir=$(mktemp -d)

    case "$file_ext" in
        gz|tgz)
            # Assume tar.gz format
            log_info "Extracting tar.gz image..."
            tar -xzf "$image_path" -C "$tmp_dir" || log_fail "Failed to extract image"
            ;;
        tar)
            log_info "Extracting tar image..."
            tar -xf "$image_path" -C "$tmp_dir" || log_fail "Failed to extract image"
            ;;
        qcow2)
            # Direct qcow2 disk image - need to create VM structure
            log_info "Importing qcow2 disk image..."
            mkdir -p "$tmp_dir/vm"
            cp "$image_path" "$tmp_dir/vm/basedisk"
            ;;
        *)
            log_fail "Unsupported image format: $file_ext (supported: tar.gz, tar, qcow2)"
            ;;
    esac

    # Find the VM data in extracted content
    local vm_data_dir=""

    # Check common directory structures
    if [ -d "$tmp_dir/vm" ]; then
        vm_data_dir="$tmp_dir/vm"
    elif [ -d "$tmp_dir/$VM_NAME" ]; then
        vm_data_dir="$tmp_dir/$VM_NAME"
    elif [ -d "$tmp_dir/sandbox" ]; then
        vm_data_dir="$tmp_dir/sandbox"
    elif [ -f "$tmp_dir/basedisk" ] || [ -f "$tmp_dir/diffdisk" ]; then
        vm_data_dir="$tmp_dir"
    else
        # Search for Lima VM structure (basedisk or diffdisk file)
        vm_data_dir=$(find "$tmp_dir" -name "basedisk" -o -name "diffdisk" -o -name "lima.yaml" 2>/dev/null | head -1 | xargs dirname 2>/dev/null || echo "")
    fi

    if [ -z "$vm_data_dir" ] || [ ! -d "$vm_data_dir" ]; then
        rm -rf "$tmp_dir"
        log_fail "Could not find valid VM data in image. Expected Lima VM structure with basedisk/diffdisk files."
    fi

    # Create Lima VM directory and copy data
    mkdir -p "$LIMA_VM_DIR"
    cp -r "$vm_data_dir"/* "$LIMA_VM_DIR/"

    # Ensure lima.yaml exists (create minimal one if not)
    if [ ! -f "$LIMA_VM_DIR/lima.yaml" ]; then
        log_info "Creating lima.yaml configuration..."
        cat > "$LIMA_VM_DIR/lima.yaml" << 'EOF'
# Auto-generated lima.yaml for imported VM
vmType: "vz"
rosetta:
  enabled: true
  binfmt: true
cpus: 4
memory: "8GiB"
disk: "100GiB"
mountType: "virtiofs"
mounts:
  - location: "~"
    writable: false
  - location: "/tmp/lima"
    writable: true
EOF
    fi

    rm -rf "$tmp_dir"
    log_pass "VM image imported successfully"
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

# VM helper functions
vm_bash() {
    (limactl shell "$VM_NAME" -- bash -c "cd ~ 2>/dev/null; $1") 2>&1 | { grep -v "cd:.*No such file or directory" || true; }
}

vm_exec() {
    (limactl shell "$VM_NAME" -- "$@") 2>&1 | { grep -v "cd:.*No such file or directory" || true; }
}

# Deploy CUI to sandbox
deploy_cui() {
    if [ "$INSTALL_CUI" != "true" ]; then
        log_info "Skipping CUI installation (set COWORK_INSTALL_CUI=true to enable)"
        return 0
    fi

    log_info "Deploying CUI (Claude UI) to sandbox..."

    local VM_PATH_PREFIX='export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH" &&'

    # Check if CUI is already deployed (use vm_bash + grep to properly check)
    if vm_bash "test -d $CUI_DIR/.git && echo EXISTS" 2>/dev/null | grep -q "EXISTS"; then
        log_info "CUI already exists, updating..."
        vm_bash "cd $CUI_DIR && git pull origin main" || true
    else
        log_info "Cloning CUI repository..."
        vm_bash "mkdir -p /workspace && cd /workspace && rm -rf cui && git clone $CUI_REPO cui"
    fi

    # Verify clone succeeded
    if ! vm_bash "test -d $CUI_DIR && echo EXISTS" 2>/dev/null | grep -q "EXISTS"; then
        log_info "Git clone failed, CUI deployment skipped"
        return 1
    fi

    # Install dependencies
    log_info "Installing CUI dependencies..."
    vm_bash "$VM_PATH_PREFIX cd $CUI_DIR && npm install"

    # Build the project
    log_info "Building CUI..."
    vm_bash "$VM_PATH_PREFIX cd $CUI_DIR && npm run build"

    log_pass "CUI deployed to $CUI_DIR"
}

# Start CUI server
start_cui_server() {
    if [ "$INSTALL_CUI" != "true" ]; then
        return 0
    fi

    # Check if CUI is deployed
    if ! vm_bash "test -d $CUI_DIR && echo EXISTS" 2>/dev/null | grep -q "EXISTS"; then
        log_info "CUI not deployed, skipping server start"
        return 0
    fi

    log_info "Starting CUI server on port $CUI_SERVER_PORT..."

    # Build environment variables for API
    local env_vars=""
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        env_vars="ANTHROPIC_API_KEY='$ANTHROPIC_API_KEY' "
    fi
    if [ -n "$ANTHROPIC_AUTH_TOKEN" ]; then
        env_vars="${env_vars}ANTHROPIC_AUTH_TOKEN='$ANTHROPIC_AUTH_TOKEN' "
    fi
    if [ -n "$ANTHROPIC_BASE_URL" ]; then
        env_vars="${env_vars}ANTHROPIC_BASE_URL='$ANTHROPIC_BASE_URL' "
    fi

    # Stop any existing server
    vm_bash "pkill -f 'tsx.*server' 2>/dev/null || true"
    sleep 1

    # Start server in background - run limactl in background to avoid blocking
    (
        limactl shell "$VM_NAME" -- bash -c "cd $CUI_DIR && export PATH=\"\$HOME/.npm-global/bin:\$HOME/.local/bin:\$PATH\" && ${env_vars}PORT=$CUI_SERVER_PORT API_ONLY=true nohup npm run dev:api > /tmp/cui-server.log 2>&1 &" 2>/dev/null
    ) &
    sleep 4

    # Check if server started (200 or 401 both mean server is running)
    local http_code
    http_code=$(vm_bash "curl -s -o /dev/null -w '%{http_code}' http://localhost:$CUI_SERVER_PORT/api/health" 2>/dev/null)
    if [ "$http_code" == "200" ] || [ "$http_code" == "401" ]; then
        log_pass "CUI server started on port $CUI_SERVER_PORT"

        # Extract and display access token
        local token_line
        token_line=$(vm_bash "grep -o 'token=[a-f0-9]*' /tmp/cui-server.log 2>/dev/null | tail -1")
        if [ -n "$token_line" ]; then
            local token="${token_line#token=}"
            echo ""
            echo -e "  ${GREEN}Access URL:${NC} http://localhost:$CUI_WEB_PORT#token=$token"
            echo ""
        fi
    else
        log_info "CUI server starting... Check with: cowork cui-server status"
    fi
}

# Check CUI health
check_cui_health() {
    if [ "$INSTALL_CUI" != "true" ]; then
        return 0
    fi

    echo ""
    log_info "CUI Health Check:"

    # Check CUI deployment
    if vm_bash "test -d $CUI_DIR && echo EXISTS" 2>/dev/null | grep -q "EXISTS"; then
        log_pass "CUI deployed at $CUI_DIR"
    else
        log_info "CUI not deployed (deploy with: cowork cui-deploy)"
        return 1
    fi

    # Check CUI server (200 or 401 both mean server is running)
    local http_code
    http_code=$(vm_bash "curl -s -o /dev/null -w '%{http_code}' http://localhost:$CUI_SERVER_PORT/api/health" 2>/dev/null)
    if [ "$http_code" == "200" ] || [ "$http_code" == "401" ]; then
        log_pass "CUI server running on port $CUI_SERVER_PORT"
    else
        log_info "CUI server not running (start with: cowork cui-server start)"
    fi

    return 0
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
    echo -e "     ${YELLOW}export ANTHROPIC_API_KEY=\"your-api-key\"${NC}"
    echo -e "     # Or: export ANTHROPIC_AUTH_TOKEN=\"your-api-token\"${NC}"
    echo -e "     # Optional: export ANTHROPIC_BASE_URL=\"https://your-api-endpoint\"${NC}"
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
    if [ "$INSTALL_CUI" == "true" ]; then
        echo "  4. CUI (Claude UI) - Web Interface:"
        echo ""
        echo -e "     ${YELLOW}cowork cui-server start${NC}    # Start API server in sandbox"
        echo -e "     ${YELLOW}cowork cui-web start${NC}       # Start Web UI on host"
        echo -e "     ${YELLOW}cowork cui-health${NC}          # Check all services"
        echo ""
        echo "     Then open: http://localhost:$CUI_WEB_PORT"
        echo ""
    fi
    echo "  Optional - If you need network proxy:"
    echo ""
    echo -e "     ${YELLOW}export HTTP_PROXY=\"http://127.0.0.1:7890\"${NC}"
    echo -e "     ${YELLOW}export HTTPS_PROXY=\"http://127.0.0.1:7890\"${NC}"
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --import|-i)
                if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
                    IMPORT_IMAGE="$2"
                    shift 2
                else
                    log_fail "--import requires a path to image file"
                fi
                ;;
            --no-cui)
                INSTALL_CUI="false"
                shift
                ;;
            --help|-h)
                echo "Cowork Sandbox Installer"
                echo ""
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --import, -i <path>    Import from pre-built VM image file"
                echo "  --no-cui               Skip CUI installation"
                echo "  --help, -h             Show this help"
                echo ""
                echo "Environment variables:"
                echo "  COWORK_IMPORT_IMAGE    Path to pre-built VM image file"
                echo "  COWORK_INSTALL_CUI     Install CUI (default: true)"
                echo "  COWORK_CUI_PORT        CUI server port (default: 3001)"
                echo "  COWORK_CUI_WEB_PORT    CUI web port (default: 3000)"
                echo "  ANTHROPIC_API_KEY      API key for Claude"
                echo "  ANTHROPIC_AUTH_TOKEN   Auth token for Claude"
                echo "  ANTHROPIC_BASE_URL     Custom API endpoint"
                echo ""
                echo "Examples:"
                echo "  # Standard installation"
                echo "  ./install.sh"
                echo ""
                echo "  # Import from pre-built image"
                echo "  ./install.sh --import /path/to/sandbox-image.tar.gz"
                echo ""
                echo "  # Install without CUI"
                echo "  ./install.sh --no-cui"
                echo ""
                exit 0
                ;;
            *)
                log_fail "Unknown option: $1. Use --help for usage."
                ;;
        esac
    done
}

# Main
main() {
    parse_args "$@"

    print_banner

    check_system
    install_lima
    install_jq
    clone_repo

    # Check if import mode is enabled
    if [ -n "$IMPORT_IMAGE" ]; then
        log_info "Import mode: Using pre-built image"
        import_vm_image "$IMPORT_IMAGE"
        start_vm || log_fail "Failed to start imported VM"
    else
        # Standard installation: Try pre-built package first
        if download_prebuilt_vm && install_prebuilt_vm; then
            start_vm || build_vm
        else
            start_vm || build_vm
        fi
    fi

    # Deploy CUI if enabled
    if [ "$INSTALL_CUI" == "true" ]; then
        deploy_cui
        start_cui_server
        check_cui_health
    fi

    setup_path
    print_success
}

main "$@"
