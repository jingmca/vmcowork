#!/usr/bin/env python3
"""
Cowork Sandbox Example
演示如何使用 Python API 与 Claude Code 交互
"""

import os
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from host.controller import CoworkController, SandboxConfig, ExecutionResult


def example_basic_usage():
    """基础用法示例"""
    print("=" * 60)
    print("示例 1: 基础用法")
    print("=" * 60)

    # 创建控制器
    controller = CoworkController()

    # 检查 VM 状态
    if not controller.is_vm_running():
        print("VM 未运行，正在启动...")
        if not controller.start_vm():
            print("❌ VM 启动失败")
            return
    else:
        print("✓ VM 正在运行")

    # 获取 VM 信息
    info = controller.get_vm_info()
    print(f"\nVM 信息:")
    print(f"  Python: {info.get('python_version', 'N/A')}")
    print(f"  Node.js: {info.get('node_version', 'N/A')}")
    print(f"  Claude: {info.get('claude_version', 'N/A')}")


def example_execute_commands():
    """执行命令示例"""
    print("\n" + "=" * 60)
    print("示例 2: 在 VM 中执行命令")
    print("=" * 60)

    controller = CoworkController()

    # 执行简单命令
    result = controller.execute_in_vm("echo 'Hello from VM!'")
    if result.success:
        print(f"✓ 命令执行成功: {result.output.strip()}")
    else:
        print(f"❌ 命令执行失败: {result.error}")

    # 检查文件系统
    result = controller.execute_in_vm("ls -la /workspace")
    if result.success:
        print(f"\n/workspace 目录内容:")
        print(result.output)


def example_file_operations():
    """文件操作示例"""
    print("\n" + "=" * 60)
    print("示例 3: 文件读写操作")
    print("=" * 60)

    controller = CoworkController()

    # 写入文件
    test_content = "This is a test file\nCreated by example.py\n"
    result = controller.write_file("/workspace/test.txt", test_content)
    if result.success:
        print("✓ 文件写入成功")
    else:
        print(f"❌ 文件写入失败: {result.error}")

    # 读取文件
    result = controller.read_file("/workspace/test.txt")
    if result.success:
        print(f"✓ 文件读取成功:")
        print(result.output)
    else:
        print(f"❌ 文件读取失败: {result.error}")


def example_claude_interaction():
    """Claude Code 交互示例"""
    print("\n" + "=" * 60)
    print("示例 4: 与 Claude Code 交互（需要 API 配置）")
    print("=" * 60)

    # 检查是否配置了 API
    if not os.environ.get("ANTHROPIC_AUTH_TOKEN"):
        print("⚠ 未设置 ANTHROPIC_AUTH_TOKEN 环境变量")
        print("  请运行: export ANTHROPIC_AUTH_TOKEN='your-token'")
        return

    if not os.environ.get("ANTHROPIC_BASE_URL"):
        print("⚠ 未设置 ANTHROPIC_BASE_URL 环境变量")
        print("  请运行: export ANTHROPIC_BASE_URL='https://your-api-endpoint'")
        return

    controller = CoworkController()

    # 简单对话
    print("\n发送 prompt: '创建一个简单的 hello world Python 脚本'")
    result = controller.ask_claude(
        "创建一个简单的 hello world Python 脚本，保存为 hello.py"
    )

    if result.success:
        print(f"✓ Claude 响应:")
        print(result.output[:500])  # 只显示前 500 字符
        if len(result.output) > 500:
            print("... (输出已截断)")
    else:
        print(f"❌ 请求失败: {result.error}")


def example_project_workflow():
    """项目工作流示例"""
    print("\n" + "=" * 60)
    print("示例 5: 项目工作流")
    print("=" * 60)

    controller = CoworkController()

    project_name = "example_project"

    # 步骤 1: 创建项目目录
    print(f"\n1. 创建项目目录: {project_name}")
    result = controller.execute_in_vm(f"mkdir -p /workspace/{project_name}")
    if result.success:
        print("✓ 项目目录创建成功")
    else:
        print(f"❌ 创建失败: {result.error}")
        return

    # 步骤 2: 创建 README
    readme_content = f"""# {project_name}

这是一个由 Cowork Sandbox 创建的示例项目。

## 结构

```
{project_name}/
├── README.md
├── src/
└── tests/
```
"""
    result = controller.write_file(
        f"/workspace/{project_name}/README.md", readme_content
    )
    if result.success:
        print("✓ README.md 创建成功")

    # 步骤 3: 创建目录结构
    result = controller.execute_in_vm(
        f"cd /workspace/{project_name} && mkdir -p src tests"
    )
    if result.success:
        print("✓ 目录结构创建成功")

    # 步骤 4: 列出项目文件
    result = controller.execute_in_vm(f"tree /workspace/{project_name} || ls -la /workspace/{project_name}")
    if result.success:
        print(f"\n项目结构:")
        print(result.output)


def example_with_api_configuration():
    """使用自定义 API 配置的示例"""
    print("\n" + "=" * 60)
    print("示例 6: 使用自定义配置")
    print("=" * 60)

    # 从环境变量读取配置
    config = SandboxConfig(
        vm_name="sandbox",
        working_dir="/workspace",
        timeout=300,
        anthropic_auth_token=os.environ.get("ANTHROPIC_AUTH_TOKEN", ""),
        anthropic_base_url=os.environ.get("ANTHROPIC_BASE_URL", ""),
    )

    controller = CoworkController(config)

    # 显示配置信息
    print(f"配置信息:")
    print(f"  VM 名称: {config.vm_name}")
    print(f"  工作目录: {config.working_dir}")
    print(f"  超时时间: {config.timeout}s")
    print(f"  API Token: {'已配置' if config.anthropic_auth_token else '未配置'}")
    print(f"  API URL: {'已配置' if config.anthropic_base_url else '未配置'}")


def main():
    """运行所有示例"""
    print("\n" + "=" * 60)
    print("Cowork Sandbox Python API 示例")
    print("=" * 60)

    try:
        # 运行示例
        example_basic_usage()
        example_execute_commands()
        example_file_operations()
        example_project_workflow()
        example_with_api_configuration()
        example_claude_interaction()

        print("\n" + "=" * 60)
        print("✓ 所有示例运行完成")
        print("=" * 60)

    except KeyboardInterrupt:
        print("\n\n⚠ 用户中断")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ 错误: {e}")
        import traceback

        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
