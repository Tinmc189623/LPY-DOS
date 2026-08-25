use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  relay.com — 反应速度测试：出现 "GO" 后立刻按键，计时滴滴答答
; ============================================================================
start:
    puts s_wait
    ; 随机延时 18..179 滴答（约 1..10 秒）
    call lfsr
    mov cx, 162
    xor dx, dx
    div cx
    add dl, 18
    mov cl, dl
    xor ch, ch
    call delay_ticks
    puts s_go
    ; 读取当前时钟滴答作为起点
    mov ah, 0
    int 1Ah                  ; CX:DX = 滴答
    mov [t0], dx
    ; 等待按键
    call get_key
    ; 读取结束滴答
    mov ah, 0
    int 1Ah
    mov ax, dx
    sub ax, [t0]             ; 耗时滴答
    puts s_react
    call print_dec16
    puts s_ticks
    ; 近似秒数 = ticks / 18
    mov cx, 18
    xor dx, dx
    div cx                   ; AX = 秒
    puts s_sec
    call print_dec16
    putch '.'
    int 20h

; ----------------------------------------------------------------------------
;  lfsr：Galois LFSR，返回 AX = 伪随机数
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

s_wait  db 'Get ready...', 0Dh, 0Ah, '$'
s_go    db 'GO! PRESS ANY KEY NOW!', 0Dh, 0Ah, '$'
s_react db 'Reaction time: $'
s_ticks db ' ticks ($'
s_sec   db ' approx. seconds).', 0Dh, 0Ah, '$'
seed    dw 0
t0      dw 0

include 'inc/std.asm'