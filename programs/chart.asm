use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  chart.com — 打印可打印 ASCII 字符表（32..126，每 16 个换行）
; ============================================================================
start:
    puts s_head
    mov si, 32
.loop:
    cmp si, 127
    jae .done
    ; 输出字符
    mov ax, si
    mov dl, al
    mov ah, 02h
    int 21h
    mov dl, ' '
    mov ah, 02h
    int 21h
    inc si
    ; 每 16 个换行
    mov ax, si
    and ax, 15
    jnz .loop
    call crlf
    jmp .loop
.done:
    call crlf
    int 20h

s_head db 'ASCII printable:', 0Dh, 0Ah, '$'

include 'inc/std.asm'