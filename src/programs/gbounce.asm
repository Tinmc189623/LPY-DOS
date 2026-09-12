; ============================================================================
;  gbounce.com — 彩色像素球弹跳动画 (LPY-DOS 图形模式)
;
;  功能：在图形模式下让 3 个彩色圆球在屏内来回反弹，碰撞四壁后反向。
;  用法：运行后进入图形模式并循环动画，按任意键退出（内核自动恢复文本）。
;
;  实现要点：
;    - 3 个独立的球，各自维护位置与速度
;    - 球半径 r，遇到 0 / 319-r、0 / 199-r 边界时反弹速度取反
;    - 使用内核填充圆接口 (AH=78, SI=半径)
;    - 每帧先全屏清黑，再绘制全部球
;
;  Copyright (C) 2026 Nexsteaduser
; ============================================================================
use16
org 0100h
include 'inc/macro.asm'

NB = 3

start:
    mov ah, 70h
    int 21h
    call init_balls

frame:
    mov ah, 01h
    int 16h
    jnz quit
    ; 全屏清黑
    xor bx, bx
    xor cx, cx
    mov si, 319
    mov di, 199
    xor dl, dl
    mov ah, 75h
    int 21h

    mov di, NB              ; 球计数
    xor bp, bp              ; BP = 球序号唯一索引（字节偏移）
ball_loop:
    call move_one            ; 更新并绘制一个球（入口 BP）
    add bp, 2
    dec di
    jnz ball_loop

    mov cx, 1
    call delay_ticks
    jmp frame
quit:
    int 20h

; ----------------------------------------------------------------------------
;  move_one：更新并绘制一个球。入口 BP = 球序号字节偏移
; ----------------------------------------------------------------------------
move_one:
    mov ax, [vx+bp]
    shl ax, 1
    add [px+bp], ax
    mov ax, [vy+bp]
    shl ax, 1
    add [py+bp], ax

    mov si, [rr+bp]
    mov ax, [px+bp]
    cmp ax, si
    jge .lwall
    mov [px+bp], si
    neg word [vx+bp]
    jmp .ycheck
.lwall:
    mov ax, 319
    sub ax, si
    cmp [px+bp], ax
    jle .ycheck
    mov [px+bp], ax
    neg word [vx+bp]
.ycheck:
    mov si, [rr+bp]
    mov ax, [py+bp]
    cmp ax, si
    jge .twall
    mov [py+bp], si
    neg word [vy+bp]
    jmp .draw
.twall:
    mov ax, 199
    sub ax, si
    cmp [py+bp], ax
    jle .draw
    mov [py+bp], ax
    neg word [vy+bp]
.draw:
    mov bx, [px+bp]         ; 圆心 X
    mov si, [rr+bp]         ; 半径
    mov cx, [py+bp]         ; 圆心 Y
    mov ax, [col+bp]        ; 颜色
    mov dl, al
    mov ah, 78h             ; 填充圆
    int 21h
    ret

; ----------------------------------------------------------------------------
;  init_balls：设置 3 个球的初始位置、速度、半径、颜色
; ----------------------------------------------------------------------------
init_balls:
    mov word [px+0], 60
    mov word [py+0], 40
    mov word [vx+0], 2
    mov word [vy+0], 2
    mov word [rr+0], 6
    mov word [col+0], 12
    mov word [px+2], 240
    mov word [py+2], 140
    mov word [vx+2], -2
    mov word [vy+2], 3
    mov word [rr+2], 9
    mov word [col+2], 10
    mov word [px+4], 150
    mov word [py+4], 100
    mov word [vx+4], 3
    mov word [vy+4], -2
    mov word [rr+4], 4
    mov word [col+4], 14
    ret

px rw NB
py rw NB
vx rw NB
vy rw NB
rr rw NB
col rw NB

include 'inc/std.asm'