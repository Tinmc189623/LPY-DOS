use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  bits.com — 列出某个整数的每一位及对应权重
; ============================================================================
start:
    mov dx, s_in
    call read_num
    mov [val], ax
    puts s_out
    ; bx = 权重（1 << bit），从 bit0 到 bit15
    mov bx, 1
    mov cx, 16
    xor si, si              ; 当前位号
.loop:
    push cx bx si
    ; 输出 "bit"
    puts s_bit
    ; 位号
    mov ax, si
    call print_dec16
    mov dl, '='
    call putc
    ; 该位值
    mov ax, [val]
    and ax, bx
    test ax, ax
    jz .zero
    mov dl, '1'
    jmp .have
.zero:
    mov dl, '0'
.have:
    call putc
    ; 权重
    puts s_w
    pop si bx ax
    push ax
    mov ax, bx
    call print_dec16
    pop ax
    push bx si
    call crlf
    pop si bx cx
    inc si
    shl bx, 1               ; 权重翻倍
    loop .loop
    int 20h

s_in  db 'Enter number: $'
s_out db 'Bit breakdown:', 0Dh, 0Ah, '$'
s_bit db 'bit$'
s_w   db '  weight=$'
val   dw 0

include 'inc/std.asm'