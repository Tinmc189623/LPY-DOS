# LPY-DOS

一款用 8086 汇编从零写出来的 DOS 系统，目标是做一套干净、可读、能跑起来的 MS-DOS 同构实现。

内核三层分工，对标 MS-DOS 的经典结构：

| 组件 | 文件 | 对标 | 职责 |
| --- | --- | --- | --- |
| 引导程序 | `boot/boot.asm` | 引导扇区 | 解析 FAT12 根目录，按 FAT 链加载内核到内存 |
| 内核 | `kernel/kernel.asm` + 模块 | `IO.SYS` / `MSDOS.SYS` | 实模式内核，提供系统调用、文件系统、内存管理、进程执行 |
| 命令解释器 | `shell/shell.asm` | `COMMAND.COM` | 内建命令 + 外部 `.COM` 程序执行 |

## 功能

- FAT12 / 1.44MB 软盘文件系统，引导扇区 BPB 与 MS-DOS 完全一致
- 实模式内核，加载于 `0x1000:0000`，支持 `INT 20h/21h` 系统调用
- FAT12/16 文件读写、`MCB` 内存管理、`EXEC` 程序加载执行
- 20 个文件句柄，标准输入 / 输出 / 错误设备
- 命令解释器支持 `ECHO`、`DIR`、`COPY`、`TYPE` 等内建命令与外部 `.COM` 程序

## 构建

需要：

- [FASM](https://flatassembler.net/)（汇编器）
- PowerShell 7+（构建脚本）
- QEMU（可选，用于运行）

`build.ps1` 开头的 `$Fasm`、`$Qemu` 变量指向本机工具路径，需要按实际环境调整：

```powershell
pwsh build.ps1      # 仅构建镜像
pwsh build.ps1 run  # 构建后启动 QEMU
```

构建产物：

- `LPYOS.SYS` — 内核
- `LPYCMD.COM` — 命令解释器
- `LPY-DOS.img` — FAT12 1.44MB 软盘镜像

## 运行

构建成功后用 QEMU 启动镜像：

```powershell
pwsh build.ps1 run
```

BIOS 从软盘镜像引导后由引导扇区加载 `LPYOS.SYS`，内核初始化完毕会拉起 `LPYCMD.COM` 进入命令行。

## 目录结构

```
LPY-DOS/
├── boot/           # 引导扇区
│   └── boot.asm
├── kernel/         # 内核主文件与模块
│   ├── kernel.asm  # 内核主文件 LPYOS.SYS
│   ├── api.asm     # 系统调用接口
│   ├── disk.asm    # 磁盘底层读写
│   ├── fat.asm     # FAT12/16 文件系统
│   └── memory.asm  # MCB 内存管理
├── shell/          # 命令解释器
│   └── shell.asm
└── build.ps1       # 构建脚本
```

## License

GNU General Public License v3.0 — 详见 [LICENSE](LICENSE)。

Copyright © 2026 Nexlyh. All Rights Reserved