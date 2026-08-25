use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  diag.com — 从左上到右下的斜线扫描
; ============================================================================
start:
    mov bx, 0
.loop:
    cmp bx, 24
    jg .done
    mov dh, bl
    mov dl, bl
    call setcurs
    putch '*'
    inc bx
    jmp .loop
.done:
    mov dh, 25
    mov dl, 0
    call setcurs
    puts s_msg
    int 20h

s_msg db 'Diagonal drawn.$'

include 'inc/std.asm'