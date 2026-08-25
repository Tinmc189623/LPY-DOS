use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  spin.com — 旋转等待动画，提示后按任意键退出
; ============================================================================
start:
    puts s_msg
    mov si, spin_chars
.loop:
    ; 非阻塞检查键盘
    mov ah, 01h
    int 16h
    jnz .stop
    lodsb
    cmp al, 0
    jne .have
    mov si, spin_chars      ; 回到串首
    lodsb
.have:
    mov ah, 0Eh             ; 电传输出字符
    int 10h
    mov al, 08h             ; 退格回到原位覆盖
    mov ah, 0Eh
    int 10h
    mov cx, 2
    call delay_ticks
    jmp .loop
.stop:
    call get_key            ; 清空按键队列
    call crlf
    int 20h

s_msg       db 'Working$'
spin_chars  db '|/-\', 0

include 'inc/std.asm'