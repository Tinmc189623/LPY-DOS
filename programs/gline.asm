use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  gline.com — 从屏幕中心向外绘制多角度斜线
;  以 (160,100) 为心，按 16 个方向(每 22.5°)用 Bresenham 算法逐点画线，
;  颜色沿方向递增循环。按任意键退出。
; ============================================================================
start:
    mov ah, 70h
    int 21h                 ; 进入图形模式

    mov byte [ict], 0       ; 方向计数 0..15
.loop:
    mov al, [ict]
    xor ah, ah
    mov si, ax
    shl si, 1
    shl si, 1               ; 索引 = 计数*4（每组 x,y 两个 dw）
    mov ax, [ang+si]
    mov [lx1], ax
    mov ax, [ang+si+2]
    mov [ly1], ax           ; 取该方向的端点

    mov word [lx0], 160
    mov word [ly0], 100     ; 屏幕中心起点

    mov al, [ict]
    inc al
    mov dl, al              ; 颜色 1..16
    mov [lcol], dl
    call linedraw           ; 画一条斜线

    inc byte [ict]
    cmp byte [ict], 16
    jb .loop

    mov ah, 0
    int 16h                 ; 等待按键
    int 20h                 ; 退出，内核自动恢复文本模式

; ----------------------------------------------------------------------------
;  linedraw：Bresenham 直线，从 (lx0,ly0) 到 (lx1,ly1)，颜色 lcol
; ----------------------------------------------------------------------------
linedraw:
    push ax bx cx dx
    ; dx = |lx1 - lx0|
    mov ax, [lx1]
    sub ax, [lx0]
    jns .dxok
    neg ax
.dxok:
    mov [ldxm], ax
    ; sx 方向
    mov ax, [lx0]
    cmp ax, [lx1]
    jl .sxp
    mov word [lsx], -1
    jmp .sy
.sxp:
    mov word [lsx], 1
.sy:
    ; dy = |ly1 - ly0|
    mov ax, [ly1]
    sub ax, [ly0]
    jns .dyok
    neg ax
.dyok:
    mov [ldym], ax
    ; sy 方向
    mov ax, [ly0]
    cmp ax, [ly1]
    jl .syp
    mov word [lsy], -1
    jmp .err
.syp:
    mov word [lsy], 1
.err:
    ; err = dx - dy
    mov ax, [ldxm]
    sub ax, [ldym]
    mov [lerr], ax
.pt:
    ; 画当前点
    mov bx, [lx0]
    mov cx, [ly0]
    mov dl, [lcol]
    mov ah, 72h
    int 21h
    ; 到达终点则返回
    mov ax, [lx0]
    cmp ax, [lx1]
    jne .cont
    mov ax, [ly0]
    cmp ax, [ly1]
    je .done
.cont:
    ; e2 = 2*err
    mov ax, [lerr]
    shl ax, 1
    mov [le2], ax
    ; e2 > -dy 时：err -= dy; x += sx
    mov ax, [le2]
    mov bx, [ldym]
    neg bx
    cmp ax, bx
    jle .yup
    mov ax, [lerr]
    sub ax, [ldym]
    mov [lerr], ax
    mov ax, [lx0]
    add ax, [lsx]
    mov [lx0], ax
.yup:
    ; e2 < dx 时：err += dx; y += sy
    mov ax, [le2]
    cmp ax, [ldxm]
    jge .pt
    mov ax, [lerr]
    add ax, [ldxm]
    mov [lerr], ax
    mov ax, [ly0]
    add ax, [lsy]
    mov [ly0], ax
    jmp .pt
.done:
    pop dx cx bx ax
    ret

; 16 个方向端点表（相对中心 (160,100) 的落点，全屏幕边界内）
ang dw 250,100, 243,134, 224,164, 194,183
    dw 160,190, 126,183, 96,164, 77,134
    dw 70,100,  77,66,   96,36,  126,17
    dw 160,10,  194,17,  224,36, 243,66

ict  db 0
lx0  dw 0
ly0  dw 0
lx1  dw 0
ly1  dw 0
lcol db 0
ldxm dw 0
ldym dw 0
lsx  dw 0
lsy  dw 0
lerr dw 0
le2  dw 0

include 'inc/std.asm'