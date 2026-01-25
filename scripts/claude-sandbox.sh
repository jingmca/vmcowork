#!/bin/bash
#
# claude-sandbox - Run Claude Code in isolated Lima VM sandbox
# Drop-in replacement for `claude` command with sandbox isolation
#

set -e

VM_NAME="${COWORK_VM_NAME:-sandbox}"
WORKSPACE="${COWORK_WORKSPACE:-/workspace}"

# PATH prefix for commands executed in VM
VM_PATH_PREFIX='export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH" &&'

# Execute command in VM with cd warning suppression
vm_bash() {
    (limactl shell "$VM_NAME" -- bash -c "cd ~ 2>/dev/null; $1") 2>&1 | { grep -v "cd:.*No such file or directory" || true; }
}

# Check if Lima is installed
if ! command -v limactl &> /dev/null; then
    echo "Error: Lima is not installed. Install with: brew install lima" >&2
    exit 1
fi

# Check VM status
vm_status=$(limactl list --json 2>/dev/null | jq -r "if type == \"array\" then .[] | select(.name == \"$VM_NAME\") | .status else if .name == \"$VM_NAME\" then .status else empty end end" 2>/dev/null)

if [ "$vm_status" != "Running" ]; then
    echo "Error: VM '$VM_NAME' is not running. Run 'cowork start' first." >&2
    exit 1
fi

# Determine working directory
vm_workspace="$WORKSPACE"
workingdir=""
skip_permissions=true
args=()

# Parse arguments - extract cowork-specific flags
while [ $# -gt 0 ]; do
    case "$1" in
        --workingdir|--wd)
            shift
            workingdir="$1"
            shift
            ;;
        --no-dangerously-skip-permissions)
            skip_permissions=false
            shift
            ;;
        *)
            args+=("$1")
            shift
            ;;
    esac
done

# Convert workingdir to VM path
if [ -n "$workingdir" ]; then
    workingdir="${workingdir/#\~/$HOME}"
    if [[ "$workingdir" == "$HOME"* ]]; then
        relative_path="${workingdir#$HOME}"
        vm_workspace="/tmp/lima${relative_path}"
    else
        echo "Error: workingdir must be under home directory (~)" >&2
        exit 1
    fi
    # Create directory if not exists
    vm_bash "mkdir -p $vm_workspace" >/dev/null 2>&1
elif ! vm_bash "test -d $WORKSPACE" >/dev/null 2>&1; then
    vm_workspace="/tmp/lima/Downloads/cowork-workspace"
fi

# Ensure Claude config is linked to host
vm_bash "
    if [ -d /tmp/lima/.claude ] && [ ! -L ~/.claude ]; then
        rm -rf ~/.claude 2>/dev/null || true
        ln -sf /tmp/lima/.claude ~/.claude
    fi
" >/dev/null 2>&1 || true

# Build environment variables
env_vars=""
if [ -n "$ANTHROPIC_AUTH_TOKEN" ]; then
    env_vars="ANTHROPIC_AUTH_TOKEN='$ANTHROPIC_AUTH_TOKEN' "
fi
if [ -n "$ANTHROPIC_BASE_URL" ]; then
    env_vars="${env_vars}ANTHROPIC_BASE_URL='$ANTHROPIC_BASE_URL' "
fi

# Build Claude options
claude_opts=""
if [ "$skip_permissions" = true ]; then
    claude_opts="--dangerously-skip-permissions"
fi

# Run Claude with all arguments passed through
limactl shell --workdir "$vm_workspace" "$VM_NAME" -- bash -c "cd ~ 2>/dev/null; $VM_PATH_PREFIX cd $vm_workspace && ${env_vars}claude $claude_opts $(printf '%q ' "${args[@]}")"
