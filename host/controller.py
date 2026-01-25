#!/usr/bin/env python3
"""
Cowork Sandbox Controller
Host-side controller for communicating with Claude Code in VM via -p mode.
"""

import json
import os
import shlex
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Optional


@dataclass
class ExecutionResult:
    """Result from Claude Code execution."""

    success: bool
    output: str
    error: str = ""
    exit_code: int = 0
    duration_ms: int = 0


@dataclass
class SandboxConfig:
    """Sandbox VM configuration."""

    vm_name: str = ""
    working_dir: str = ""
    timeout: int = 300  # 5 minutes default
    env: dict = field(default_factory=dict)
    # Claude Code API configuration (can be overridden by environment variables)
    anthropic_auth_token: str = ""
    anthropic_base_url: str = ""
    # Runtime configuration for VM creation
    proxy_host: str = ""
    proxy_port: int = 7890
    custom_mount: str = ""  # Format: host_path:vm_path

    def __post_init__(self):
        """Load configuration from environment variables if not set."""
        if not self.vm_name:
            self.vm_name = os.environ.get("COWORK_VM_NAME", "sandbox")
        if not self.working_dir:
            self.working_dir = os.environ.get("COWORK_WORKSPACE", "/workspace")
        if not self.anthropic_auth_token:
            self.anthropic_auth_token = os.environ.get("ANTHROPIC_AUTH_TOKEN", "")
        if not self.anthropic_base_url:
            self.anthropic_base_url = os.environ.get("ANTHROPIC_BASE_URL", "")
        if not self.proxy_host:
            self.proxy_host = os.environ.get("COWORK_PROXY_HOST", "")
        if self.proxy_port == 7890:  # default value
            self.proxy_port = int(os.environ.get("COWORK_PROXY_PORT", "7890"))
        if not self.custom_mount:
            self.custom_mount = os.environ.get("COWORK_MOUNT", "")


class CoworkController:
    """
    Controller for communicating with Claude Code running inside Lima VM.
    Uses claude -p (print mode) for non-interactive execution.
    """

    def __init__(self, config: Optional[SandboxConfig] = None):
        self.config = config or SandboxConfig()
        self._vm_running = None
        self._project_dir = Path(__file__).parent.parent

    def _generate_runtime_config(self) -> str:
        """
        Generate a runtime Lima config file with dynamic settings.
        Returns path to the temporary config file.
        """
        import re
        import tempfile

        base_config = self._project_dir / "sandbox.yaml"

        # Read base config
        with open(base_config, "r") as f:
            config_content = f.read()

        # Add custom mount if specified - insert into existing mounts array
        if self.config.custom_mount:
            parts = self.config.custom_mount.split(":")
            if len(parts) == 2:
                host_path, vm_path = parts
                # Expand ~ in host path
                host_path = os.path.expanduser(host_path)
                # Ensure host directory exists
                os.makedirs(host_path, exist_ok=True)

                # Find "mounts:" line and insert after it
                mount_entry = f'  - location: "{host_path}"\n    writable: true\n    mountPoint: "{vm_path}"'
                config_content = re.sub(
                    r"(^mounts:\s*\n)",
                    r"\1" + mount_entry + "\n",
                    config_content,
                    flags=re.MULTILINE,
                )

        # Add proxy configuration if specified - insert into existing env section
        if self.config.proxy_host:
            proxy_url = f"http://{self.config.proxy_host}:{self.config.proxy_port}"
            proxy_entries = f"""  HTTP_PROXY: "{proxy_url}"
  HTTPS_PROXY: "{proxy_url}"
  http_proxy: "{proxy_url}"
  https_proxy: "{proxy_url}"
  NO_PROXY: "localhost,127.0.0.1"
  no_proxy: "localhost,127.0.0.1"
"""
            config_content = re.sub(
                r"(^env:\s*\n)",
                r"\1" + proxy_entries,
                config_content,
                flags=re.MULTILINE,
            )

        # Write to temp file
        fd, runtime_config = tempfile.mkstemp(suffix=".yaml", prefix="cowork-sandbox-")
        os.close(fd)
        with open(runtime_config, "w") as f:
            f.write(config_content)

        return runtime_config

    def is_vm_running(self) -> bool:
        """Check if the sandbox VM is running."""
        if self._vm_running is not None:
            return self._vm_running

        try:
            result = subprocess.run(
                ["limactl", "list", "--json"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode == 0:
                data = json.loads(result.stdout)
                # Lima 2.x returns a single object, older versions return an array
                if isinstance(data, list):
                    for vm in data:
                        if vm.get("name") == self.config.vm_name:
                            self._vm_running = vm.get("status") == "Running"
                            return self._vm_running
                elif isinstance(data, dict):
                    if data.get("name") == self.config.vm_name:
                        self._vm_running = data.get("status") == "Running"
                        return self._vm_running
        except Exception as e:
            print(f"Error checking VM status: {e}", file=sys.stderr)

        self._vm_running = False
        return False

    def start_vm(self) -> bool:
        """Start the sandbox VM if not running."""
        if self.is_vm_running():
            print(f"VM '{self.config.vm_name}' is already running.")
            return True

        print(f"Starting VM '{self.config.vm_name}'...")
        try:
            result = subprocess.run(
                ["limactl", "start", self.config.vm_name],
                capture_output=True,
                text=True,
                timeout=300,  # VM startup can take a while
            )
            if result.returncode == 0:
                self._vm_running = True
                print(f"VM '{self.config.vm_name}' started successfully.")
                return True
            else:
                print(f"Failed to start VM: {result.stderr}", file=sys.stderr)
                return False
        except subprocess.TimeoutExpired:
            print("VM startup timed out.", file=sys.stderr)
            return False
        except Exception as e:
            print(f"Error starting VM: {e}", file=sys.stderr)
            return False

    def create_vm(self) -> bool:
        """
        Create the sandbox VM with runtime configuration.
        Uses dynamic proxy and mount settings from config.
        """
        # Check if VM already exists
        try:
            result = subprocess.run(
                ["limactl", "list", "--json"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode == 0:
                data = json.loads(result.stdout)
                # Check if VM exists (handle both Lima 1.x and 2.x)
                if isinstance(data, list):
                    for vm in data:
                        if vm.get("name") == self.config.vm_name:
                            print(f"VM '{self.config.vm_name}' already exists.")
                            return self.start_vm()
                elif isinstance(data, dict):
                    if data.get("name") == self.config.vm_name:
                        print(f"VM '{self.config.vm_name}' already exists.")
                        return self.start_vm()
        except Exception:
            pass

        # Create workspace directory
        workspace_dir = Path.home() / "Downloads" / "cowork-workspace"
        workspace_dir.mkdir(exist_ok=True)

        # Generate runtime config
        runtime_config = self._generate_runtime_config()

        print(f"Creating VM '{self.config.vm_name}' with runtime configuration...")
        if self.config.proxy_host:
            print(f"  Proxy: {self.config.proxy_host}:{self.config.proxy_port}")
        if self.config.custom_mount:
            print(f"  Custom mount: {self.config.custom_mount}")

        try:
            result = subprocess.run(
                ["limactl", "start", f"--name={self.config.vm_name}", runtime_config],
                capture_output=True,
                text=True,
                timeout=600,  # VM creation can take a while
            )

            # Cleanup temp config
            os.unlink(runtime_config)

            if result.returncode == 0:
                self._vm_running = True
                print(f"VM '{self.config.vm_name}' created successfully.")
                return True
            else:
                print(f"Failed to create VM: {result.stderr}", file=sys.stderr)
                return False
        except subprocess.TimeoutExpired:
            os.unlink(runtime_config)
            print("VM creation timed out.", file=sys.stderr)
            return False
        except Exception as e:
            if os.path.exists(runtime_config):
                os.unlink(runtime_config)
            print(f"Error creating VM: {e}", file=sys.stderr)
            return False

    def stop_vm(self) -> bool:
        """Stop the sandbox VM."""
        print(f"Stopping VM '{self.config.vm_name}'...")
        try:
            result = subprocess.run(
                ["limactl", "stop", self.config.vm_name],
                capture_output=True,
                text=True,
                timeout=60,
            )
            self._vm_running = False
            return result.returncode == 0
        except Exception as e:
            print(f"Error stopping VM: {e}", file=sys.stderr)
            return False

    def execute_in_vm(
        self, command: str, timeout: Optional[int] = None
    ) -> ExecutionResult:
        """
        Execute a shell command inside the VM.

        Args:
            command: Shell command to execute
            timeout: Optional timeout in seconds

        Returns:
            ExecutionResult with output and status
        """
        timeout = timeout or self.config.timeout
        start_time = datetime.now()

        # Set PATH to include npm global and local bins, then run command
        # Prepend cd ~ to avoid Lima's "cd: No such file or directory" warnings
        path_prefix = 'export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"'
        command = f"cd ~ 2>/dev/null; {path_prefix} && {command}"

        try:
            result = subprocess.run(
                ["limactl", "shell", self.config.vm_name, "--", "bash", "-c", command],
                capture_output=True,
                text=True,
                timeout=timeout,
            )

            duration = int((datetime.now() - start_time).total_seconds() * 1000)

            # Filter out Lima's cd warnings from stderr
            stderr_lines = result.stderr.split('\n')
            filtered_stderr = '\n'.join(
                line for line in stderr_lines
                if 'cd:' not in line or 'No such file or directory' not in line
            )

            return ExecutionResult(
                success=result.returncode == 0,
                output=result.stdout,
                error=filtered_stderr,
                exit_code=result.returncode,
                duration_ms=duration,
            )
        except subprocess.TimeoutExpired:
            return ExecutionResult(
                success=False,
                output="",
                error=f"Command timed out after {timeout} seconds",
            )
        except Exception as e:
            return ExecutionResult(success=False, output="", error=str(e))

    def ask_claude(
        self,
        prompt: str,
        working_dir: Optional[str] = None,
        timeout: Optional[int] = None,
        allowed_tools: Optional[list] = None,
        continue_conversation: bool = False,
        project: Optional[str] = None,
        workingdir: Optional[str] = None,
        skip_permissions: bool = True,
        claude_args: Optional[list] = None,
    ) -> ExecutionResult:
        """
        Send a prompt to Claude Code in the VM using -p mode.

        Args:
            prompt: The prompt to send to Claude
            working_dir: Working directory for Claude (default: /workspace) - VM path
            timeout: Timeout in seconds
            allowed_tools: List of allowed tools (optional)
            continue_conversation: If True, use -c flag to continue previous conversation
            project: Project folder name under workspace. If provided, Claude will work
                     in /workspace/{project}. Directory will be created if not exists.
            workingdir: Host path to work in (e.g., ~/Projects/app). Will be converted
                       to VM path via /tmp/lima mount. Takes precedence over project.
            skip_permissions: If True (default), use --dangerously-skip-permissions
            claude_args: Additional Claude CLI arguments as a list. All Claude Code
                        options are supported (e.g., ["--plan"], ["--model", "opus"])

        Returns:
            ExecutionResult with Claude's response

        Example:
            # Basic usage
            controller.ask_claude("write hello world")

            # With project directory
            controller.ask_claude(
                "write hello world",
                project="myapp",
            )

            # With host path
            controller.ask_claude(
                "add tests",
                workingdir="~/Projects/app",
            )

            # With Claude options (plan mode, model, etc.)
            controller.ask_claude(
                "design a REST API",
                claude_args=["--plan"],
            )

            controller.ask_claude(
                "complex task",
                claude_args=["--model", "opus", "--max-budget-usd", "1.0"],
            )
        """
        if not self.is_vm_running():
            if not self.start_vm():
                return ExecutionResult(
                    success=False, output="", error="Failed to start VM"
                )

        timeout = timeout or self.config.timeout
        vm_working_dir = working_dir or self.config.working_dir

        # Determine working directory
        if workingdir:
            # --workingdir specified: convert host path to VM path
            host_path = os.path.expanduser(workingdir)
            home_dir = os.path.expanduser("~")

            if host_path.startswith(home_dir):
                # Convert to /tmp/lima path
                relative_path = host_path[len(home_dir) :]
                vm_working_dir = f"/tmp/lima{relative_path}"
                # Create directory if not exists
                self.execute_in_vm(f"mkdir -p {shlex.quote(vm_working_dir)}")
            else:
                return ExecutionResult(
                    success=False,
                    output="",
                    error="workingdir must be under home directory (~)",
                )
        elif project:
            # --project specified: use /workspace/<project>
            # Check if /workspace exists, fallback to /tmp/lima/Downloads/cowork-workspace
            check_result = self.execute_in_vm(f"test -d {shlex.quote(self.config.working_dir)} && echo 'exists'")
            if not check_result.output.strip():
                # Fallback to home-mounted workspace
                base_workspace = "/tmp/lima/Downloads/cowork-workspace"
            else:
                base_workspace = self.config.working_dir

            project_dir = f"{base_workspace}/{project}"
            # Create project directory if not exists
            self.execute_in_vm(f"mkdir -p {shlex.quote(project_dir)}")
            vm_working_dir = project_dir

        # Escape the prompt for shell
        escaped_prompt = shlex.quote(prompt)

        # Build environment variables
        env_vars = ""
        if self.config.anthropic_auth_token:
            env_vars += (
                f"ANTHROPIC_AUTH_TOKEN={shlex.quote(self.config.anthropic_auth_token)} "
            )
        if self.config.anthropic_base_url:
            env_vars += (
                f"ANTHROPIC_BASE_URL={shlex.quote(self.config.anthropic_base_url)} "
            )

        # Build Claude command parts
        # Default: -p (print mode) and --dangerously-skip-permissions (sandbox default)
        cmd_parts = ["claude", "-p"]

        if skip_permissions:
            cmd_parts.append("--dangerously-skip-permissions")

        # Add continue flag if specified
        if continue_conversation:
            cmd_parts.append("-c")

        # Add allowed tools if specified
        if allowed_tools:
            cmd_parts.append("--allowedTools")
            cmd_parts.append(",".join(allowed_tools))

        # Add any additional Claude args (supports all Claude Code options)
        if claude_args:
            cmd_parts.extend(claude_args)

        # Add prompt as last argument
        cmd_parts.append(escaped_prompt)

        # Ensure Claude config is linked to host (for existing VMs that don't have the symlink)
        link_cmd = """
if [ -d /tmp/lima/.claude ] && [ ! -L ~/.claude ]; then
    rm -rf ~/.claude 2>/dev/null || true
    ln -sf /tmp/lima/.claude ~/.claude
fi
"""

        # Set PATH to include npm global and local bins
        path_prefix = 'export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"'

        # Build full command with config link check and cd ~
        claude_cmd = f"cd ~ 2>/dev/null; {path_prefix} && {link_cmd} cd {vm_working_dir} && {env_vars}{' '.join(cmd_parts)}"

        start_time = datetime.now()

        try:
            result = subprocess.run(
                [
                    "limactl",
                    "shell",
                    self.config.vm_name,
                    "--",
                    "bash",
                    "-c",
                    claude_cmd,
                ],
                capture_output=True,
                text=True,
                timeout=timeout,
                env={**os.environ, **self.config.env},
            )

            duration = int((datetime.now() - start_time).total_seconds() * 1000)

            # Filter out Lima's cd warnings from stderr
            stderr_lines = result.stderr.split('\n')
            filtered_stderr = '\n'.join(
                line for line in stderr_lines
                if 'cd:' not in line or 'No such file or directory' not in line
            )

            return ExecutionResult(
                success=result.returncode == 0,
                output=result.stdout,
                error=filtered_stderr,
                exit_code=result.returncode,
                duration_ms=duration,
            )
        except subprocess.TimeoutExpired:
            return ExecutionResult(
                success=False,
                output="",
                error=f"Claude timed out after {timeout} seconds",
            )
        except Exception as e:
            return ExecutionResult(success=False, output="", error=str(e))

    def read_file(self, path: str) -> ExecutionResult:
        """Read a file from the VM."""
        return self.execute_in_vm(f"cat {shlex.quote(path)}")

    def write_file(self, path: str, content: str) -> ExecutionResult:
        """Write content to a file in the VM."""
        escaped_content = shlex.quote(content)
        return self.execute_in_vm(f"echo {escaped_content} > {shlex.quote(path)}")

    def list_files(self, path: str = "") -> ExecutionResult:
        """List files in a directory in the VM."""
        if not path:
            path = self.config.working_dir
        return self.execute_in_vm(f"ls -la {shlex.quote(path)}")

    def get_vm_info(self) -> dict:
        """Get information about the VM."""
        info = {
            "vm_name": self.config.vm_name,
            "running": self.is_vm_running(),
        }

        if info["running"]:
            # Get additional info
            python_ver = self.execute_in_vm("python3 --version")
            node_ver = self.execute_in_vm("node --version")
            claude_ver = self.execute_in_vm(
                "claude --version 2>/dev/null || echo 'not installed'"
            )

            info["python_version"] = python_ver.output.strip()
            info["node_version"] = node_ver.output.strip()
            info["claude_version"] = claude_ver.output.strip()

        return info


def main():
    """CLI entry point."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Cowork Sandbox Controller - Communicate with Claude Code in VM"
    )
    parser.add_argument("prompt", nargs="?", help="Prompt to send to Claude Code")
    parser.add_argument(
        "--vm-name", help="Name of the Lima VM (default: $COWORK_VM_NAME or sandbox)"
    )
    parser.add_argument(
        "--working-dir",
        "-d",
        help="Working directory in VM (default: $COWORK_WORKSPACE or /workspace)",
    )
    parser.add_argument(
        "--timeout",
        "-t",
        type=int,
        default=300,
        help="Timeout in seconds (default: 300)",
    )
    parser.add_argument(
        "--init",
        action="store_true",
        help="Initialize/create the VM with runtime config",
    )
    parser.add_argument("--start", action="store_true", help="Start the VM")
    parser.add_argument("--stop", action="store_true", help="Stop the VM")
    parser.add_argument("--status", action="store_true", help="Show VM status and info")
    parser.add_argument(
        "--exec",
        "-e",
        metavar="COMMAND",
        help="Execute a shell command in VM (not Claude)",
    )
    parser.add_argument("--json", action="store_true", help="Output in JSON format")
    parser.add_argument(
        "-c",
        "--continue",
        dest="continue_conversation",
        action="store_true",
        help="Continue previous conversation",
    )
    parser.add_argument(
        "-p",
        "--project",
        metavar="NAME",
        help="Project folder name under workspace (creates if not exists)",
    )
    parser.add_argument(
        "--workingdir",
        "--wd",
        metavar="PATH",
        help="Host path to work in (e.g., ~/Projects/app)",
    )
    parser.add_argument(
        "--no-dangerously-skip-permissions",
        dest="skip_permissions",
        action="store_false",
        default=True,
        help="Don't auto-add --dangerously-skip-permissions (default: add it)",
    )
    # Runtime configuration options
    parser.add_argument(
        "--proxy",
        metavar="HOST:PORT",
        help="Proxy configuration for VM network (e.g., 192.168.5.2:7890)",
    )
    parser.add_argument(
        "--mount",
        metavar="HOST:VM",
        help="Custom mount directory (e.g., ~/myproject:/project)",
    )

    args = parser.parse_args()

    # Parse proxy configuration
    proxy_host = ""
    proxy_port = 7890
    if args.proxy:
        if ":" in args.proxy:
            proxy_host, proxy_port = args.proxy.rsplit(":", 1)
            proxy_port = int(proxy_port)
        else:
            proxy_host = args.proxy

    config = SandboxConfig(
        vm_name=args.vm_name or "",
        working_dir=args.working_dir or "",
        timeout=args.timeout,
        proxy_host=proxy_host,
        proxy_port=proxy_port,
        custom_mount=args.mount or "",
    )

    controller = CoworkController(config)

    # Handle commands
    if args.init:
        success = controller.create_vm()
        sys.exit(0 if success else 1)

    if args.start:
        success = controller.start_vm()
        sys.exit(0 if success else 1)

    if args.stop:
        success = controller.stop_vm()
        sys.exit(0 if success else 1)

    if args.status:
        info = controller.get_vm_info()
        if args.json:
            print(json.dumps(info, indent=2))
        else:
            print(f"VM Name: {info['vm_name']}")
            print(f"Running: {info['running']}")
            if info["running"]:
                print(f"Python: {info.get('python_version', 'N/A')}")
                print(f"Node.js: {info.get('node_version', 'N/A')}")
                print(f"Claude: {info.get('claude_version', 'N/A')}")
        sys.exit(0)

    if args.exec:
        result = controller.execute_in_vm(args.exec)
        if args.json:
            print(
                json.dumps(
                    {
                        "success": result.success,
                        "output": result.output,
                        "error": result.error,
                        "exit_code": result.exit_code,
                        "duration_ms": result.duration_ms,
                    },
                    indent=2,
                )
            )
        else:
            if result.output:
                print(result.output, end="")
            if result.error:
                print(result.error, file=sys.stderr, end="")
        sys.exit(result.exit_code)

    if args.prompt:
        result = controller.ask_claude(
            args.prompt,
            continue_conversation=args.continue_conversation,
            project=args.project,
            workingdir=args.workingdir,
            skip_permissions=args.skip_permissions,
        )
        if args.json:
            print(
                json.dumps(
                    {
                        "success": result.success,
                        "output": result.output,
                        "error": result.error,
                        "exit_code": result.exit_code,
                        "duration_ms": result.duration_ms,
                    },
                    indent=2,
                )
            )
        else:
            if result.output:
                print(result.output, end="")
            if result.error:
                print(result.error, file=sys.stderr, end="")
        sys.exit(result.exit_code)

    # No command specified, show help
    parser.print_help()
    sys.exit(1)


if __name__ == "__main__":
    main()
