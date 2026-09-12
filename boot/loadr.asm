; ============================================================================
;  boot/loadr.asm — LPY-DOS stage2 加载器（LOADR.SYS，≤8KB）
;  stage1 加载至 0x2000:0000；运行时识别 FAT12/16/32，按扩展块目标名加载
;  系统文件到 0x1000:0000 并移交。映像内 DS=ES=SS=0x2000；移交前把 BPB
;  副本复制到 0x0000:0x0510
;
;  Copyright (C) 2026 Nexsteaduser
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
; ============================================================================

use16
org 0

include 'boot.inc'

start:
        cli
        mov ax, STAGE2_SEG
        mov ds, ax
        mov es, ax
        mov ss, ax
        mov sp, 0xFFF0
        sti

        ; ---- 段 0 窗口：复制 CTX 16B、BPB 64B 进映像 ----
        push ds
        xor ax, ax
        mov ds, ax
        mov si, CTX_LIN
        mov di, ctx_copy
        mov cx, 8
        cld
        rep movsw
        mov si, VBR_LIN
        mov di, bpb_copy
        mov cx, 32
        rep movsw
        pop ds                       ; DS=0x2000

        cmp word [ctx_copy], CTX_MAGIC
        jne s2_noctx
        mov eax, dword [ctx_copy + 2]
        mov [part_lba], eax
        mov al, byte [ctx_copy + 7]
        mov [boot_drive], al

        ; ---- FAT 类型识别 ----
        cmp word [bpb_copy + bpbT.fatSz16], 0
        je .is32
        mov ax, word [bpb_copy + bpbT.totSec16]
        test ax, ax
        jnz .tot_ok
        mov ax, word [bpb_copy + bpbT.totSec32]   ; FAT12/16 卷 < 65536 扇区（低字）
.tot_ok:
        mov [tot_tmp], ax
        mov cx, word [bpb_copy + bpbT.rootEntCnt]
        shl cx, 5
        add cx, 511
        shr cx, 9                    ; 根目录扇区数
        movzx ax, byte [bpb_copy + bpbT.numFATs]
        mov dx, word [bpb_copy + bpbT.fatSz16]
        mul dx
        add cx, ax                   ; + FAT 区
        mov ax, [tot_tmp]
        sub ax, cx                   ; 数据区扇区数
        xor dx, dx
        movzx bx, byte [bpb_copy + bpbT.secPerClus]
        div bx                       ; AX=簇数
        cmp ax, 4085                 ; 微软阈值：<4085 → FAT12
        jae .is16
        mov byte [fat_type], FAT12
        jmp .det_done
.is16:
        mov byte [fat_type], FAT16
        jmp .det_done
.is32:
        mov byte [fat_type], FAT32
.det_done:

        ; ---- 硬盘 → INT 13h 扩展检测 ----
        cmp byte [boot_drive], 0x80
        jb .floppy
        mov byte [is_hd], 1
        mov dl, [boot_drive]
        DAP_PROBE s2_noext
.floppy:

        ; ---- 按识别结果实例化加载（运行时分发，call 各子例程） ----
        mov ax, TARGET_SEG
        mov es, ax
        xor bx, bx
        cmp byte [fat_type], FAT12
        jne .try16
        call s2_load12
        jmp .loaded
.try16:
        cmp byte [fat_type], FAT16
        jne .last
        call s2_load16
        jmp .loaded
.last:
        call s2_load32
.loaded:

        ; ---- BPB 副本 → 0x0000:0x0510 ----
        push ds
        push es
        xor ax, ax
        mov es, ax
        mov si, bpb_copy
        mov di, BPB_COPY_LIN
        mov cx, 32
        rep movsw
        pop es
        pop ds

        ; ---- 移交（kentry 契约：DL=盘号；段/栈同 v1） ----
        mov dl, [boot_drive]
        mov ax, TARGET_SEG
        mov ds, ax
        mov es, ax
        mov ss, ax
        mov sp, 0xFFFE
        mov si, BPB_COPY_LIN         ; BPB 副本偏移（段约定由子项目 4 定义）
        jmp TARGET_SEG:0

; ---------------- 读扇区分发（AX/EAX=卷内 LBA, CX=数, ES:BX=缓冲） ----------------
s2_read:
        cmp byte [is_hd], 0
        je .chs
        cmp byte [fat_type], FAT32
        je .hd
        movzx eax, ax                ; 12/16 卷内 LBA 零扩展
.hd:
        add eax, [part_lba]          ; 绝对 LBA = 分区起始 + 卷内
        call s2_dap
        ret
.chs:
        call s2_chs
        ret

; ---------------- 取簇分发（12/16: AX；32: EAX；0=链尾） ----------------
s2_fatdisp:
        cmp byte [fat_type], FAT12
        jne @f
        call s2_next12
        ret
@@:     cmp byte [fat_type], FAT16
        jne @f
        call s2_next16
        ret
@@:     call s2_next32
        ret

; ---------------- 各变体文件加载子例程（READ_FILE 宏展开，ret 返回 .loaded） ----------------
READ_FILE s2_load12, FAT12, bpb_copy, ROOTBUF_SEG, ROOTBUF_SEG, ROOTBUF_FATOFF, target_name, s2_read, s2_fatdisp, s2_err_disk, s2_notarget, TARGET_SEG
READ_FILE s2_load16, FAT16, bpb_copy, ROOTBUF_SEG, ROOTBUF_SEG, ROOTBUF_FATOFF, target_name, s2_read, s2_fatdisp, s2_err_disk, s2_notarget, TARGET_SEG
READ_FILE s2_load32, FAT32, bpb_copy, ROOTBUF_SEG, ROOTBUF_SEG, ROOTBUF_FATOFF, target_name, s2_read, s2_fatdisp, s2_err_disk, s2_notarget, TARGET_SEG

; ---------------- 例程实例化 ----------------
CHS_READ s2_chs, [boot_drive], [bpb_copy+bpbT.secPerTrk], [bpb_copy+bpbT.numHeads], 4, s2_err_disk
DAP_READ s2_dap, 4, s2_err_disk
FAT_NEXT s2_next12, FAT12, bpb_copy, ROOTBUF_SEG, ROOTBUF_FATOFF, s2_read, s2_err_disk
FAT_NEXT s2_next16, FAT16, bpb_copy, ROOTBUF_SEG, ROOTBUF_FATOFF, s2_read, s2_err_disk
FAT_NEXT s2_next32, FAT32, bpb_copy, ROOTBUF_SEG, ROOTBUF_FATOFF, s2_read, s2_err_disk

PRINT_PROCS

; ---------------- 终态错误路径 ----------------
s2_err_disk:
        DISK_ERR msg_s2disk
s2_notarget:
        mov si, msg_notarget
        call print_str
.halt:
        hlt
        jmp .halt
s2_noctx:
        mov si, msg_noctx
        call print_str
.halt:
        hlt
        jmp .halt
s2_noext:
        mov si, msg_noext
        call print_str
.halt:
        hlt
        jmp .halt

; ---------------- 数据 ----------------
ctx_copy    dw 8 dup (0)         ; 引导上下文块副本
bpb_copy    db 64 dup (0)
target_name db 'LPYOS   SYS'     ; stage2 要加载到 0x1000 的内核名
boot_drive  db 0
is_hd       db 0
fat_type    db 0
part_lba    dd 0
tot_tmp     dw 0
msg_s2disk   db 'S2 DISK', 0
msg_notarget db 'NO TARGET', 13, 10, 0
msg_noctx    db 'NO CTX', 13, 10, 0
msg_noext    db 'NO INT13EXT', 13, 10, 0

assert $ <= STAGE2_MAX
