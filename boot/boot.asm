; ============================================================================
;  LPY-DOS 引导扇区 (FAT12 / 1.44MB 软盘)
;  对标 MS-DOS 引导程序：解析根目录、按 FAT12 链加载 LPYOS.SYS 内核
;  内核加载地址：0x1000:0x0000（内核大小须小于 32KB）
;
;  编译：fasm boot.asm boot.bin
;
;  Copyright (C) 2026 Nexlyh
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
; ============================================================================

use16
org 0x7C00

; ----------------------------------------------------------------------------
;  BPB（BIOS Parameter Block），与 MS-DOS 1.44MB 软盘保持一致
; ----------------------------------------------------------------------------
        jmp short boot_start
        nop
bsOemName       db 'LPY-DOS '        ; OEM 名（8 字节）
bpbBytsPerSec   dw 512               ; 每扇区字节数
bpbSecPerClus   db 1                 ; 每簇扇区数
bpbRsvdSecCnt   dw 1                 ; 保留扇区数
bpbNumFATs      db 2                 ; FAT 表份数
bpbRootEntCnt   dw 224               ; 根目录项数
bpbTotSec16     dw 2880              ; 总扇区数
bpbMedia        db 0F0h              ; 介质描述符
bpbFATSz16      dw 9                 ; 每份 FAT 占扇区数
bpbSecPerTrk    dw 18                ; 每磁道扇区数
bpbNumHeads     dw 2                 ; 磁头数
bpbHiddSec      dd 0                 ; 隐藏扇区
bpbTotSec32     dd 0                 ; 32 位总扇区数

; 根目录区起始扇区 = 保留扇区数 + FAT 份数 * 每 FAT 扇区数
ROOT_DIR_START  equ 1 + (2 * 9)
; 根目录占扇区数 = (根目录项数 * 32 + 511) / 512
ROOT_DIR_SECTS  equ (224 * 32 + 511) / 512
; 数据区起始扇区 = 根目录区起始 + 根目录占扇区数
DATA_START      equ ROOT_DIR_START + ROOT_DIR_SECTS

boot_start:
        cli
        xor ax, ax
        mov ss, ax                  ; 栈段 0x0000
        mov sp, 7C00h               ; 栈顶位于引导区之下
        mov ds, ax
        mov es, ax
        sti

        mov [boot_drive], dl        ; 保存 BIOS 传入的驱动器号

        ; ---- 读根目录到 0x0200:0x0000 ----
        mov ax, 2000h
        mov es, ax
        mov ax, ROOT_DIR_START
        mov cx, ROOT_DIR_SECTS
        xor bx, bx
        call read_sectors

        ; ---- 在根目录中查找 "LPYOS    SYS" ----
        xor di, di                  ; 目录项偏移
        mov cx, bpbRootEntCnt       ; 根目录项数
.find_entry:
        push cx
        push di
        mov si, filename            ; 待匹配文件名
        mov cx, 11
        repe cmpsb                  ; 比较 11 字节文件名
        pop di
        pop cx
        je .found
        add di, 32                  ; 定位到下一个目录项
        loop .find_entry
        mov si, msg_no_kernel
        call print
        jmp hang

.found:
        ; 目录项偏移 +0x1A 处为起始簇号
        mov ax, [es:di+1Ah]
        mov [first_cluster], ax

        ; ---- 按 FAT 链加载内核到 0x1000:0x0000 ----
        mov ax, 1000h
        mov es, ax
        xor bx, bx
        mov ax, [first_cluster]
.load_cluster:
        mov si, ax                  ; 保存当前簇号
        ; 数据区扇区号 = DATA_START + (簇号 - 2) * 每簇扇区数（每簇 1 扇区）
        add ax, DATA_START - 2
        mov cx, 1
        call read_sectors           ; 读一簇到 es:bx
        mov ax, si
        call next_cluster           ; 获取下一簇号
        cmp ax, 0FF8h               ; FAT12 结束标记 >= 0xFF8
        jae .done
        add bx, 512                 ; 缓冲区后移一个扇区
        jmp .load_cluster

.done:
        ; ---- 跳转到内核（DS=ES=SS=0x1000, SP=0xFFFE）----
        mov ax, 1000h
        mov ds, ax
        mov es, ax
        cli
        mov ss, ax
        mov sp, 0FFFEh
        sti
        jmp 1000h:0000h

hang:
        jmp hang

; ============================================================================
;  子程序区
; ============================================================================

; ----------------------------------------------------------------------------
;  print：向屏幕输出以 0 结尾的字符串
;  入口：DS:SI = 字符串地址，无出口
; ----------------------------------------------------------------------------
print:
        lodsb
        test al, al
        jz .done
        mov ah, 0Eh                 ; BIOS 电传模式写字符
        xor bx, bx
        int 10h
        jmp print
.done:
        ret

; ----------------------------------------------------------------------------
;  read_sectors：从磁盘读取连续扇区
;  入口：AX = 起始 LBA，CX = 扇区数，ES:BX = 目标缓冲区
;  出口：失败时打印错误信息并挂起
; ----------------------------------------------------------------------------
read_sectors:
        pusha
.loop:
        push ax
        push cx
        push bx

        ; LBA 转 CHS：
        ;   扇区号 = LBA % 每磁道扇区数 + 1
        ;   磁道号 = LBA / (每磁道扇区数 * 磁头数)
        ;   磁头号 = (LBA / 每磁道扇区数) % 磁头数
        ; 注意：BX 必须保留缓冲区偏移，扇区号用内存变量暂存
        xor dx, dx
        mov cx, 18                  ; 每磁道扇区数
        div cx                      ; ax = LBA/18, dx = LBA%18
        inc dx                      ; 扇区号 (1..18)
        mov [sec_num], dl           ; 暂存扇区号
        xor dx, dx
        mov cx, 2                   ; 磁头数
        div cx                      ; ax = 磁道, dx = 磁头
        mov ch, al                  ; 磁道号（1.44MB 下 < 256，仅用低 8 位）
        mov cl, [sec_num]           ; 扇区号
        mov dh, dl                  ; 磁头号
        mov dl, [boot_drive]        ; 驱动器号
        mov al, 1                   ; 读 1 扇区
        mov ah, 02h
        int 13h
        jc .error

        pop bx
        pop cx
        pop ax
        inc ax                      ; 下一个 LBA
        add bx, 512                 ; 缓冲区后移
        loop .loop
        popa
        ret

.error:
        pop bx
        pop cx
        pop ax
        popa
        mov si, msg_disk_error
        call print
        jmp hang

; ----------------------------------------------------------------------------
;  next_cluster：FAT12 中获取下一簇号
;  入口：AX = 当前簇号
;  出口：AX = 下一簇号
;  说明：FAT12 每簇占 1.5 字节，偶数簇取低 12 位，奇数簇取高 12 位
; ----------------------------------------------------------------------------
next_cluster:
        push bx
        push cx
        push dx
        push si
        push di
        push es

        mov bx, ax                  ; bx = 簇号（read_sectors 经 pusha/popa 不会改动）
        mov si, ax
        shr si, 1
        add si, ax                  ; si = 簇号 * 1.5（FAT 内字节偏移）

        mov ax, si
        xor dx, dx
        mov cx, 512
        div cx                      ; ax = 偏移/512, dx = 偏移%512
        push dx                     ; 暂存扇区内偏移
        add ax, 1                   ; FAT 区起始 LBA = 1
        mov cx, 1
        mov di, 0050h               ; 临时 FAT 缓冲区段
        mov es, di
        xor bx, bx
        call read_sectors
        pop di                      ; 恢复扇区内偏移
        mov ax, [es:di]             ; 读取 16 位 FAT 项
        test bx, 1                  ; 判断簇号奇偶
        jnz .odd
        and ax, 0FFFh               ; 偶数簇：取低 12 位
        jmp .done
.odd:
        shr ax, 4                   ; 奇数簇：取高 12 位
.done:
        pop es
        pop di
        pop si
        pop dx
        pop cx
        pop bx
        ret

; ----------------------------------------------------------------------------
;  数据区
; ----------------------------------------------------------------------------
boot_drive      db 0                ; 启动驱动器号
first_cluster   dw 0                ; 内核起始簇号
sec_num         db 0                ; CHS 转换临时扇区号
filename        db 'LPYOS   SYS'   ; 内核文件名（11 字节，8.3 格式）
msg_no_kernel   db 0Dh,0Ah,'LPY-DOS: kernel LPYOS.SYS not found.',0Dh,0Ah,0
msg_disk_error  db 0Dh,0Ah,'LPY-DOS: disk read error.',0Dh,0Ah,0

; 填充至 510 字节并以 0x55AA 结尾
times 510-($-$$) db 0
dw 0AA55h
