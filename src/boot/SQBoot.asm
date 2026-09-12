; ============================================================================
;  LPY-DOS 紧急备选引导
;  此代码并非 AI 编写，此代码为人工编写
;  Name: SQBoot
;  Copyright (C) 2026 Nexsteaduser. All rights reserved.
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
; ============================================================================

include 'boot.inc'

use16
org 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 7C00h
    mov [boot_drive], dl
    sti

    mov si, msg_start
    call print_string

    ; FAT32 的标准备份引导扇区位于卷内 LBA 6。
    mov ax, 2000h
    mov es, ax
    xor bx, bx
    mov si, dap
    mov dl, [boot_drive]
    mov ah, 42h
    int 13h
    jnc check_backup

    ; 老 BIOS 可能不支持 INT 13h 扩展，使用软盘常见几何参数回退。
    mov ax, 2000h
    mov es, ax
    xor bx, bx
    mov ah, 02h
    mov al, 01h
    mov ch, 00h
    mov cl, 07h
    mov dh, 00h
    mov dl, [boot_drive]
    int 13h
    jc backup_failed

check_backup:
    cmp word [es:01FEh], 0AA55h
    jne backup_invalid
    mov dl, [boot_drive]
    jmp 2000h:0000h

backup_failed:
    mov si, msg_read_failed
    call print_string
    jmp halt

backup_invalid:
    mov si, msg_invalid
    call print_string

halt:
    cli
    hlt
    jmp halt

print_string:
    lodsb
    test al, al
    jz .done
    mov ah, 0Eh
    mov bx, 0007h
    int 10h
    jmp print_string
.done:
    ret

boot_drive db 0
msg_start db 'SQBOOT: TRY LBA 6', 13, 10, 0
msg_read_failed db 'BACKUP READ FAILED', 13, 10, 0
msg_invalid db 'NO VALID BACKUP BOOT', 13, 10, 0

; INT 13h AH=42h Disk Address Packet，读取 1 个扇区到 2000:0000。
dap:
    db 10h
    db 00h
    dw 0001h
    dw 0000h
    dw 2000h
    dq 0000000000000006h

times 510 - ($ - $$) db 0
dw 0xAA55