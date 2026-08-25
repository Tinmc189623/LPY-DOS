use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  bounce.com — 一个字符球在屏内自动弹跳，任意键退出
; ============================================================================
start:
    ; 清屏
    mov ax, 0600h
    mov bh, 07h
    xor cx, cx
    mov dx, 184Fh
    int 10h
    ; 初始位置与方向
    mov byte [row], 10
    mov byte [col], 20
    mov byte [dr], 1
    mov byte [dc], 1
    puts s_msg
.frame:
    ; 有按键则退出
    mov ah, 01h
    int 16h
    jnz .exit
    ; 擦除当前位置
    mov dh, [row]
    mov dl, [col]
    call setcurs
    putch ' '
    ; 位移
    mov al, [row]
    add al, [dr]
    mov [row], al
    mov al, [col]
    add al, [dc]
    mov [col], al
    ; 上下边界反弹（范围 0..23）
    cmp byte [row], 0
    jne .rlow
    mov byte [dr], 1
    jmp .cck
.rlow:
    cmp byte [row], 23
    jne .cck
    mov byte [dr], -1
.cck:
    ; 左右边界反弹（范围 0..78）
    cmp byte [col], 0
    jne .clow
    mov byte [dc], 1
    jmp .wrt
.clow:
    cmp byte [col], 78
    jne .wrt
    mov byte [dc], -1
.wrt:
    ; 在新位置画球
    mov dh, [row]
    mov dl, [col]
    call setcurs
    putch '*'
    mov cx, 1
    call delay_ticks
    jmp .frame
.exit:
    call get_key
    int 20h

s_msg db 'Bouncing ball - press any key to stop$'
row   db 0
col   db 0
dr    db 0
dc    db 0

include 'inc/std.asm'