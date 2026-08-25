use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  ascii.com — 打印 ASCII 完整表（0x00..0x7F），含十六进制码与可打印字符
; ============================================================================
start:
    puts s_head
    mov bx, 0
.loop:
    cmp bx, 128
    jae .done
    mov ax, bx
    call print_hex8         ; 十六进制码
    putch ':'
    putch ' '
    ; 可打印字符
    mov al, bl
    cmp al, 20h
    jb .dot
    cmp al, 7Fh
    jae .dot
    mov dl, al
    jmp .putc
.dot:
    mov dl, '.'
.putc:
    mov ah, 02h
    int 21h
    ; 每 8 个换行
    mov ax, bx
    inc ax
    and ax, 7
    jnz .next
    call crlf
    jmp .next
.next:
    inc bx
    jmp .loop
.done:
    call crlf
    int 20h

s_head db 'ASCII 0x00..0x7F:', 0Dh, 0Ah, '$'

include 'inc/std.asm'