; ============================================================================
;  LPY-DOS 内核主文件 LPYOS.SYS
;  对标 MS-DOS 的 IO.SYS / MSDOS.SYS 角色：实模式内核
;  加载地址：0x1000:0x0000（引导扇区加载），CS=DS=ES=SS=0x1000, SP=0xFFFE
;  提供 INT 20h/21h 系统调用、FAT12/16 文件系统、MCB 内存管理与 EXEC
;
;  编译：fasm kernel.asm LPYOS.SYS（结合其他模块）
;
;  Copyright (C) 2026 Nexlyh
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
;  头部信息区
; ----------------------------------------------------------------------------
kern_signature  db 'LPY-DOS kernel (LPYOS.SYS) v1.0.0', 0
kern_version    db 1,0,0        ; 主/次/修订

; ----------------------------------------------------------------------------
;  系统变量区
; ----------------------------------------------------------------------------
boot_drive      db 0            ; 引导驱动器号（0=A）
current_drive   db 0            ; 当前默认驱动器
current_dir     db 64 dup(0)    ; 当前目录串（如 '\SUB\DIR'，不含盘符）
cur_dir_first   dw 0            ; 当前目录第一个簇（0=根目录）
current_psp      dw 0            ; 当前 PSP 段
caller_ds        dw 0            ; INT 21h 调用者 DS（参数段）
caller_es        dw 0            ; INT 21h 调用者 ES
term_request     db 0            ; 程序终止请求标志
term_code        db 0            ; 退出码（AH=4C）
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
        mov ax, 0               ; LBA 0 = 引导扇区
        mov cx, 1
        mov bx, dir_buf         ; 复用 dir_buf 作为临时扇区缓冲
        call read_sector_lba    ; 读入 dir_buf
        ; 从引导扇区拷贝 BPB 字段
        mov si, dir_buf+11      ; 引导扇区 BPB 起始（跳过跳转与 OEM 名）
        mov di, bpb_byts_per_sec
        mov ax, [si+0]          ; 每扇区字节数
        mov [di], ax
        mov al, [si+2]          ; 每簇扇区数
        xor ah, ah
        mov [bpb_sec_per_clus], ax
        mov ax, [si+3]          ; 保留扇区数
        mov [bpb_rsvd_sec_cnt], ax
        mov al, [si+5]          ; FAT 份数
        xor ah, ah
        mov [bpb_num_fats], ax
        mov ax, [si+6]          ; 根目录项数
        mov [bpb_root_ent_cnt], ax
        mov ax, [si+11]         ; 每 FAT 扇区数（偏移 +11 相对 BPB 起）
        mov [bpb_fat_sz16], ax
        mov ax, [si+13]         ; 每磁道扇区数
        mov [bpb_sec_per_trk], ax
        mov ax, [si+15]         ; 磁头数
        mov [bpb_num_heads], ax
        ; 计算派生值
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
include 'api.asm'       ; INT 21h 分发与系统服务
include 'disk.asm'      ; 磁盘底层驱动
include 'fat.asm'       ; FAT12/16 文件系统
include 'memory.asm'    ; MCB 内存管理与 EXEC

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
;  print_banner：显示版本横幅
;  入口：无，出口：无
; ----------------------------------------------------------------------------
print_banner:
        mov si, msg_banner
        call print_str
        ret

msg_banner      db 0Dh,0Ah
                db 'LPY-DOS Version 1.0.0', 0Dh,0Ah
                db 'Copyright (C) 2026 Nexlyh', 0Dh,0Ah
                db 'This is free software under the GNU GPL v3 or later.', 0Dh,0Ah,0Dh,0Ah,0

; ============================================================================
;  内核代码末尾标记（内存管理据此建立 MCB 链）
; ============================================================================
end_of_kernel:

; ----------------------------------------------------------------------------
;  尾部数据（放末尾减少前面代码长度，但这里无额外数据）
; ----------------------------------------------------------------------------
