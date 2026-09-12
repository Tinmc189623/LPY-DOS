# LPY-DOS SDK

对外公开的第三方 `.COM` 程序开发套件。基于 8086 汇编（FASM），
为在 LPY-DOS 上编写、编译、运行独立应用提供头文件库、示例与构建脚本。

- 项目：LPY-DOS
- 团队：Nexlyh
- 版本：1.0.0（常量 `LPYDOS_SDK_VER`）
- 许可：GNU GPL v3 或更高版本
- 版权：Copyright © 2026 Nexsteaduser. All Rights Reserved

## 目录结构

```
sdk/
├── API.md               # 本文档
├── build.ps1            # 示例编译脚本（Windows PowerShell 7+）
├── build.bat            # 示例编译脚本（Windows CMD）
├── build.sh             # 示例编译脚本（POSIX sh）
├── build.bash           # 示例编译脚本（Bash）
├── include/             # 对外头文件库
│   ├── lpydos.inc       #   主头文件：常量 + 宏，并引入以下子库
│   ├── conio.inc        #   控制台 I/O
│   ├── numeric.inc      #   数字打印 / 解析 / 输入
│   ├── sysinfo.inc      #   系统信息
│   └── fs.inc           #   文件系统封装
└── examples/            # 第三方示例
    ├── hello.asm        #   最小入门示例
    └── app.asm          #   综合示例（控制台+系统信息+文件系统）
```

## 环境要求

- 8086 汇编，`.COM` 文件模型：`use16` + `org 0100h`（CS=DS=ES=SS）。
- 编译器：[FASM](https://flatassembler.net/)。
- 宿主系统：LPY-DOS（内核 INT 21h 兼容 MS-DOS 调用约定）。

## 快速开始

在程序开头 `include` 主头文件一次（勿重复包含）：

```asm
use16
org 0100h
include '../include/lpydos.inc'

start:
    puts msg_hello
    call crlf
    mov ah, AH_TERM_CD        ; 带退出码退出
    int 21h

msg_hello db 'Hello from SDK!$'
```

编译并运行：

```powershell
# 1. 编译所有示例
pwsh sdk/build.ps1 all

# 2. 或只编译单个示例
pwsh sdk/build.ps1 app
```

也可使用其它平台的构建脚本（三者都会自动查找 FASM，
找不到时提示安装，找到则直接使用定位到的路径）：

| 脚本 | 平台 |
| --- | --- |
| `sdk/build.ps1` | Windows PowerShell 7+ |
| `sdk/build.bat` | Windows CMD |
| `sdk/build.sh` | POSIX sh（Unix/Linux/WSL） |
| `sdk/build.bash` | Bash |

工具定位优先级统一为：环境变量 `LPYDOS_FASM` → `PATH` → 常见安装路径。

把生成的 `.COM` 放入系统 FAT12 镜像后，即可在 LPYCMD 命令行直接输入文件名运行。

## 对外 API 一览

### 宏

| 宏 | 说明 |
| --- | --- |
| `puts str` | 输出 `$` 结尾字符串 |
| `putch ch` | 输出单个字符（立即数） |

### 控制台 I/O（`conio.inc`）

| 例程 | 说明 |
| --- | --- |
| `crlf` | 输出回车换行 |
| `putc` | 输出 `DL` 中字符 |
| `puts_str` | 输出 `DS:DX` 处 `$` 结尾字符串 |
| `get_key` | 读按键（无回显），`AL`=字符，扩展键返回 0 |
| `get_key_echo` | 读按键并回显，`AL`=字符 |
| `wait_key` | 打印 `:` 后等待按键 |
| `delay_ticks` | 延时 `CX` 个时钟滴答（≈18.2 滴答/秒） |
| `setcurs` | 光标定位到（`DH`=行，`DL`=列） |

### 数字（`numeric.inc`）

| 例程 | 说明 |
| --- | --- |
| `put_dec16` | 输出 `AX` 无符号十进制 |
| `put_hex16` | 输出 `AX` 十六进制（4 位，大写） |
| `put_hex8` | 输出 `AL` 十六进制（2 位，大写） |
| `atoi_dec` | `DS:SI` 十进制串 → `AX` |
| `read_num` | 打印 `DS:DX` 提示后读入无符号数 → `AX` |

### 系统信息（`sysinfo.inc`）

| 例程 | 说明 |
| --- | --- |
| `get_sysver` | 取版本号，`AX`=主.次 |
| `get_date` | `CX`=年，`DH`=月，`DL`=日，`AL`=星期 |
| `get_time` | `CH`=时，`CL`=分，`DH`=秒，`DL`=百分秒 |
| `get_drive` | 取当前驱动器号（0=A） |
| `print_date_line` | 打印 `YYYY-MM-DD` 换行 |
| `print_time_line` | 打印 `HH:MM:SS` 换行 |

### 文件系统（`fs.inc`）

| 例程 | 说明 |
| --- | --- |
| `open_file` | 打开已存在文件，`DS:DX`=路径 → `AX`=句柄 |
| `create_file` | 创建文件（存在则截断），`DS:DX`=路径，`CL`=属性 |
| `read_file` | 读文件，`BX`=句柄，`CX`=字节，`DS:DX`=缓冲 → `AX`=读取数 |
| `write_file` | 写文件，`BX`=句柄，`CX`=字节，`DS:DX`=源 → `AX`=写入数 |
| `close_file` | 关闭句柄，`BX`=句柄 |
| `delete_file` | 删除文件，`DS:DX`=路径 |

### 系统常量

- 功能号：`AH_TERMINATE`、`AH_READ_CH`、`AH_WRITE_CH`、`AH_WRITE_MSG`、
  `AH_GET_DATE`、`AH_GET_TIME`、`AH_GET_VER`、`AH_CREATE`、`AH_OPEN`、
  `AH_CLOSE`、`AH_READ`、`AH_WRITE`、`AH_DELETE`、`AH_MKDIR`、`AH_RMDIR`、
  `AH_CHDIR`、`AH_GET_CWD`、`AH_EXEC`、`AH_TERM_CD`、`AH_FIND_FIRST`、
  `AH_FIND_NEXT`、`AH_GET_PSP`。
- 标准句柄：`STDIN`=0、`STDOUT`=1、`STDERR`=2。
- 返回码（`CF`=1 时 `AX`）：`ERR_INVALID_FN`、`ERR_NOT_FOUND`、`ERR_PATH`、
  `ERR_ACCESS`、`ERR_HANDLE`、`ERR_NO_MORE`、`ERR_DISK_FULL`。

### SDK 版本常量

| 常量 | 值 | 说明 |
| --- | --- | --- |
| `LPYDOS_SDK_VER_MAJOR` | 1 | 主版本 |
| `LPYDOS_SDK_VER_MINOR` | 0 | 次版本 |
| `LPYDOS_SDK_VER_PATCH` | 0 | 修订版本 |
| `LPYDOS_SDK_VER` | `0x010000` | 打包版本号（`0xMMmmrr`），即 1.0.0 |

SDK 版本独立于系统 API 版本：`LPYDOS_SDK_VER` 标识 SDK 自身，
系统 API 版本由 `get_sysver`（INT 21h `AH=30h`）返回。示例：

```asm
; 打印 SDK 版本（1.0.0）
mov al, LPYDOS_SDK_VER_MAJOR
call put_dec16
putch '.'
mov al, LPYDOS_SDK_VER_MINOR
call put_dec16
putch '.'
mov al, LPYDOS_SDK_VER_PATCH
call put_dec16
```

## 调用约定

- 通过 `INT 21h` 访问内核，`AH`=功能号，`CF`=1 表示出错且 `AX`=错误码。
- 文件路径 / 缓冲均以 `DS:DX` 传递，内核内部解析调用者数据段，无需手动切段。
- 文件读写采用句柄模型（对标 MS-DOS），句柄用 `BX` 传递。

## 库 LOGO（`logo.inc`）

五个 SDK 库各带一份纯字符 ASCII 横幅（`#` 前景、`.` 背景），并共享同一个渲染
例程 `render_logo`，直接写文本显存 `0B800h`（char+attr）居中显示，带各库专属颜色。

### 打印某库 LOGO 的例程

| 例程 | 所属库 | 颜色 |
| --- | --- | --- |
| `lpy_logo_print` | `lpydos.inc` | 白字 / 红底（0x4F） |
| `conio_logo_print` | `conio.inc` | 白字 / 蓝底（0x1F） |
| `fs_logo_print` | `fs.inc` | 白字 / 绿底（0x2F） |
| `num_logo_print` | `numeric.inc` | 白字 / 黄底（0x6F） |
| `sys_logo_print` | `sysinfo.inc` | 白字 / 青底（0x3F） |

`logo.inc` 自带重复 include 保护（`if defined LOGO_INC`），被 `lpydos.inc` 及各子库
重复引用也不会符号重定义；渲染逻辑仅一份，五个库只各提供一个装载自身参数的入口，符合 DRY。

### 输出 LOGO 示例片段

```asm
use16
org 0100h
include '../include/lpydos.inc'

start:
    call lpy_logo_print     ; 打印 LPYDOS 横幅（居中，白字红底）
    call crlf
    mov ah, AH_TERM_CD
    xor al, al
    int 21h
```

### 展示示例 logo.COM

新增 `sdk/examples/logo.asm`（已编译为 `logo.COM`），按命令行参数打印指定库的 LOGO：

```powershell
& 'D:\fasm\FASM.EXE' 'sdk\examples\logo.asm' 'sdk\examples\logo.COM'
```

运行（将 `logo.COM` 放入系统 FAT12 镜像后在 LPYCMD 中）：

```text
logo lpydos        ; 打印 LPYDOS 库 LOGO
logo conio         ; 打印 CONIO 库 LOGO
logo fs            ; 打印 FS 库 LOGO
logo numeric       ; 打印 NUMERIC 库 LOGO
logo sysinfo       ; 打印 SYSINFO 库 LOGO
logo               ; 无参数时打印用法提示
```