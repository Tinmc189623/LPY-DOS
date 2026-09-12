; ============================================================================
;  gplasma.com — 颜色流动渐变动画 (LPY-DOS 图形模式)
;
;  功能：用 (x+y+帧号) 的函数映射到低位色，产生自上而下流动的彩色渐变。
;  用法：运行后进入图形模式并循环动画，按任意键退出（内核自动恢复文本）。
;
;  实现要点：
;    - 逐行（按行块）刷新，避免整屏逐像素过慢
;    - 每个 4x4 块画一条水平线 (AH=73), 颜色 = (x+y+frame) 的哈希->低位色
;    - 相位 frame 每帧递增，产生流动效果
;
;  Copyright (C) 2026 Nexsteaduser
; ============================================================================
use16
org 0100h
include 'inc/macro.asm'

MXB = 80                      ; 水平块数 (320/4)
MYB = 50                      ; 垂直行数 (200/4)

start:
    mov ah, 70h
    int 21h

frame:
    mov ah, 01h
    int 16h
    jnz quit
    ; 清屏
    xor bx, bx
    xor cx, cx
    mov si, 319
    mov di, 199
    xor dl, dl
    mov ah, 75h
    int 21h

    ; 逐块绘制（用递减计数器，块坐标 = MXB - 计数 得到 0..MXB-1）
    mov bp, MYB             ; BP = 行剩余数
row_loop:
    mov di, MXB            ; DI = 列剩余数
col_loop:
    ; 列 idx = MXB - DI，行 idx = MYB - BP
    mov ax, MXB
    sub ax, di
    mov bx, ax
    mov ax, MYB
    sub ax, bp
    ; idx = 列 + 行 + 帧号 -> 低位色
    add ax, bx
    add ax, [frame]
    xor ax, 0FF97h          ; 混入相位让相邻帧色差更明显
    and ax, 15
    mov dl, al

    ; X0 = 列*4，Y = 行*4
    mov ax, di
    neg ax
    add ax, MXB
    mov bx, ax
    shl bx, 1               ; X0 = 列*4（*2 后 *2）
    shl bx, 1
    mov ax, bx
    add ax, 3
    mov si, ax              ; X1
    mov cx, bp
    neg cx
    add cx, MYB
    shl cx, 1               ; Y = 行*4
    shl cx, 1
    mov ah, 73h             ; 水平线
    int 21h

    dec di
    jnz col_loop
    dec bp
    jnz row_loop

    inc word [phase]        ; 相位推进，出现流动
    mov cx, 1
    call delay_ticks
    jmp frame
quit:
    int 20h

phase dw 0

include 'inc/std.asm'