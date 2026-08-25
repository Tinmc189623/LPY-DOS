use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  lcm.com — 求两个数的最小公倍数：LCM = A / GCD * B
; ============================================================================
start:
    mov dx, s_a
    call read_num           ; A
    mov [va], ax
    mov dx, s_b
    call read_num           ; B
    mov [vb], ax
    ; ---- 先求 GCD ----
    mov ax, [va]
    mov bx, [vb]
.gloop:
    test bx, bx
    jz .gcd_done
    xor dx, dx
    div bx
    mov ax, bx
    mov bx, dx
    jmp .gloop
.gcd_done:
    mov [gcdv], ax
    ; ---- LCM = A / GCD * B ----
    mov ax, [va]
    xor dx, dx
    div word [gcdv]         ; AX = A/GCD
    imul word [vb]          ; * B
    puts s_out
    call print_dec16
    call crlf
    int 20h

s_a   db 'Enter A: $'
s_b   db 'Enter B: $'
s_out db 'LCM = $'
va    dw 0
vb    dw 0
gcdv  dw 0

include 'inc/std.asm'