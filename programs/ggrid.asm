use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  ggrid.com — 图形模式棋盘格
;  整屏按 20x20 像素方块划分为 16 列 x 10 行，相邻方块交替两色，
;  形成像素棋盘/网格。按任意键退出。
; ============================================================================
start:
    mov ah, 70h
    int 21h                 ; 进入图形模式

    mov byte [gr], 0
.rows:                      ; 行 0..9
    mov byte [gc], 0
.cols:                      ; 列 0..15
    ; 颜色 = (行+列)&1 ? 8 : 7
    mov al, [gr]
    add al, [gc]
    test al, 1
    jz .even
    mov dl, 8
    jmp .calc
.even:
    mov dl, 7
.calc:
    ; X0 = 列*20
    mov al, [gc]
    xor ah, ah
    mov cl, 4
    shl ax, cl              ; 列*16
    mov bx, ax
    mov al, [gc]
    xor ah, ah
    mov cl, 2
    shl ax, cl              ; 列*4
    add ax, bx              ; 列*20 = X0
    mov bx, ax              ; bx = X0
    add ax, 19
    mov si, ax              ; si = X1
    ; Y0 = 行*20
    mov al, [gr]
    xor ah, ah
    mov cl, 4
    shl ax, cl              ; 行*16
    mov cx, ax
    mov al, [gr]
    xor ah, ah
    mov cl, 2
    shl ax, cl              ; 行*4
    add ax, cx              ; Y0 = 行*20
    mov cx, ax              ; cx = Y0
    add ax, 19
    mov di, ax              ; di = Y1
    mov ah, 75h
    int 21h                 ; 填充一个棋盘格

    inc byte [gc]
    cmp byte [gc], 16
    jb .cols
    inc byte [gr]
    cmp byte [gr], 10
    jb .rows

    mov ah, 0
    int 16h                 ; 等待按键
    int 20h                 ; 退出，内核自动恢复文本模式

gr db 0
gc db 0

include 'inc/std.asm'