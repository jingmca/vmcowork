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

    vm_name: str = "sandbox"
    working_dir: str = "/workspace"
    timeout: int = 300  # 5 minutes default
    env: dict = field(default_factory=dict)
    # Claude Code API configuration (can be overridden by environment variables)
    anthropic_auth_token: str = ""
    anthropic_base_url: str = ""

    def __post_init__(self):
        """Load API configuration from environment variables if not set."""
        if not self.anthropic_auth_token:
            self.anthropic_auth_token = os.environ.get("ANTHROPIC_AUTH_TOKEN", "")
        if not self.anthropic_base_url:
            self.anthropic_base_url = os.environ.get("ANTHROPIC_BASE_URL", "")


class CoworkController:
    """
    Controller for communicating with Claude Code running inside Lima VM.
    Uses claude -p (print mode) for non-interactive execution.
    """

    def __init__(self, config: Optional[SandboxConfig] = None):
        self.config = config or SandboxConfig()
        self._vm_running = None

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

        try:
            result = subprocess.run(
                ["limactl", "shell", self.config.vm_name, "--", "bash", "-c", command],
                capture_output=True,
                text=True,
                timeout=timeout,
            )

            duration = int((datetime.now() - start_time).total_seconds() * 1000)

            return ExecutionResult(
                success=result.returncode == 0,
                output=result.stdout,
                error=result.stderr,
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
    ) -> ExecutionResult:
        """
        Send a prompt to Claude Code in the VM using -p mode.

        Args:
            prompt: The prompt to send to Claude
            working_dir: Working directory for Claude (default: /workspace)
            timeout: Timeout in seconds
            allowed_tools: List of allowed tools (optional)
            continue_conversation: If True, use -c flag to continue previous conversation
            project: Project folder name under workspace. If provided, Claude will work
                     in /workspace/{project}. Directory will be created if not exists.

        Returns:
            ExecutionResult with Claude's response
        """
        if not self.is_vm_running():
            if not self.start_vm():
                return ExecutionResult(
                    success=False, output="", error="Failed to start VM"
                )

        working_dir = working_dir or self.config.working_dir
        timeout = timeout or self.config.timeout

        # If project is specified, use project directory under workspace
        if project:
            project_dir = f"{self.config.working_dir}/{project}"
            # Create project directory if not exists
            self.execute_in_vm(f"mkdir -p {shlex.quote(project_dir)}")
            working_dir = project_dir

        # Escape the prompt for shell
        escaped_prompt = shlex.quote(prompt)

        # Build claude command with environment variables
        env_vars = ""
        if self.config.anthropic_auth_token:
            env_vars += (
                f"ANTHROPIC_AUTH_TOKEN={shlex.quote(self.config.anthropic_auth_token)} "
            )
        if self.config.anthropic_base_url:
            env_vars += (
                f"ANTHROPIC_BASE_URL={shlex.quote(self.config.anthropic_base_url)} "
            )

        # Build base claude command with flags
        continue_flag = "-c " if continue_conversation else ""
        claude_cmd = f"cd {working_dir} && {env_vars}claude -p {continue_flag}--dangerously-skip-permissions {escaped_prompt}"

        # Add allowed tools if specified
        if allowed_tools:
            tools_str = ",".join(allowed_tools)
            claude_cmd = f"cd {working_dir} && {env_vars}claude -p {continue_flag}--dangerously-skip-permissions --allowedTools {tools_str} {escaped_prompt}"

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

            return ExecutionResult(
                success=result.returncode == 0,
                output=result.stdout,
                error=result.stderr,
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

    def list_files(self, path: str = "/workspace") -> ExecutionResult:
        """List files in a directory in the VM."""
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
        "--vm-name", default="sandbox", help="Name of the Lima VM (default: sandbox)"
    )
    parser.add_argument(
        "--working-dir",
        "-d",
        default="/workspace",
        help="Working directory in VM (default: /workspace)",
    )
    parser.add_argument(
        "--timeout",
        "-t",
        type=int,
        default=300,
        help="Timeout in seconds (default: 300)",
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

    args = parser.parse_args()

    config = SandboxConfig(
        vm_name=args.vm_name, working_dir=args.working_dir, timeout=args.timeout
    )

    controller = CoworkController(config)

    # Handle commands
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
