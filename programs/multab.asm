use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  multab.com — 打印 9x9 乘法表（上三角）
; ============================================================================
start:
    puts s_head
    mov bh, 1               ; 行（被乘数）
.rows:
    cmp bh, 9
    ja .done
    mov bl, 1               ; 列（乘数）
.cols:
    cmp bl, bh
    ja .row_end
    mov al, bh
    imul bl                 ; AX = 行*列
    push ax bx
    call print_dec16
    putch ' '
    pop bx ax
    inc bl
    jmp .cols
.row_end:
    call crlf
    inc bh
    jmp .rows
.done:
    int 20h

s_head db 'Multiplication table:', 0Dh, 0Ah, '$'

include 'inc/std.asm'