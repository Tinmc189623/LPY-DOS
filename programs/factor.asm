use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  factor.com — 分解质因数：输入整数 N，输出其质因子分解
; ============================================================================
start:
    mov dx, s_in
    call read_num           ; N -> AX
    test ax, ax
    jz .zero
    mov bx, ax
    mov si, 2               ; 试除因子，从 2 起
    puts s_out
.loop:
    ; 直到商为 1
    cmp bx, 1
    jbe .done
    mov ax, bx
    xor dx, dx
    div si                  ; AX = 商, DX = 余
    test dx, dx
    jnz .next_div
    ; SI 是因子：打印，继续用同一因子除
    push ax bx dx si
    mov ax, si
    call print_dec16
    putch ' '
    pop si dx bx ax
    mov bx, ax              ; 商继续
    jmp .loop
.next_div:
    inc si
    jmp .loop
.zero:
    puts s_zero
.done:
    call crlf
    int 20h

s_in   db 'Enter N: $'
s_out  db 'Prime factors: $'
s_zero db '0 has no factors.', 0Dh, 0Ah, '$'

include 'inc/std.asm'