# Cowork 模式调研报告

> 基于 Simon Willison 对 Claude Code Cowork 模式的逆向工程分析

## 1. 背景

Claude Code 是 Anthropic 推出的 CLI 工具，其 "Cowork 模式" 提供了一个安全的沙箱环境来执行代码。本文档记录了对该模式的技术调研。

## 2. 信息来源

- GitHub Gist: https://gist.github.com/simonw/35732f187edbe4fbd0bf976d013f22c8
- 逆向工程方法：分析 Claude.app 的 Swift 原生模块和 VM 配置

## 3. 技术架构分析

### 3.1 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        macOS Host                               │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                     Claude.app                             │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐   │ │
│  │  │ Swift VM    │  │ Proxy       │  │ Shared          │   │ │
│  │  │ Manager     │  │ Server      │  │ Directory       │   │ │
│  │  └──────┬──────┘  └──────┬──────┘  └────────┬────────┘   │ │
│  └─────────┼────────────────┼──────────────────┼────────────┘ │
│            │                │                  │               │
│     Virtualization.framework│ socat           │ VZSharedDir   │
└────────────┼────────────────┼──────────────────┼───────────────┘
             │                │                  │
═════════════╪════════════════╪══════════════════╪═══════════════
             │                │                  │
┌────────────┼────────────────┼──────────────────┼───────────────┐
│            ▼                ▼                  ▼               │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                   Ubuntu 22.04 VM                        │  │
│  │                                                          │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │  │
│  │  │ Claude Code  │  │ Bubblewrap   │  │ Seccomp      │   │  │
│  │  │ CLI          │  │ Sandbox      │  │ Filter       │   │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘   │  │
│  └─────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
```

### 3.2 虚拟化层

| 组件 | 技术 | 说明 |
|------|------|------|
| 虚拟化框架 | Apple Virtualization.framework | macOS 原生虚拟化 |
| 操作系统 | Ubuntu 22.04.5 LTS (Jammy) | ARM64 架构 |
| CPU | 4 核 | 虚拟 CPU |
| 内存 | 3.8 GB | 分配给 VM |
| 存储 | 10GB NVMe | 虚拟磁盘 |

### 3.3 沙箱隔离层（多层防御）

#### 第一层：虚拟机隔离
- 完全隔离 guest 和 host 系统
- 即使 VM 被攻破也无法直接影响 host

#### 第二层：Bubblewrap (bwrap)
- 命名空间隔离（PID, Network, Mount, User）
- 文件系统只读挂载
- 防止进程逃逸

```bash
# Bubblewrap 典型配置
bwrap \
  --ro-bind /usr /usr \          # 只读挂载系统目录
  --ro-bind /lib /lib \
  --tmpfs /tmp \                  # 临时文件系统
  --proc /proc \
  --dev /dev \
  --unshare-all \                 # 隔离所有命名空间
  --die-with-parent \             # 父进程死亡时终止
  --cap-drop ALL \                # 丢弃所有 capabilities
  -- /bin/bash
```

#### 第三层：Seccomp 过滤
- 系统调用白名单
- 阻止危险的 syscall（如 ptrace, mount）
- 防止内核级攻击

### 3.4 网络架构

```
┌─────────────────┐
│   macOS Host    │
│                 │
│  ┌───────────┐  │      ┌─────────────┐
│  │ socat     │◄─┼──────│ 外部网络    │
│  │ :3128 HTTP│  │      └─────────────┘
│  │ :1080 SOCKS│ │
│  └─────┬─────┘  │
└────────┼────────┘
         │ Unix Socket / localhost
┌────────┼────────┐
│   VM   ▼        │
│  ┌───────────┐  │
│  │ HTTP_PROXY│  │
│  │ 环境变量  │  │
│  └───────────┘  │
└─────────────────┘
```

- HTTP 流量通过 3128 端口代理
- SOCKS5 流量通过 1080 端口代理
- 使用 socat 进行 Unix Socket 转发
- 便于流量审计和控制

### 3.5 Host-Guest 通信

#### 主要通信方式

1. **Virtio-vsock**
   - VM 和 Host 之间的直接 socket 通信
   - 低延迟、高效率
   - 用于控制命令传输

2. **共享目录 (VZSharedDirectory)**
   - Host 目录挂载到 VM
   - 用于文件交换
   - 支持读写控制

3. **网络代理**
   - VM 通过 Host 代理访问外网
   - 便于流量控制

### 3.6 预装软件环境

根据逆向分析，VM 内预装约 1,201 个软件包：

| 类别 | 软件 | 版本 |
|------|------|------|
| 语言运行时 | Python | 3.10 |
| | Node.js | 22.21.0 |
| | Java | 11 (OpenJDK) |
| 编译工具 | GCC | 11.4.0 |
| | Make, CMake | - |
| **未安装** | Go | - |
| | Rust | - |
| | Docker | - |

### 3.7 技能模块 (Skills)

VM 内包含用于处理特定任务的技能模块：

- PDF 处理
- DOCX 处理
- XLSX 处理
- PPTX 处理
- 设计相关能力

## 4. 关键发现

### 4.1 为什么使用多层沙箱？

**问题**：既然已经在 VM 里隔离了，为什么还需要 Bubblewrap？

**答案**：纵深防御（Defense in Depth）

```
攻击路径分析：

仅 VM 隔离:
  恶意代码 → VM 内完整权限 → VM 逃逸漏洞 → Host 被攻破

VM + Bubblewrap:
  恶意代码 → Bubblewrap 受限环境 → 逃出 bwrap → VM 权限 → VM 逃逸 → Host
              ↑                      ↑
           第一道防线              第二道防线
```

### 4.2 Claude Code 沙盒模式 vs Cowork 模式

| 特性 | 沙盒模式 | Cowork 模式 |
|------|----------|-------------|
| 隔离级别 | 权限确认 | 完整 VM 隔离 |
| 执行环境 | 本机 macOS | Ubuntu VM |
| 安全性 | 中等 | 高 |
| 性能 | 原生 | 有 VM 开销 |
| 用途 | 日常使用 | 高风险代码执行 |

### 4.3 性能考量

- VM 启动时间：可能使用快照/休眠恢复加速
- 资源限制：4核/4GB 是平衡点
- 网络延迟：代理层会增加少量延迟

## 5. 安全评估

### 优点

1. **多层隔离**：VM + Bubblewrap + Seccomp 提供纵深防御
2. **网络可控**：所有流量通过代理，便于审计
3. **资源限制**：防止资源耗尽攻击
4. **最小权限**：代码执行在受限环境中

### 潜在风险

1. **VM 逃逸**：虽然罕见，但 VM 逃逸漏洞存在
2. **Side-channel 攻击**：共享硬件可能存在信息泄露
3. **网络攻击**：VM 有网络访问能力

## 6. 结论

Claude Code 的 Cowork 模式采用了企业级的安全架构：

1. 使用 Apple 原生虚拟化框架
2. 多层沙箱（VM + Bubblewrap + Seccomp）
3. 网络代理层控制外部访问
4. 精简的预装环境

这是一个成熟的、经过深思熟虑的安全方案，适合执行不受信任的代码。

## 7. 参考资料

- [Apple Virtualization Framework](https://developer.apple.com/documentation/virtualization)
- [Bubblewrap](https://github.com/containers/bubblewrap)
- [Seccomp](https://man7.org/linux/man-pages/man2/seccomp.2.html)
- [Lima - Linux Machines](https://github.com/lima-vm/lima)
