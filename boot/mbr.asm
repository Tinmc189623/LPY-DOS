; ============================================================================
;  boot/mbr.asm — LPY-DOS 自有 MBR（512 字节：代码 + 4×16 分区表 + 0xAA55）
;  BIOS 载入 0:0x7C00 → 自举复制到 0:0x0600 → 扫描活动分区 → 读其 VBR 到
;  0:0x7C00 → 写引导上下文块 → 跳 VBR（DL 保持）
;  VBR 读取：INT 13h 扩展读优先；无扩展回退 AH=08h 几何 + LBA-assist CHS
;
;  Copyright (C) 2026 Nexsteaduser
;  This program is free software: you can redistribute it under the terms of
;  the GNU General Public License as published by the Free Software Foundation,
;  either version 3 of the License, or (at your option) any later version.
; ============================================================================

use16
org 0x0600

include 'boot.inc'

        jmp short mbr_start
        nop
mbr_start:
        xor ax, ax
        mov ds, ax
        mov es, ax
        cli
        mov ss, ax
        mov sp, VBR_LIN
        sti
        ; 自举：复制 512B 到 0x0600（DL 由 rep movsw 保留，复制后再存）
        mov si, VBR_LIN
        mov di, 0x0600
        mov cx, 256
        cld
        rep movsw
        jmp 0:mbr_main               ; 跳到 0x0600 处副本（org 0x0600 绝对地址）

mbr_main:
        mov [boot_drive], dl         ; DL 自 BIOS 传入，复制未破坏
        mov byte [mbr_ext], 1
        mov dl, [boot_drive]
        DAP_PROBE mbr_nox            ; 失败先降级标志再跳
        jmp mbr_govbr

mbr_nox:
        mov byte [mbr_ext], 0
        ; 回退路径取几何：AH=08h
        mov dl, [boot_drive]
        mov ah, 0x08
        int 0x13
        jc mbr_err                   ; AH 保留 08h 的错误码
        and cx, 0x3F                 ; 每磁道扇区数
        mov [mbr_spt], cx
        mov al, dh                   ; 最大磁头号
        xor ah, ah
        inc ax                       ; 磁头数
        mov [mbr_heads], ax

mbr_govbr:
        ; ---- 扫描活动分区（4 项循环） ----
        push di
        mov di, part_table
        mov cx, 4
.scan:
        cmp byte [di + partT.flag], 0x80
        je .active
        add di, 16
        dec cx
        jnz .scan
        pop di
        jmp mbr_noact
.active:
        mov eax, dword [di + partT.lba]
        mov [act_lba], eax
        pop di
        call mbr_read                ; VBR → 0:0x7C00
        cmp word [VBR_LIN + 510], 0xAA55
        jne mbr_nosig
        ; ---- 写引导上下文块 ----
        mov si, CTX_LIN
        mov word [si], CTX_MAGIC
        mov eax, [act_lba]
        mov [si+2], eax
        mov byte [si+6], 0           ; FAT 类型由 VBR（stage1）填
        mov al, [boot_drive]
        mov [si+7], al
        ; ---- 跳 VBR，DL 保持 ----
        mov dl, [boot_drive]
        jmp 0:VBR_LIN

; ---------------- VBR 读取分发 ----------------
mbr_read:
        cmp byte [mbr_ext], 0
        je .chs
        mov eax, [act_lba]
        mov cx, 1
        mov bx, VBR_LIN
        call mbr_dapread
        ret
.chs:
        call mbr_chsread
        ret

DAP_READ mbr_dapread, 4, mbr_err

mbr_chsread:
        push ax
        push bx
        push cx
        push dx
        mov eax, [act_lba]
        call mbr_la                  ; → CH=柱面低8, CL=扇区|高2, DH=磁头
        mov dl, [boot_drive]
        mov al, 1
        mov ah, 0x02
        mov bx, VBR_LIN
        int 0x13
        jc mbr_err                   ; 失败直接终态（停机无需恢复栈）
        pop dx
        pop cx
        pop bx
        pop ax
        ret

LBA_ASSIST mbr_la, [mbr_spt], [mbr_heads]

; ---------------- 终态错误路径 ----------------
mbr_err:
        DISK_ERR msg_mbrdisk
mbr_noact:
        mov si, msg_noact
        call print_str
        jmp mbr_halt
mbr_nosig:
        mov si, msg_nosig
        call print_str
mbr_halt:
        hlt
        jmp mbr_halt

PRINT_PROCS

; ---------------- 数据 ----------------
boot_drive  db 0
mbr_ext     db 0
mbr_spt     dw 0
mbr_heads   dw 0
act_lba     dd 0
msg_mbrdisk db 'MBR DISK', 0
msg_noact   db 'NO ACTIVE', 13, 10, 0
msg_nosig   db 'BAD VBR', 13, 10, 0

assert $-$$ <= 446
rb 446 - ($-$$)
part_table  db 64 dup (0)        ; 4×PART_ENTRY，由安装器/测试脚本填写
dw 0xAA55
assert $-$$ = 512
