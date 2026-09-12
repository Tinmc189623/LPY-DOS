# LPY-DOS

LPY-DOS 是一个面向 Intel 8086 实模式的实验性 DOS 风格操作系统。项目包含启动扇区、内核、命令解释器、FAT 文件系统支持和一组可执行的 `.COM` 工具，目标是用清晰、可追踪的汇编代码实现从 BIOS 启动到命令行交互的完整链路。

项目由 Nexsteaduser 维护。

## 当前状态

仓库正在进行两阶段引导重构。已存在的 v1 FAT12 链路、内核、Shell 和外部程序仍是项目的主要可运行内容；`boot/boot12.asm`、`boot/boot16.asm`、`boot/boot32.asm`、`boot/loadr.asm` 和 `boot/mbr.asm` 属于重构中的引导组件。

当前工作区的 `build.ps1` 与 `build.sh` 仍使用旧的 `boot/boot.asm` 入口，而新的 `boot.asm` 需要由 `boot12/16/32.asm` 提供编译期参数。因此完整镜像构建入口还在整合中，不能把当前源码状态当作已发布构建。

## 特性

- 使用 FASM 编译 16 位实模式汇编代码。
- 内核加载到 `0x1000:0000`，提供磁盘、FAT、内存和系统调用模块。
- 支持 FAT12 文件系统，并保留 FAT16/FAT32 引导重构所需的代码结构。
- 提供 `LPYCMD.COM` 命令解释器和外部 `.COM` 程序执行能力。
- 包含文本模式工具与图形模式实验程序，例如 `ggrid`、`gline`、`gmandel` 和 `gplasma`。
- `boot/SQBoot.asm` 提供紧急引导扇区：尝试读取 FAT32 常见备份引导扇区 LBA 6，失败时显示原因并停机。
- 启动扇区使用 `0xAA55` BIOS 签名，并限制在 512 字节内。

## 目录结构

| 路径 | 用途 |
| --- | --- |
| `boot/` | 启动扇区、引导宏和引导重构组件 |
| `kernel/` | 内核及磁盘、FAT、内存、图形、API 模块 |
| `shell/` | 命令解释器 |
| `programs/` | 外部 `.COM` 程序及其汇编源文件 |
| `sdk/` | SDK 头文件、示例和构建辅助工具 |
| `docs/` | 需求、设计和实现记录 |
| `tools/` | 镜像和原始数据辅助工具 |
| `build.ps1` | Windows 构建脚本 |
| `build.sh` | POSIX shell 构建脚本 |
| `CHANGELOG.md` | 版本变更记录 |

## 环境要求

- Windows 11 建议使用 PowerShell 7+；Linux/macOS 可使用兼容的 POSIX shell。
- FASM 1.73 或更高版本，并将 `fasm` 加入 `PATH`；也可以设置 `LPYDOS_FASM` 指向 FASM 可执行文件。
- QEMU `qemu-system-i386` 仅在需要启动镜像时使用。

## 快速验证紧急引导

`SQBoot.asm` 可以独立编译，不依赖完整镜像构建：

```powershell
$fasm = (Get-Command fasm).Source
& $fasm boot\SQBoot.asm $env:TEMP\SQBoot.bin
$bytes = [IO.File]::ReadAllBytes("$env:TEMP\SQBoot.bin")
"size=$($bytes.Length) signature=$('{0:X2} {1:X2}' -f $bytes[510], $bytes[511])"
```

预期结果是 `size=512 signature=55 AA`。将该扇区写入测试介质前，请确认目标设备和备份；低级写盘操作可能覆盖现有数据。

## 构建镜像

在构建入口完成与两阶段引导重构的同步后，Windows 下使用：

```powershell
pwsh -File .\build.ps1
```

全部构建产物统一输出到 `bin/` 目录（`LPY-DOS.img`、`LPYOS.SYS`、`LPYCMD.COM` 及 `bin/programs/` 下的 `.COM` 文件，均不入库）。生成镜像后，可用 QEMU 启动：

```powershell
qemu-system-i386 -fda .in\LPY-DOS.img -boot a
```

当前重构阶段若直接运行完整构建，`boot/boot.asm` 会报告缺少 `FATBITS`；请先使用对应的 `boot12.asm`、`boot16.asm` 或 `boot32.asm` 包装入口，或等待构建脚本整合完成。

## 开发约定

- 保持启动扇区不超过 512 字节，并保留末尾 `0xAA55` 签名。
- 8086 兼容路径只使用 8086 指令集；需要 32 位寄存器的代码应放在明确允许的阶段。
- 修改引导、内核或文件系统后，至少执行一次 FASM 编译和尺寸检查。
- 新增外部程序时，同时提交 `programs/<name>.asm`；构建脚本会生成对应的 `.COM` 文件。
- 设计背景和引导链约束记录在 `docs/` 中，版本变化记录在 `CHANGELOG.md` 中。

## 贡献

请在提交前说明修改的启动阶段或系统模块、验证命令和已知限制。涉及磁盘写入、引导扇区或文件系统的改动，应附带可复现的测试步骤。

## 许可证

本项目按 GNU GPL v3 或更高版本发布，详见 [LICENSE](LICENSE)。

Copyright © 2026 Nexsteaduser. All Rights Reserved