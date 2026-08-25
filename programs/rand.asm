use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  rand.com — 基于 16 位 Galois LFSR 的伪随机数生成器，输出 N 个
; ============================================================================
start:
    mov dx, s_in
    call read_num           ; 个数 -> AX
    mov [count], ax
    ; 以时钟低字节填充种子
    mov ah, 0
    int 1Ah
    mov byte [seed], dl
    test word [count], 0
    jz .done
    puts s_out
    mov cx, [count]
.loop:
    push cx
    call lfsr               ; AX = 伪随机数
    call print_dec16
    putch ' '
    pop cx
    loop .loop
.done:
    call crlf
    int 20h

; ----------------------------------------------------------------------------
;  lfsr：Galois LFSR，每调用产生一个新 16 位随机数（存回 [seed]）
; ----------------------------------------------------------------------------
lfsr:
    push cx dx
    mov ax, [seed]
    mov cx, 8
.l:
    mov dx, ax
    and dx, 1               ; 取最低位
    shr ax, 1
    test dx, dx
    jz .no
    xor ax, 0B400h          ; 反馈多项式
.no:
    loop .l
    mov [seed], ax
    pop dx cx
    ret

s_in   db 'How many numbers? $'
s_out  db 'Random: $'
count  dw 0
seed   dw 0

include 'inc/std.asm'