# 更新日志 Changelog

本项目的显著变更都会记录在此。格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循[语义化版本](https://semver.org/lang/zh-CN/)。

## [1.0.0] - 2026-08-25

首个可用版本。完成了从引导到命令行的完整链路，可直接构建出可启动的 FAT12 软盘镜像。

### 新增

- 8086 实模式内核 `LPYOS.SYS`（对标 `IO.SYS` / `MSDOS.SYS`），加载于 `0x1000:0000`
- FAT12 引导扇区，BPB 参数与 MS-DOS 1.44MB 软盘一致，按 FAT 链加载内核
- FAT12/16 文件系统模块 `fat.asm`，支持文件读写与目录操作
- `MCB` 内存管理模块 `memory.asm`
- `EXEC` 程序加载执行，20 个文件句柄，标准输入 / 输出 / 错误设备
- `INT 20h/21h` 系统调用接口 `api.asm`，含取版本号等服务
- 磁盘底层读写模块 `disk.asm`
- 命令解释器 `LPYCMD.COM`（对标 `COMMAND.COM`）
- 内建命令：`VER`、`ECHO`、`DIR`、`COPY`、`TYPE` 等
- 外部 `.COM` 程序执行
- PowerShell 构建脚本 `build.ps1`，一键编译并生成镜像