use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  countd.com — 10 秒倒计时，固定位置刷新显示
; ============================================================================
start:
    puts s_tip
    mov bh, 0
    mov cx, 10
.loop:
    ; 光标回到 (行1, 列0)
    mov ah, 02h
    mov dh, 1
    mov dl, 0
    int 10h
    push cx
    mov ax, cx
    call print_dec16        ; 打印剩余秒数
    ; 清掉被覆盖的尾字符
    putch ' '
    pop cx
    ; 每轮延时约 1 秒（18.2 滴答）
    mov ax, cx
    mov cx, 18
    push ax
    call delay_ticks
    pop ax
    mov cx, ax
    dec cx
    jnz .loop
    call crlf
    puts s_done
    int 20h

s_tip  db 'Countdown:', 0Dh, 0Ah, '$'
s_done db 'Blast off!$'

include 'inc/std.asm'