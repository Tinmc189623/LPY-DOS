; ============================================================================
;  grotate.com — 中心旋转光弧动画 (LPY-DOS 图形模式)
;
;  功能：从屏幕中心向四周发出 ARM 条半径线，随角度均匀分布并整体匀速旋转。
;  用法：运行后进入图形模式并循环动画，按任意键退出（内核自动恢复文本）。
;
;  实现要点：
;    - 角度以 256 步一圈采样（0..255）
;    - 内置 65 项正弦表 sin_t（0..90 度，缩放到 256），用象限对称还原 sin/cos
;    - 整数近似：offset = sin(ang)*radius/256
;    - Bresenham 算法逐点画半径线 (AH=72)
;    - 中心 (160,100)，半径 RHI，条数 ARM 均分一圈
;
;  Copyright (C) 2026 Nexsteaduser
; ============================================================================
use16
org 0100h
include 'inc/macro.asm'

ARMS = 8                     ; 半径线条数（均分一圈）
MS   = 32                    ; 步数 = 256/ARMS
RHI  = 95                    ; 半径
CENTER_X = 160
CENTER_Y = 100

start:
    mov ah, 70h
    int 21h

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

    ; 逐条绘制半径线，用运行游标法避免乘法
    mov ax, [angle]         ; AX = 本条线角度
    mov cx, ARMS            ; 线条计数
arm_loop:
    mov [a_tmp], ax         ; 保存当前线角度
    ; 外端点 X = CENTER_X + cos(a)*RHI/256  (cos 用 sin(a+64))
    push ax
    add ax, 64
    and ax, 255
    mov bx, RHI
    call sincomp
    add ax, CENTER_X
    mov [ex_t], ax
    mov ax, [a_tmp]
    mov bx, RHI
    call sincomp            ; 外端点 Y = CENTER_Y + sin(a)*RHI/256
    add ax, CENTER_Y
    mov [ey_t], ax
    pop ax

    ; 画中心 -> 外端点的半径线，颜色随序号变化
    mov bx, CENTER_X
    mov cx, CENTER_Y
    mov si, [ex_t]
    mov di, [ey_t]
    mov dl, 5               ; 指定高亮色
    call draw_line

    ; 下一条线角度 += MS
    add ax, MS
    and ax, 255
    loop arm_loop

    ; 角度前进
    add word [angle], 3
    mov cx, 2
    call delay_ticks
    jmp frame
quit:
    int 20h

; ----------------------------------------------------------------------------
;  sincomp：输入 AX=角度(0..255)、BX=半径，返回 AX = sin(角)*半径/256（有符号）
; ----------------------------------------------------------------------------
sincomp:
    push cx dx
    mov word [rr_tmp], bx
    mov [ang_tmp], ax
    ; idx60 = 角 & 63
    and ax, 63
    mov [idx_tmp], ax
    ; quad = 角 >> 6
    mov ax, [ang_tmp]
    mov cl, 6
    shr ax, cl
    mov [quad_tmp], ax
    ; 查表下标：quad 为 1 或 3 时用 64-idx60，否则用 idx60
    mov ax, [idx_tmp]
    cmp word [quad_tmp], 1
    je .mirror
    cmp word [quad_tmp], 3
    jne .got
.mirror:
    mov ax, 64
    sub ax, [idx_tmp]
.got:
    mov bx, ax
    mov al, [sin_t+bx]      ; 0..256
    xor ah, ah
    ; 第 2、3 象限为负
    cmp word [quad_tmp], 2
    je .neg
    cmp word [quad_tmp], 3
    jne .pos
.neg:
    neg ax
.pos:
    ; 乘以半径 / 256
    imul word [rr_tmp]      ; DX:AX = AX*半径（有符号）
    mov cl, 8
    sar ax, cl              ; 除以 256
    pop dx cx
    ret

; ----------------------------------------------------------------------------
;  draw_line：Bresenham 画线段。入口 BX=X0,CX=Y0,SI=X1,DI=Y1,DL=颜色
; ----------------------------------------------------------------------------
draw_line:
    push ax bx cx dx si di bp
    mov [col_tmp], dl
    ; DX = |X1-X0|，SX 步进
    mov ax, si
    sub ax, bx
    mov dx, ax
    mov word [sxh_tmp], 1
    cmp ax, 0
    jge .dx1
    neg dx
    mov word [sxh_tmp], -1
.dx1:
    mov [dx_tmp], dx
    ; DY = |Y1-Y0|，SY 步进
    mov ax, di
    sub ax, cx
    mov bp, ax
    mov word [syh_tmp], 1
    cmp ax, 0
    jge .dy1
    neg bp
    mov word [syh_tmp], -1
.dy1:
    mov [dy_tmp], bp
    ; err = DX - DY
    mov ax, [dx_tmp]
    sub ax, [dy_tmp]
    mov [err_tmp], ax
.lp:
    mov dl, [col_tmp]
    mov ah, 72h             ; 画点 (bx,cx)
    int 21h
    cmp bx, si
    jne .go
    cmp cx, di
    je .done
.go:
    mov ax, [err_tmp]
    shl ax, 1               ; e2 = 2*err
    mov bp, ax
    ; if e2 > -DY：ERR-=DY，X+=SX
    mov dx, [dy_tmp]
    neg dx
    cmp bp, dx
    jle .skipx
    mov ax, [err_tmp]
    sub ax, [dy_tmp]
    mov [err_tmp], ax
    add bx, [sxh_tmp]
.skipx:
    ; if e2 < DX：ERR+=DX，Y+=SY
    mov dx, [dx_tmp]
    cmp bp, dx
    jge .skipy
    mov ax, [err_tmp]
    add ax, [dx_tmp]
    mov [err_tmp], ax
    add cx, [syh_tmp]
.skipy:
    jmp .lp
.done:
    pop bp di si dx cx bx ax
    ret

angle    dw 0
a_tmp    dw 0
ex_t     dw 0
ey_t     dw 0
rr_tmp   dw 0
ang_tmp  dw 0
idx_tmp  dw 0
quad_tmp dw 0
col_tmp  db 0
sxh_tmp  dw 0
syh_tmp  dw 0
dx_tmp   dw 0
dy_tmp   dw 0
err_tmp  dw 0

; 正弦表：sin_t[i] = sin(i*90/64度)*256，i=0..64（最大 255）
sin_t db 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92
      db 98,104,109,115,121,126,132,137,142,147,153,158,163,167,172,177
      db 181,185,190,194,198,202,206,209,213,216,220,223,227,230,233,236
      db 239,242,245,247,250,252,255,255,251,252,253,254,255,255,255,255,255

include 'inc/std.asm'