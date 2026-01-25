# VMCowork

A macOS sandbox environment for running Claude Code in an isolated Linux VM.

## One-Click Install (Apple Silicon)

```bash
curl -fsSL https://raw.githubusercontent.com/jingmca/vmcowork/main/install.sh | bash
```

This will:
- Install Lima and jq (via Homebrew or direct download)
- Clone the repository to `~/.vmcowork/`
- Download pre-built VM package (if available) or build from scratch
- Configure PATH automatically

After installation:

```bash
# Configure API (required)
export ANTHROPIC_AUTH_TOKEN="your-api-token"
export ANTHROPIC_BASE_URL="https://your-api-endpoint"

# Reload shell
source ~/.zshrc  # or ~/.bashrc

# Start using (drop-in replacement for claude)
claude-sandbox -p "write hello world in python"
claude-sandbox  # interactive mode
```

## Network Proxy (Optional)

If you need proxy to access the API:

```bash
export HTTP_PROXY="http://127.0.0.1:7890"
export HTTPS_PROXY="http://127.0.0.1:7890"
```

## Usage

### claude-sandbox (Recommended)

Drop-in replacement for `claude` command, runs in isolated VM:

```bash
# Print mode (single query)
claude-sandbox -p "write a function"

# Interactive mode
claude-sandbox

# With working directory
claude-sandbox --workingdir ~/Projects/myapp -p "add tests"

# All Claude Code options are supported
claude-sandbox -p "hello" --output-format stream-json --verbose
claude-sandbox --model sonnet -p "quick task"
```

### cowork CLI

Full-featured CLI with VM management:

```bash
cowork init                 # Create and start sandbox
cowork list                 # List all sandboxes
cowork status               # Show sandbox status
cowork stop                 # Stop sandbox
cowork delete               # Delete sandbox

cowork shell                # Enter VM shell
cowork exec "command"       # Run command in VM
```

### Claude Commands via cowork

```bash
# New conversation
cowork ask "write a function"

# Continue conversation
cowork ask -c "add error handling"

# Work in project directory
cowork ask --project myapp "create flask app"
cowork ask --project myapp -c "add tests"

# Interactive mode
cowork claude
```

### Multiple Sandboxes

Create independent sandboxes with different configurations:

```bash
# Create sandbox for project A
cowork --vm-name proj-a --mount ~/project-a:/workspace init

# Create sandbox for project B  
cowork --vm-name proj-b --mount ~/project-b:/workspace init

# Use specific sandbox
cowork --vm-name proj-a ask "analyze this code"
cowork --vm-name proj-b ask "write tests"

# List all sandboxes
cowork list
```

### Proxy Configuration

Configure network proxy when creating sandbox:

```bash
cowork --proxy 192.168.5.2:7890 init
cowork --vm-name dev --proxy 192.168.5.2:7890 --mount ~/dev:/workspace init
```

## Command Reference

### claude-sandbox

```
claude-sandbox [options] [claude-options]

Cowork Options:
  --workingdir, --wd <path>          Host path to work in (e.g., ~/Projects/app)
  --no-dangerously-skip-permissions  Don't auto-add --dangerously-skip-permissions

All Claude Code CLI options are passed through directly:
  -p, --print           Print mode (non-interactive)
  -c, --continue        Continue previous conversation
  --model <model>       Specify model (opus, sonnet, haiku)
  --plan                Plan mode (no execution)
  --output-format       Output format (text, json, stream-json)
  --verbose             Verbose output
  --allowedTools <t>    Specify allowed tools
  ... and more (see 'claude --help')
```

### cowork

```
cowork [options] <command> [arguments]

Options:
  --vm-name <name>      VM name (default: sandbox)
  --proxy <host:port>   Proxy for VM network (only for init)
  --mount <host:vm>     Custom mount directory (only for init)

Commands:
  init      Create and start a sandbox VM
  list      List all VMs
  start     Start VM
  stop      Stop VM
  status    Show VM status
  delete    Delete VM

  shell     Enter VM shell
  exec      Run command in VM
  claude    Interactive Claude session (all claude options supported)
  ask       Non-interactive Claude query (auto adds -p)

Ask/Claude Options:
  --project <name>                   Work in /workspace/<name>
  --workingdir <path>                Work in host path (e.g., ~/Projects/app)
  --no-dangerously-skip-permissions  Don't auto-add --dangerously-skip-permissions
  (All Claude CLI options are passed through)
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `COWORK_VM_NAME` | Default VM name |
| `COWORK_PROXY_HOST` | Proxy host |
| `COWORK_PROXY_PORT` | Proxy port (default: 7890) |
| `COWORK_MOUNT` | Mount path (format: host:vm) |
| `ANTHROPIC_AUTH_TOKEN` | API token for Claude |
| `ANTHROPIC_BASE_URL` | API endpoint URL |

## Python API

```python
from host.controller import CoworkController, SandboxConfig

config = SandboxConfig(
    vm_name="sandbox",
    proxy_host="192.168.5.2",
    proxy_port=7890,
    custom_mount="~/project:/workspace"
)
controller = CoworkController(config)

# Create VM with configuration
controller.create_vm()

# Ask Claude
result = controller.ask_claude("write fibonacci function")
print(result.output)

# Continue conversation
result = controller.ask_claude("add memoization", continue_conversation=True)

# Work in project
result = controller.ask_claude("create app", project="myapp")

# Work in host directory
result = controller.ask_claude("add tests", workingdir="~/Projects/app")

# With Claude options
result = controller.ask_claude(
    "design a REST API",
    claude_args=["--plan"]
)

# Execute command in VM
result = controller.execute_in_vm("ls -la /workspace")
print(result.output)
```

## VM Specifications

| Resource | Value |
|----------|-------|
| OS | Ubuntu 22.04 LTS |
| Arch | ARM64 / AMD64 |
| CPU | 4 cores |
| RAM | 4 GB |
| Disk | 10 GB |

### Pre-installed Software

- Python 3.10 + pip
- Node.js 22.x LTS
- Claude Code CLI
- GCC, Make, CMake
- Git, curl, wget
- ripgrep, fd, jq

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      macOS Host                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  cowork CLI / controller.py                         │   │
│  └─────────────────────────────────────────────────────┘   │
│                           │ Lima/SSH                        │
└───────────────────────────┼─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Ubuntu 22.04 VM                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Claude Code CLI (isolated environment)             │   │
│  └─────────────────────────────────────────────────────┘   │
│  /workspace ← mounted from host                            │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
cowork-sandbox/
├── scripts/
│   ├── claude-sandbox      # Node.js wrapper (for spawn compatibility)
│   ├── claude-sandbox.sh   # Bash implementation
│   └── cowork              # Full CLI tool
├── host/
│   └── controller.py       # Python API
├── sandbox.yaml            # Lima VM configuration
├── install.sh              # One-click installer
└── tests/                  # Test scripts
```

## Troubleshooting

### VM won't start

```bash
limactl list                # Check status
cowork delete               # Delete VM
cowork init                 # Recreate
```

### Claude not found

```bash
cowork shell
npm install -g @anthropic-ai/claude-code
```

### Network issues

```bash
cowork exec "curl -I https://google.com"
cowork stop && cowork start
```

## License

MIT
