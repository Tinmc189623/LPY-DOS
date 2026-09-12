; ============================================================================
;  boot/boot.asm — LPY-DOS stage1 引导扇区主体（2.0 两阶段引导）
;  本文件不直接编译；由 boot12.asm / boot16.asm / boot32.asm 包装编译：
;    包装定义 BPB_* 几何常量、FATBITS（1/2/3）、TARGET_NAME（equ 字符串）
;  职责：保存 DL → 写引导上下文块 → 按扩展块目标名加载 LOADR.SYS 到
;        0x2000:0000 → 跳转（DL 保持）
;
;  Copyright (C) 2026 Nexsteaduser
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
; ============================================================================

use16
org 0x7C00

include 'boot.inc'

if ~ defined FATBITS
        display 'boot.asm: FATBITS 未定义（须由 boot12/16/32.asm 包装编译）'
        err 'FATBITS undefined'
end if
if ~ defined TARGET_NAME
        display 'boot.asm: TARGET_NAME 未定义'
        err 'TARGET_NAME undefined'
end if

; ---------------- BPB（值来自包装常量） ----------------
        jmp short boot_start
        nop
        db 'LPY-DOS '
        dw BPB_BYTS_PER_SEC
        db BPB_SEC_PER_CLUS
        dw BPB_RSVD
        db BPB_NUM_FATS
        dw BPB_ROOT_ENT
        dw BPB_TOT16
        db BPB_MEDIA
        dw BPB_FATSZ16
        dw BPB_SPT
        dw BPB_HEADS
        dd BPB_HIDD
        dd BPB_TOT32
if FATBITS = FAT32
        dd BPB_FATSZ32        ; fatSz32 @36
        dw 0                  ; extFlags
        dw 0                  ; fsVer
        dd BPB_ROOTCLUS       ; rootClus @44
        dw 1                  ; fsInfo
        dw 6                  ; bkBootSec
        db 12 dup (0)         ; rsvd32
else
        db 28 dup (0)         ; FAT12/16 不使用 36..63
end if

; ---------------- 扩展块 @0x40 ----------------
; ext_target = TARGET_NAME（stage1 据此搜索并加载到 0x2000）。stage2 LOADR.SYS
;  不读此处——其内核目标名在自身映像内固定为 LPYOS.SYS（见 loadr.asm）。
ext_target      db TARGET_NAME
ext_media       db 0
ext_magic       dw EXT_MAGIC
assert $-$$ = 0x4E               ; 头部区止于 0x4E，代码区自此到 0x1FD

boot_start:
        cli
        xor ax, ax
        mov ss, ax
        mov sp, VBR_LIN
        mov ds, ax
        mov es, ax
        sti
        mov [boot_drive], dl

        ; ---- 引导上下文块：无 MBR 自建；有 MBR 保留其写入的分区 LBA ----
        mov si, CTX_LIN
        cmp word [si], CTX_MAGIC
        je .ctx_kept
        mov word [si], CTX_MAGIC    ; LBA 字段留作 BDA 零（软盘）/ MBR 已写（硬盘）
.ctx_kept:
        mov byte [si+6], FATBITS
        mov [si+7], dl              ; DL 仍为 BIOS 传入的盘号

if FATBITS = FAT32
        ; DAP 扩展检测省略：无扩展时 ah=42 失败即跳 s1_err_disk（测试目标 QEMU 恒有扩展）
end if

        ; ---- 加载 LOADR.SYS → STAGE2_SEG:0 ----
        mov ax, STAGE2_SEG
        mov es, ax
        xor bx, bx
        call s1_load
        jmp STAGE2_SEG:0
READ_FILE s1_load, FATBITS, VBR_LIN, ROOTBUF_SEG, ROOTBUF_SEG, ROOTBUF_FATOFF, ext_target, s1_read, s1_next, s1_err_disk, s1_noloader, STAGE2_SEG

; ---------------- 终态错误路径 ----------------
s1_noloader:
        mov si, msg_noloader
        jmp s1_err_common
s1_err_disk:
        mov si, msg_s1disk
s1_err_common:
        call print_str
        jmp s1_hang

; ---------------- 读扇区：先加分区起始 LBA，再按变体实例化 ----------------
; READ_FILE / FAT_NEXT 给出的是卷内 LBA；MBR 分区引导时 CTX 块 +2 存分区起始
if FATBITS = FAT32
s1_read:
        add eax, [CTX_LIN+2]        ; 卷内 LBA + 分区起始（32 位）；落入 s1_dap
        DAP_READ s1_dap, 4, s1_err_disk
        FAT_NEXT s1_next, FAT32, VBR_LIN, ROOTBUF_SEG, ROOTBUF_FATOFF, s1_read, s1_err_disk
else
s1_read:
        add ax, [CTX_LIN+2]         ; + 分区起始低 16 位（软盘为 0）
        jc s1_overrange
        jmp s1_chs
s1_overrange:                       ; 绝对 LBA 超 16 位：FAT12/16 卷 >64K 扇区不支持
        mov si, msg_overrange
        call print_str
        jmp s1_hang
        CHS_READ s1_chs, [boot_drive], [VBR_LIN+bpbT.secPerTrk], [VBR_LIN+bpbT.numHeads], 4, s1_err_disk
        FAT_NEXT s1_next, FATBITS, VBR_LIN, ROOTBUF_SEG, ROOTBUF_FATOFF, s1_read, s1_err_disk
end if

PRINT_PROCS
s1_hang:
        hlt
        jmp s1_hang

; ---------------- 数据 ----------------
boot_drive      db 0
msg_s1disk      db 'E', 0
msg_noloader    db 'LD', 0
if FATBITS <> FAT32
msg_overrange   db 'OV', 0
end if

assert $-$$ <= 510
times 510-($-$$) db 0
dw 0xAA55
