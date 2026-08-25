use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  gcd.com — 求两个数的最大公约数（辗转相除法）
; ============================================================================
start:
    mov dx, s_a
    call read_num           ; A
    mov [va], ax
    mov dx, s_b
    call read_num           ; B
    mov [vb], ax
    ; 辗转相除
    mov ax, [va]
    mov bx, [vb]
.loop:
    test bx, bx
    jz .done
    xor dx, dx
    div bx                  ; AX / B -> 余数 DX
    mov ax, bx
    mov bx, dx
    jmp .loop
.done:
    puts s_out
    call print_dec16
    call crlf
    int 20h

s_a   db 'Enter A: $'
s_b   db 'Enter B: $'
s_out db 'GCD = $'
va    dw 0
vb    dw 0

include 'inc/std.asm'