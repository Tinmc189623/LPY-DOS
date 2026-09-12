; ============================================================================
;  lpydos.inc — LPY-DOS 对外 SDK 主头文件
;  面向第三方 .COM 程序开发者：宏、系统常量、常用子程序与文件封装。
;  使用方式：在程序开头 `include 'lpydos.inc'`，末尾再 `include 'lpydos.inc'`
;            （与 std.asm 一致，主头文件可重复包含）。
;
;  程序约定：
;    - CPUMODE 必须为 use16，代码段起始 org 0100h（.COM 模型，CS=DS=ES=SS）
;    - 通过 INT 21h 访问内核，AH = 功能号
;    - 以 AH=4Ch（fn_exit）或 INT 20h 结束
;
;  Copyright (C) 2026 Nexsteaduser
;  Licensed under GPL v3 or later.
; ============================================================================

; ---- 主头文件：只需在程序中 include 一次 ----
;  自带宏与子库，勿重复 include 以免符号重定义。

; ----------------------------------------------------------------------------
;  SDK 版本（独立于系统 API 版本，供第三方程序区分 SDK 与系统版本）
;  打包格式：0xMMmmrr（MM 主版本 / mm 次版本 / rr 修订），当前为 1.0.0
; ----------------------------------------------------------------------------
LPYDOS_SDK_VER_MAJOR = 1
LPYDOS_SDK_VER_MINOR = 0
LPYDOS_SDK_VER_PATCH = 0
LPYDOS_SDK_VER = (LPYDOS_SDK_VER_MAJOR shl 16) or (LPYDOS_SDK_VER_MINOR shl 8) or LPYDOS_SDK_VER_PATCH

; ----------------------------------------------------------------------------
;  系统常量（对应 INT 21h 常用 AH 值）
;  宏与常量必须先于子库定义，子库内会引用它们。
; ----------------------------------------------------------------------------
AH_TERMINATE  = 00h    ; 终止程序
AH_READ_CH    = 01h    ; 读字符带显
AH_WRITE_CH   = 02h    ; 写字符 DL
AH_WRITE_MSG  = 09h    ; 写 $ 结尾串 DS:DX
AH_READ_LINE  = 0Ah    ; 缓冲输入 DS:DX
AH_GET_DRIVE  = 19h    ; 取当前驱动器
AH_SET_DTA    = 1Ah    ; 设 DTA
AH_GET_DATE   = 2Ah    ; 取日期
AH_GET_TIME   = 2Ch    ; 取时间
AH_GET_VER    = 30h    ; 取版本号
AH_MKDIR      = 39h    ; 建目录
AH_RMDIR      = 3Ah    ; 删目录
AH_CHDIR      = 3Bh    ; 换目录
AH_CREATE     = 3Ch    ; 建文件
AH_OPEN       = 3Dh    ; 开文件
AH_CLOSE      = 3Eh    ; 关文件
AH_READ       = 3Fh    ; 读文件
AH_WRITE      = 40h    ; 写文件
AH_DELETE     = 41h    ; 删文件
AH_GET_CWD    = 47h    ; 取当前目录
AH_EXEC       = 4Bh    ; 执行程序
AH_TERM_CD    = 4Ch    ; 带退出码退出
AH_FIND_FIRST = 4Eh    ; 找首匹配
AH_FIND_NEXT  = 4Fh    ; 找下一匹配
AH_GET_PSP    = 62h    ; 取 PSP

; 标准句柄（AH=3F/40 用）
STDIN   = 0
STDOUT  = 1
STDERR  = 2

; 常见返回码（CF=1 时 AX 的含义）
ERR_INVALID_FN  = 1     ; 功能号非法
ERR_NOT_FOUND   = 2     ; 文件未找到
ERR_PATH        = 3     ; 路径未找到
ERR_HANDLE      = 6     ; 句柄非法
ERR_ACCESS      = 5     ; 访问被拒
ERR_DISK_FULL   = 19h   ; 磁盘已满
ERR_NO_MORE     = 18h   ; 无更多匹配

; ----------------------------------------------------------------------------
;  宏：输出 $ 结尾字符串（AH=09）
; ----------------------------------------------------------------------------
macro puts str {
    mov dx, str
    mov ah, AH_WRITE_MSG
    int 21h
}

; ----------------------------------------------------------------------------
;  宏：输出单个字符（立即数，AH=02）
; ----------------------------------------------------------------------------
macro putch ch {
    mov dl, ch
    mov ah, AH_WRITE_CH
    int 21h
}

; ---- 子库（宏与常量已就绪后引入） ----
include 'logo.inc'       ; 共享 LOGO（带重复 include 保护）
include 'conio.inc'      ; 控制台 I/O
include 'numeric.inc'    ; 数字打印 / 解析 / 输入
include 'sysinfo.inc'    ; 系统信息
include 'fs.inc'         ; 文件系统封装