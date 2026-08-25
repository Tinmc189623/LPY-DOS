use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  beep.com — 扬声器发出一声短哔声
; ============================================================================
start:
    ; 打开扬声器（端口 0x61 bit0/1）
    in al, 61h
    or al, 3
    out 61h, al
    ; 设置定时器 2 频率（0x43 控制字，三个 out）
    mov al, 0B6h
    out 43h, al
    ; 分频数 = 1193182 / 800 ≈ 1491
    mov ax, 1491
    out 42h, al
    mov al, ah
    out 42h, al
    ; 持续约 0.5 秒（9 滴答）
    mov cx, 9
    call delay_ticks
    ; 关闭扬声器
    in al, 61h
    and al, 0FCh
    out 61h, al
    puts s_msg
    int 20h

s_msg db 'Beep!$'

include 'inc/std.asm'