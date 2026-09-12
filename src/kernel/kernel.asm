; ============================================================================
;  LPY-DOS 内核主文件 LPYOS.SYS
;  实模式内核：提供系统调用、文件系统、内存管理与 EXEC
;  加载地址：0x1000:0x0000（引导扇区加载），CS=DS=ES=SS=0x1000, SP=0xFFFE
;  提供 INT 20h/21h 系统调用、FAT12/16 文件系统、MCB 内存管理与 EXEC
;
;  编译：fasm kernel.asm LPYOS.SYS（结合其他模块）
;
;  Copyright (C) 2026 Nexsteaduser
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
; ============================================================================

use16
org 0

; ----------------------------------------------------------------------------
;  常量定义
; ----------------------------------------------------------------------------
KERNEL_SEG      equ 1000h      ; 内核代码/数据段
SYS_PSP_SEG     equ 0050h      ; 内核自身 PSP 段（低内存固定）
MEM_TOP_SEG     equ 9F00h      ; 640KB 边界段（可用内存顶端）
NUM_HANDLES     equ 20         ; 文件句柄数量
STDIN           equ 0          ; 标准输入句柄
STDOUT          equ 1          ; 标准输出句柄
STDERR          equ 2          ; 标准错误句柄
; 文件属性
ATTR_READONLY   equ 01h
ATTR_HIDDEN     equ 02h
ATTR_SYSTEM     equ 04h
ATTR_VOLUME     equ 08h
ATTR_DIR        equ 10h
ATTR_ARCHIVE    equ 20h

; 文件描述符（fd）结构体布局
FD_FLAGS        equ 0          ; 状态：0=空闲
FD_CLUSTER      equ 2          ; 起始簇号
FD_CURCLU       equ 4          ; 当前簇号
FD_CURPOS       equ 6          ; 当前簇覆盖的文件偏移起点（4 字节）
FD_SIZE         equ 10         ; 文件大小（4 字节）
FD_POS          equ 14         ; 当前文件位置（4 字节）
FD_DIRSEC       equ 18         ; 目录项所在扇区 LBA
FD_DIROFF       equ 20         ; 目录项在扇区内偏移
FD_ATTR         equ 22         ; 文件属性
FD_NAME         equ 23         ; 8.3 文件名（11 字节）
FD_LEN          equ 34         ; 描述符总长度

; ============================================================================
;  入口：跳过多余数据区，从 kentry 开始
; ============================================================================
        jmp kentry

; ----------------------------------------------------------------------------
;  头部信息区（版本号来自 src/build/version.inc，由 build.ps1 从 version.ini 生成）
; ----------------------------------------------------------------------------
include '..\build\version.inc'
kern_signature  db 'LPY-DOS kernel (LPYOS.SYS) v', '0'+VER_MAJOR, '.', '0'+VER_MINOR, '.', '0'+VER_PATCH, 0
kern_version    db VER_MAJOR, VER_MINOR, VER_PATCH   ; 主/次/修订

; ----------------------------------------------------------------------------
;  系统变量区
; ----------------------------------------------------------------------------
boot_drive      db 0            ; 引导驱动器号（0=A）
partition_base  dw 0            ; 分区起始 LBA（MBR 引导时由 CTX 块 +2 提供；软盘=0）
current_drive   db 0            ; 当前默认驱动器
current_dir     db 64 dup(0)    ; 当前目录串（如 '\SUB\DIR'，不含盘符）
cur_dir_first   dw 0            ; 当前目录第一个簇（0=根目录）
current_psp      dw 0            ; 当前 PSP 段
caller_ds        dw 0            ; INT 21h 调用者 DS（参数段）
caller_es        dw 0            ; INT 21h 调用者 ES
term_request     db 0            ; 程序终止请求标志
term_code        db 0            ; 退出码（AH=4C）
verify_flag      db 0            ; AH=2E 写后校验开关（0=关,1=开）
ctrlc_flag       db 1            ; AH=33 Ctrl-C 检测开关（1=开）
; 文件句柄表 0/1/2 设备句柄初始化值
handle_init      dw 8000h, 8001h, 8002h
; BPB 现场数据（从磁盘引导扇区读出）
bpb_byts_per_sec dw 512
bpb_sec_per_clus dw 1
bpb_rsvd_sec_cnt dw 1
bpb_num_fats     dw 2
bpb_root_ent_cnt dw 224
bpb_fat_sz16     dw 9
bpb_sec_per_trk  dw 18
bpb_num_heads    dw 2
fat_start        dw 1           ; FAT 区起始扇区
root_dir_start   dw 19          ; 根目录区起始扇区
root_dir_sects   dw 15          ; 根目录区占扇区数
data_start       dw 34          ; 数据区起始扇区
; 磁盘传输区（DTA，对标 MS-DOS，用于查找文件结果）
; 默认 DTA 指向内核 PSP:0x80；INT 21h AH=1A 可重定向
dta_seg         dw SYS_PSP_SEG   ; DTA 段
dta_off         dw 80h           ; DTA 偏移
dta_area        db 128 dup(0)    ; 内核自带 DTA 区（供无显式 DTA 时兜底）
; 输入行缓冲（AH=0A 使用）
line_buf         db 128         ; 最大长度
line_len         db 0           ; 实际长度
line_data        db 128 dup(0)
; 内部临时缓冲区
fat_buf          db 512 dup(0)  ; FAT 扇区缓冲
dir_buf          db 512 dup(0)  ; 目录扇区缓冲
path_buf         db 128 dup(0)  ; 路径解析缓冲
exec_cmdline     db 200 dup(0)  ; EXEC 子进程命令行尾部（首字节=长度）
; 文件句柄表：句柄号 -> 文件描述符偏移（0xFFFF = 空闲）
handles          dw NUM_HANDLES dup(0FFFFh)
; 文件描述符数组
fd_table         db NUM_HANDLES*FD_LEN dup(0)
; 系统级"文件"句柄 0/1/2 不在 fd 表里，由句柄特殊处理

; ----------------------------------------------------------------------------
;  内核入口
; ----------------------------------------------------------------------------
kentry:
        mov [boot_drive], dl    ; 保存引导驱动器号

        ; 初始化中断向量表
        call setup_ivt
        ; 恢复 ES 为内核数据段（setup_ivt 写 IVT 时曾将 ES 置 0）
        mov ax, KERNEL_SEG
        mov es, ax
        ; 从磁盘读取引导扇区 BPB
        call load_bpb
        ; 初始化内存管理（建立 MCB 链）
        call init_memory
        ; 设置当前目录为根目录
        call reset_curdir
        ; 建立内核 PSP 并作为父 PSP
        call setup_sys_psp
        ; 显示版本横幅
        call print_banner
        ; 加载并执行命令解释器 LPYCMD.COM
        jmp reshell

; ----------------------------------------------------------------------------
;  setup_ivt：建立关键中断向量
;  入口：无，出口：无
; ----------------------------------------------------------------------------
setup_ivt:
        cli
        xor ax, ax
        mov es, ax              ; ES = 0（IVT 所在段）
        ; INT 20h：程序终止
        mov ax, int20_handler
        mov [es:20h*4], ax
        mov ax, cs
        mov [es:20h*4+2], ax
        ; INT 21h：系统调用分发
        mov ax, int21_handler
        mov [es:21h*4], ax
        mov ax, cs
        mov [es:21h*4+2], ax
        ; INT 22h：终止地址（初始指向 reshell 恢复点）
        mov ax, reshell
        mov [es:22h*4], ax
        mov ax, cs
        mov [es:22h*4+2], ax
        ; INT 23h：Ctrl-C（默认忽略，直接返回）
        mov ax, int23_handler
        mov [es:23h*4], ax
        mov ax, cs
        mov [es:23h*4+2], ax
        ; INT 24h：严重错误（默认忽略）
        mov ax, int24_handler
        mov [es:24h*4], ax
        mov ax, cs
        mov [es:24h*4+2], ax
        ; INT 25h：绝对磁盘读（供 FAT 使用）
        mov ax, int25_handler
        mov [es:25h*4], ax
        mov ax, cs
        mov [es:25h*4+2], ax
        ; INT 26h：绝对磁盘写
        mov ax, int26_handler
        mov [es:26h*4], ax
        mov ax, cs
        mov [es:26h*4+2], ax
        ; INT 28h：DOS 空闲（直接返回）
        mov ax, int28_handler
        mov [es:28h*4], ax
        mov ax, cs
        mov [es:28h*4+2], ax
        sti
        ret

; ----------------------------------------------------------------------------
;  load_bpb：从引导扇区读取 BPB 并计算派生值
;  入口：无，出口：无
; ----------------------------------------------------------------------------
load_bpb:
        ; BPB 由 stage2 LOADR.SYS 复制到 0x0000:0x0510（前 64B VBR）。
        ; 直接从该副本读取，不再回读 LBA 0（硬盘上 LBA 0 是 MBR，无 FAT BPB）。
        push es
        xor ax, ax
        mov es, ax
        mov si, 0x0510 + 11     ; BPB 字段起点（跳过跳转与 OEM 名）
        mov di, bpb_byts_per_sec
        mov ax, [es:si+0]       ; 每扇区字节数
        mov [di], ax
        mov al, [es:si+2]       ; 每簇扇区数
        xor ah, ah
        mov [bpb_sec_per_clus], ax
        mov ax, [es:si+3]       ; 保留扇区数
        mov [bpb_rsvd_sec_cnt], ax
        mov al, [es:si+5]       ; FAT 份数
        xor ah, ah
        mov [bpb_num_fats], ax
        mov ax, [es:si+6]       ; 根目录项数
        mov [bpb_root_ent_cnt], ax
        mov ax, [es:si+11]      ; 每 FAT 扇区数（偏移 +11 相对 BPB 起）
        mov [bpb_fat_sz16], ax
        mov ax, [es:si+13]      ; 每磁道扇区数
        mov [bpb_sec_per_trk], ax
        mov ax, [es:si+15]      ; 磁头数
        mov [bpb_num_heads], ax
        pop es
        ; 分区起始 LBA（CT 块 0:0x0502，软盘为 0）
        push es
        xor ax, ax
        mov es, ax
        mov ax, [es:0x0502]
        mov [partition_base], ax
        pop es
        mov ax, [bpb_rsvd_sec_cnt]
        mov [fat_start], ax
        mov ax, [bpb_num_fats]
        mov cx, [bpb_fat_sz16]
        mul cx
        add ax, [bpb_rsvd_sec_cnt]
        mov [root_dir_start], ax
        mov ax, [bpb_root_ent_cnt]
        mov cx, 32
        mul cx
        add ax, [bpb_byts_per_sec]
        dec ax
        mov cx, [bpb_byts_per_sec]
        xor dx, dx
        div cx
        mov [root_dir_sects], ax
        mov ax, [root_dir_start]
        add ax, [root_dir_sects]
        mov [data_start], ax
        ret

; ----------------------------------------------------------------------------
;  reset_curdir：把当前目录重置为根目录
;  入口：无，出口：无
; ----------------------------------------------------------------------------
reset_curdir:
        mov byte [current_dir], '\'
        mov byte [current_dir+1], 0
        mov word [cur_dir_first], 0     ; 0 = 根目录
        ret

; ============================================================================
;  包含子模块
; ============================================================================
include 'syscall\int21.asm'   ; INT 21h 分发与系统服务
include 'io\disk.asm'         ; 磁盘底层驱动
include 'fs\fat.asm'          ; FAT12/16 文件系统
include 'mem\memory.asm'     ; MCB 内存管理与 EXEC
include 'gfx\gfx.asm'         ; VGA 图形服务（INT 21h AH=70..7A）
; 386 保护模式扩展（GDT/A20/C 运行时）独立编译为 EXT32.BIN，
; 不进入 16 位实模式内核镜像，以保证内核本体只用 8086 指令。

; ============================================================================
;  reshell：重新加载并执行命令解释器
;  这是 INT 22h 的默认目标，程序终止后回到这里
;  入口：无，出口：无（不返回）
; ============================================================================
reshell:
        ; 复用 INT 22h 指向自己：程序终止返回这里
        xor ax, ax
        mov es, ax
        mov ax, reshell
        mov [es:22h*4], ax
        mov ax, cs
        mov [es:22h*4+2], ax
        ; 打开 LPYCMD.COM 并执行
        mov si, shell_name
        mov ax, KERNEL_SEG
        mov ds, ax
        call exec_com           ; 加载并运行，直到退出返回
        jmp reshell             ; 循环重新加载

shell_name      db 'A:\LPYCMD.COM', 0

; ----------------------------------------------------------------------------
;  print_banner：显示彩色 ASCII LOGO 与版本横幅
;  入口：无，出口：无
; ----------------------------------------------------------------------------
print_banner:
        call print_logo         ; 输出彩色 ASCII "LPY-DOS" LOGO
        ; 把光标定位到 LOGO 之后的空行
        mov ax, 0200h
        xor bh, bh
        mov dh, [logo_rows]
        xor dl, dl
        int 10h
        mov si, msg_banner
        call print_str
        ret

; ----------------------------------------------------------------------------
;  print_logo：用 BIOS 绘制多行 ASCII LOGO（字符+属性，行 0 起）
;  每行以 '$' 结尾，数据整体以 0 结尾；颜色取 logo_attr
; ----------------------------------------------------------------------------
print_logo:
        push ax bx cx dx si
        mov byte [logo_rows], 0
        mov byte [logo_col], 0
        mov si, logo
.loop:
        mov al, [si]
        test al, al
        jz .done
        cmp al, '$'
        je .nl
        push si
        mov ah, 02h
        mov bh, 0
        mov dh, [logo_rows]
        mov dl, [logo_col]
        int 10h                  ; 定位光标
        mov ah, 09h
        mov al, [si]
        mov bl, [logo_attr]
        mov cx, 1
        int 10h                  ; 写字符+属性
        pop si
        inc byte [logo_col]
        inc si
        jmp .loop
.nl:
        inc byte [logo_rows]
        mov byte [logo_col], 0
        inc si
        jmp .loop
.done:
        pop si dx cx bx ax
        ret

logo    db 'L     PPPPP Y   Y ----- DDDDD  OOO   SSS ', '$'
        db 'L     P   P  Y Y  ----- D   D O   O S     ', '$'
        db 'L     PPPPP   Y   ----- D   D O   O  SSS  ', '$'
        db 'L     P       Y   ----- D   D O   O     S ', '$'
        db 'LLLLL P      Y   ----- DDDDD  OOO   SSS ', 0
logo_attr       db 0Ah           ; 前景亮绿
logo_rows       db 0
logo_col        db 0

msg_banner      db 0Dh,0Ah
                db 'LPY-DOS Version ', '0'+VER_MAJOR, '.', '0'+VER_MINOR, '.', '0'+VER_PATCH, 0Dh,0Ah
                db 'Copyright (C) 2026 Nexsteaduser', 0Dh,0Ah
                db 'This is free software under the GNU GPL v3 or later.', 0Dh,0Ah,0Dh,0Ah,0

; ============================================================================
;  内核代码末尾标记（内存管理据此建立 MCB 链）
; ============================================================================
end_of_kernel:

; ----------------------------------------------------------------------------
;  尾部数据（放末尾减少前面代码长度，但这里无额外数据）
; ----------------------------------------------------------------------------