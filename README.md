# Cowork Sandbox

A macOS sandbox environment for running Claude Code safely in an isolated Linux VM.

Inspired by Claude Code's "Cowork mode" - reverse engineered from Claude.app.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      macOS Host                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  cowork CLI / controller.py                         │   │
│  │  - Manages VM lifecycle                             │   │
│  │  - Sends prompts to Claude via -p mode              │   │
│  │  - Receives and displays results                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                           │                                 │
│                      Lima / SSH                             │
└───────────────────────────┼─────────────────────────────────┘
                            │
┌───────────────────────────┼─────────────────────────────────┐
│                   Ubuntu 22.04 VM                           │
│                           ▼                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Claude Code CLI                                    │   │
│  │  - Executes in isolated environment                 │   │
│  │  - Full access to VM filesystem                     │   │
│  │  - Cannot affect host system                        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Pre-installed: Python 3.10, Node.js 22, GCC, Java 11      │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **macOS** (Apple Silicon or Intel)
2. **Lima** - Linux VM manager

```bash
# Install Lima
brew install lima

# Verify installation
limactl --version
```

3. **Claude Code** needs to be installed inside the VM (handled by setup)

## Quick Start

### 1. Clone/Setup Project

```bash
cd ~/Downloads/cowork-sandbox

# Create host workspace directory
mkdir -p ~/cowork-workspace
```

### 2. Initialize VM

```bash
# Using the cowork CLI
./scripts/cowork init

# Or manually with Lima
limactl start --name=sandbox sandbox.yaml
```

This will:
- Download Ubuntu 22.04 ARM64 image
- Create a VM with 4 CPU, 4GB RAM, 10GB disk
- Install Python, Node.js, GCC, Java
- Install Claude Code CLI

### 3. Use Claude Code in Sandbox

```bash
# Interactive mode (full Claude Code experience)
./scripts/cowork claude

# Non-interactive mode (script-friendly)
./scripts/cowork ask "write a python hello world program"

# Execute commands directly
./scripts/cowork exec "python3 --version"
./scripts/cowork exec "ls -la /workspace"
```

### 4. Enter VM Shell

```bash
./scripts/cowork shell

# Inside VM, you have full access
cd /workspace
claude  # Run Claude Code interactively
```

## CLI Reference

```
cowork <command> [arguments]

Commands:
  init      Initialize/create the sandbox VM
  start     Start the sandbox VM
  stop      Stop the sandbox VM
  status    Show VM status and info
  shell     Enter VM shell
  claude    Start Claude Code interactively in VM
  ask       Ask Claude (non-interactive -p mode)
  exec      Execute a command in VM
  delete    Delete the sandbox VM
  help      Show this help message
```

## Python Controller

For programmatic access:

```python
from host.controller import CoworkController, SandboxConfig

# Create controller
config = SandboxConfig(vm_name="sandbox", working_dir="/workspace")
controller = CoworkController(config)

# Check status
print(controller.get_vm_info())

# Ask Claude
result = controller.ask_claude("write a function to calculate fibonacci")
print(result.output)

# Execute commands
result = controller.execute_in_vm("python3 fibonacci.py")
print(result.output)
```

## File Sharing

Host directory `~/cowork-workspace` is mounted at `/workspace` in VM:

```bash
# From host - create a file
echo "print('hello')" > ~/cowork-workspace/test.py

# In VM - run the file
./scripts/cowork exec "python3 /workspace/test.py"
```

## VM Specifications

Matching Claude Code's Cowork mode:

| Resource | Value |
|----------|-------|
| OS | Ubuntu 22.04 LTS (Jammy) |
| Arch | ARM64 (aarch64) |
| CPU | 4 cores |
| RAM | 4 GB |
| Disk | 10 GB |

### Pre-installed Software

- Python 3.10 + pip
- Node.js 22.x (LTS)
- GCC 11.4.0
- OpenJDK 11
- Git, curl, wget
- ripgrep, fd, fzf, bat
- SQLite, PostgreSQL client

## Troubleshooting

### VM won't start

```bash
# Check Lima status
limactl list

# View logs
limactl shell sandbox -- journalctl -xe

# Delete and recreate
./scripts/cowork delete
./scripts/cowork init
```

### Claude Code not found

```bash
# Enter VM and install manually
./scripts/cowork shell

# Inside VM
npm install -g @anthropic-ai/claude-code
# or
curl -fsSL https://claude.ai/install.sh | sh
```

### Network issues in VM

```bash
# Check network
./scripts/cowork exec "ping -c 3 google.com"

# Restart VM
./scripts/cowork stop
./scripts/cowork start
```

## Security Notes

1. **Isolation**: Code runs in VM, cannot access host system directly
2. **File Access**: Only `~/cowork-workspace` is shared
3. **Network**: VM has full network access (can be restricted in Lima config)
4. **No Bubblewrap**: This MVP doesn't include the additional Bubblewrap layer

## Next Steps (Advanced)

To add more security layers:

1. **Add Bubblewrap** inside VM for process isolation
2. **Add Seccomp** for syscall filtering
3. **Network proxy** for traffic auditing
4. **Replace SSH with vsock** for better performance

## License

MIT
