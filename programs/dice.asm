use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  dice.com — 掷两颗骰子，显示点数与合计
; ============================================================================
start:
    ; 随机种子
    mov ah, 0
    int 1Ah
    mov byte [seed], dl       ; 用系统时间低字节作随机种子
    puts s_msg
    call roll
    mov [d1], ax
    call roll
    mov [d2], ax
    ; 输出：d1 + d2 = sum
    puts s_v1
    mov ax, [d1]
    call print_dec16
    putch ' '
    puts s_v2
    mov ax, [d2]
    call print_dec16
    putch ' '
    puts s_v3
    mov ax, [d1]
    add ax, [d2]
    call print_dec16
    call crlf
    int 20h

; ----------------------------------------------------------------------------
;  roll：产生 1..6 的点数（基于 LFSR 取模）
; ----------------------------------------------------------------------------
roll:
    call lfsr
    xor dx, dx
    mov cx, 6
    div cx                  ; AX % 6 -> DX
    inc dx
    mov ax, dx
    ret

; ----------------------------------------------------------------------------
;  lfsr：Galois LFSR 取随机数，al 返回最低字节
; ----------------------------------------------------------------------------
lfsr:
    push cx dx
    mov ax, [seed]
    mov cx, 8
.l:
    mov dx, ax
    and dx, 1
    shr ax, 1
    test dx, dx
    jz .no
    xor ax, 0B400h
.no:
    loop .l
    mov [seed], ax
    pop dx cx
    ret

s_msg db 'Rolling dice...', 0Dh, 0Ah, '$'
s_v1  db 'Die1 = $'
s_v2  db '  Die2 = $'
s_v3  db '  Sum = $'
d1    dw 0
d2    dw 0
seed  dw 0

include 'inc/std.asm'