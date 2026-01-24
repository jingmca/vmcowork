# Cowork Sandbox

> v0.4.0 - 完整的 Claude CLI 参数支持 + 网络监控

A macOS sandbox environment for running Claude Code safely in an isolated Linux VM.

Inspired by Claude Code's "Cowork mode" - reverse engineered from Claude.app.

## ✨ Features

- 🔒 **Secure Isolation**: Claude Code runs in a Linux VM, isolated from your host system
- 📁 **File Sharing**: Share `~/cowork-workspace` with the VM at `/workspace`
- 🔄 **Conversation Continuity**: Support for continuing conversations with `-c` flag
- 📂 **Project Management**: Organize different projects with `--project` flag
- 🎯 **Full Claude CLI Support**: All 40+ Claude CLI parameters supported (v0.4.0+)
- 🌐 **Network Monitoring**: Monitor and log all network traffic with proxy
- 🛡️ **Traffic Audit**: See what external resources Claude accesses
- 🛠️ **Full Dev Environment**: Python, Node.js, GCC, Java pre-installed
- 🔧 **Dual Interface**: CLI tools + Python API
- 📊 **Comprehensive Testing**: 20 test cases included

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

### 1. Prerequisites

```bash
# Install Lima
brew install lima

# Verify installation
limactl --version
```

### 2. Setup Configuration

```bash
# Copy environment template
cp .env.example .env

# Edit .env and add your API credentials
nano .env
```

Required environment variables:
```bash
ANTHROPIC_AUTH_TOKEN=your-api-token-here
ANTHROPIC_BASE_URL=https://your-api-endpoint
```

### 3. Initialize VM

```bash
# Load environment variables
source .env

# Initialize VM (first time only)
./scripts/cowork init
```

This will:
- Download Ubuntu 22.04 ARM64 image (~800MB)
- Create a VM with 4 CPU, 4GB RAM, 10GB disk
- Install Python, Node.js, GCC, Java
- Install Claude Code CLI
- Configure proxy to host:7890

### 4. Start Using

```bash
# Ask Claude (new conversation)
./scripts/cowork ask "write a python hello world program"

# Continue previous conversation
./scripts/cowork ask -c "add error handling"

# Work in a specific project
./scripts/cowork ask -p myproject "create a web app"
./scripts/cowork ask -p myproject -c "add authentication"

# Interactive mode
./scripts/cowork claude

# Monitor network traffic (in another terminal)
./scripts/cowork proxy -l proxy.log

# Execute commands in VM
./scripts/cowork exec "python3 --version"
```

## CLI Reference

```
Usage: cowork <command> [options] [arguments]

Commands:
  init      Initialize/create the sandbox VM
  start     Start the sandbox VM
  stop      Stop the sandbox VM
  status    Show VM status and info
  shell     Enter VM shell
  claude    Start Claude Code interactively in VM
  ask       Ask Claude (non-interactive -p mode)
  exec      Execute a command in VM
  proxy     Start network proxy monitor
  delete    Delete the sandbox VM
  help      Show this help message

Options for 'ask' command:
  -c, --continue            Continue previous conversation
  --project <name>          Work in specific project directory (replaces old -p)
  --model <model>           Use specific model (opus/sonnet/haiku)
  --max-budget-usd <amt>    Set budget limit
  --system-prompt <prompt>  Custom system prompt
  --allowed-tools <tools>   Specify allowed tools
  ... and 40+ more Claude CLI parameters (see docs/04-claude-parameters.md)

Options for 'proxy' command:
  -l <file>       Log to file
  -v              Verbose output

Examples:
  cowork init                                       # Create and start VM
  cowork proxy -l proxy.log                         # Monitor traffic
  cowork ask "write hello world"                    # New conversation
  cowork ask -c "add tests"                         # Continue conversation
  cowork ask --project myapp "create flask app"     # Work in project
  cowork ask --project myapp -c "add auth"          # Continue in project
  cowork ask --model opus "complex task"            # Use Opus model
  cowork ask --max-budget-usd 1.0 "expensive task"  # Set budget
  cowork exec "python3 script.py"                   # Run command
  cowork shell                                      # Enter VM

Note: Old syntax `-p <project>` is deprecated. Use `--project <name>` instead.
```

## Python API

For programmatic access, see [examples/basic_usage.py](examples/basic_usage.py):

```python
from host.controller import CoworkController, SandboxConfig

# Basic usage
controller = CoworkController()
result = controller.ask_claude("write a function to calculate fibonacci")
print(result.output)

# With project directory
result = controller.ask_claude(
    "create a web app",
    project="myapp"
)

# Continue conversation
result = controller.ask_claude(
    "add authentication",
    project="myapp",
    continue_conversation=True
)

# Use advanced Claude parameters (v0.4.0+)
result = controller.ask_claude(
    "create complex system",
    project="backend",
    claude_args=["--model", "opus", "--max-budget-usd", "2.0"]
)

# Execute commands
result = controller.execute_in_vm("python3 /workspace/script.py")
```

## Documentation

- **[Quick Start Guide](QUICKSTART.md)** - Get started in 5 minutes
- **[Usage Guide](USAGE.md)** - Comprehensive usage documentation
- **[Claude Parameters Guide](docs/04-claude-parameters.md)** - All Claude CLI parameters (v0.4.0+)
- **[Proxy Monitoring Guide](docs/03-proxy-monitoring.md)** - Network traffic monitoring
- **[Contributing Guide](CONTRIBUTING.md)** - Development guidelines
- **[Test Cases](TEST_CASES.md)** - 20 comprehensive test cases
- **[Design Documents](docs/)** - Architecture and research

## Testing

Run the included test suite:

```bash
# Automated tests (recommended)
./run_tests.sh

# Manual tests
# See TEST_CASES.md for 20 test cases

# Unit tests
./scripts/test.sh
```

Run examples:
```bash
# Make sure VM is running and env vars are set
source .env
python3 examples/basic_usage.py
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

### Current Security Layers

1. **VM Isolation**: Code runs in Ubuntu VM, cannot access host directly
2. **File Access**: Only `~/cowork-workspace` is shared with VM
3. **Proxy Configuration**: Network traffic routes through host:7890
4. **Permission Bypass**: Claude Code runs with `--dangerously-skip-permissions` in sandbox

### Security Considerations

- VM has full network access (configurable via proxy)
- VM can read/write to `/workspace` directory
- No Bubblewrap or Seccomp in MVP (see Phase 2)
- Regular backups of `~/cowork-workspace` recommended

## Testing

Run the test suite to verify installation:

```bash
./scripts/test.sh
```

This will check:
- Prerequisites (Lima, Python, jq)
- VM status and functionality
- File I/O operations
- Claude Code installation
- Project directory management

## Documentation

- **[USAGE.md](USAGE.md)** - Detailed usage guide with examples
- **[docs/01-research.md](docs/01-research.md)** - Reverse engineering analysis
- **[docs/02-design.md](docs/02-design.md)** - System design and architecture
- **[examples/](examples/)** - Python API examples

## Project Structure

```
cowork-sandbox/
├── docs/                   # Design documents
│   ├── 01-research.md      # Cowork mode analysis
│   └── 02-design.md        # System design
├── host/                   # Host-side code
│   └── controller.py       # Python controller API
├── scripts/                # CLI tools
│   ├── cowork              # Main CLI script
│   └── test.sh             # Test suite
├── examples/               # Usage examples
│   └── basic_usage.py      # Python API examples
├── sandbox.yaml            # Lima VM configuration
├── .env.example            # Environment template
├── USAGE.md                # Detailed usage guide
└── README.md               # This file
```

## Next Steps (Advanced)

To add more security layers:

1. **Add Bubblewrap** inside VM for process isolation
2. **Add Seccomp** for syscall filtering
3. **Network proxy** for traffic auditing
4. **Replace SSH with vsock** for better performance

## License

MIT
