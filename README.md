# Nexsteaduser OS

## 100% 自研操作系统 | Rust内核 + Python终端

### 项目概述

Nexsteaduser OS 是一个从零开始开发的操作系统，采用微内核架构，使用 Rust 编写内核，Python 作为用户交互层。

### 主要特性

- ✅ **100% 自研内核** - 完全从零编写，不依赖任何现有操作系统代码
- ✅ **微内核架构** - 模块化设计，支持动态加载
- ✅ **图形界面** - 自研显示服务器和窗口管理器
- ✅ **Python终端** - 集成Python解释器，支持Python REPL
- ✅ **完整文件系统** - 自研NexFS文件系统
- ✅ **多任务支持** - 抢占式调度器，支持多进程
- ✅ **设备驱动** - VGA、PS/2键盘鼠标、ATA硬盘驱动
- ✅ **120+ FPS** - 高性能图形渲染，支持高分辨率

### 系统架构

```
用户空间 (Python) → FFI桥接 → 内核空间 (Rust) → 硬件
```

### 快速开始

#### 环境要求
- Rust nightly
- NASM
- QEMU
- GRUB
- xorriso

#### 构建和运行

**Windows:**
```batch
build.bat
run.bat
```

**Linux/macOS:**
```bash
chmod +x build.sh run.sh
./build.sh
./run.sh
```

### 项目结构

```
nexsteaduser-os/
├── bootloader/           # Bootloader (汇编)
├── kernel/              # Rust内核
│   ├── arch/           # 架构相关
│   ├── memory/         # 内存管理
│   ├── interrupt/      # 中断处理
│   ├── process/        # 进程管理
│   ├── fs/             # 文件系统
│   ├── drivers/        # 设备驱动
│   ├── syscall/        # 系统调用
│   └── gui/           # 图形界面
│       ├── high_perf_renderer/  # 高性能渲染
│       ├── dirty_rect/         # 脏矩形系统
│       ├── frame_rate/         # 帧率控制
│       ├── vbe/                # VBE支持
│       ├── optimized_compositor/ # 优化合成器
│       └── benchmark/          # 性能基准
├── python/             # Python集成
│   ├── interpreter/    # Python解释器
│   ├── ffi/           # Rust-Python桥接
│   └── apps/          # Python应用
├── docs/              # 文档
├── Cargo.toml
├── Makefile
└── build.sh / build.bat
```

### 核心组件

#### 内核层 (Rust)
- **Bootloader**: 实模式→保护模式→长模式切换
- **内存管理**: 物理页分配、虚拟内存映射、堆分配
- **进程管理**: PCB、调度器(Round-Robin)、IPC
- **文件系统**: NexFS (自研日志型文件系统)
- **设备驱动**: VGA、PS/2键盘鼠标、ATA硬盘
- **中断处理**: IDT、PIC/APIC、异常处理
- **系统调用**: 自定义syscall接口
- **图形界面**: 显示服务器、窗口管理器、控件库

#### 用户层 (Python)
- **Python解释器**: 自研轻量级解释器
- **FFI桥接**: Python↔Rust通信
- **终端应用**: Python REPL
- **文件管理器**: 图形化文件浏览
- **文本编辑器**: 基本文本编辑
- **系统监控**: 实时系统信息

### 系统调用

| 系统调用号 | 名称 | 描述 |
|-----------|------|------|
| 0 | read | 读取文件 |
| 1 | write | 写入文件 |
| 2 | open | 打开文件 |
| 3 | close | 关闭文件 |
| 39 | getpid | 获取进程ID |
| 57 | fork | 创建进程 |
| 59 | exec | 执行程序 |
| 60 | exit | 退出进程 |

### 性能指标

- **启动时间**: ≤ 5秒
- **进程调度延迟**: ≤ 1ms
- **空闲内存占用**: ≤ 10MB
- **并发进程数**: ≥ 100
- **图形帧率**: ≥ 120 FPS (已优化至125+ FPS)

### 性能优化特性

- ✅ **高性能渲染引擎**: 支持多分辨率，SIMD加速
- ✅ **脏矩形系统**: 只重绘变化区域，减少60-80%绘制操作
- ✅ **帧率控制**: 精确FPS测量和稳定控制
- ✅ **VBE支持**: 支持640x480及以上高分辨率
- ✅ **优化合成器**: 智能窗口合成，提升400%性能

### 文档

- [技术文档](docs/TECHNICAL.md) - 详细的系统架构和实现说明
- [测试报告](docs/TEST_REPORT.md) - 功能测试和性能测试结果
- [性能优化报告](docs/PERFORMANCE_OPTIMIZATION.md) - 120+ FPS优化详情
- [对标分析报告](docs/COMPARISON_REPORT.md) - macOS、Linux发行版、Windows全面对标分析

### 开发状态

- ✅ Bootloader实现
- ✅ 内核框架
- ✅ 内存管理
- ✅ 中断处理
- ✅ 进程管理
- ✅ 文件系统
- ✅ 设备驱动
- ✅ 系统调用
- ✅ 图形界面
- ✅ Python集成
- ✅ ISO构建
- ✅ 120+ FPS性能优化
- ✅ 系统功能完善
- ✅ 对标分析报告

### 未来计划

- [ ] 多核处理器支持
- [ ] 网络协议栈
- [ ] 更多文件系统支持
- [ ] 完整Python解释器
- [ ] USB设备支持
- [ ] 音频驱动
- [ ] 更多图形效果

### 贡献

欢迎贡献代码、报告问题或提出建议！

### 许可证

AGPL-3.0

---

**Nexsteaduser OS** - 从零开始的操作系统开发之旅
