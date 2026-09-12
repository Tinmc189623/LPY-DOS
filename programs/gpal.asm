use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  gpal.com — 图形模式显示 256 色调色板色带
;  整屏划分为 8 行 x 32 列的色块网格，每个色块颜色 = 行*32+列（0..255），
;  完整覆盖 VGA 256 色常用范围。
;  用法：运行后进入图形模式，按任意键退出。
; ============================================================================
start:
    mov ah, 70h
    int 21h                 ; 进入图形模式

    mov byte [grow], 0
.rows:
    mov byte [gcol], 0
.cols:
    ; color = row*32 + col
    mov al, [grow]
    xor ah, ah
    mov cl, 5
    shl ax, cl              ; row*32
    mov dx, ax
    mov al, [gcol]
    xor ah, ah
    add ax, dx              ; color
    mov dl, al              ; dl = color
    ; Y0 = row*25
    mov al, [grow]
    xor ah, ah
    mov cx, 25
    mul cx                  ; ax = row*25 = Y0
    mov cx, ax              ; cx = Y0
    ; X0 = col*10
    mov al, [gcol]
    xor ah, ah
    mov cl, 3
    shl ax, cl              ; col*8
    mov bx, ax
    mov al, [gcol]
    xor ah, ah
    shl ax, 1               ; col*2
    add ax, bx              ; col*10 = X0
    mov bx, ax              ; bx = X0
    add ax, 9
    mov si, ax              ; si = X1 = X0+9
    mov ax, cx
    add ax, 24
    mov di, ax              ; di = Y1 = Y0+24
    mov ah, 75h
    int 21h                 ; 填充色块矩形

    inc byte [gcol]
    cmp byte [gcol], 32
    jb .cols
    inc byte [grow]
    cmp byte [grow], 8
    jb .rows

    mov ah, 0
    int 16h                 ; 等待按键
    int 20h                 ; 退出，内核自动恢复文本模式

grow db 0
gcol db 0

include 'inc/std.asm'