use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  gshape.com — 矩形与圆（填充 + 边框）对比演示
;  依次绘制：正方形外框、正方形填充、圆环、填充圆、圆环+填充矩形组合，
;  直观对比填充与描边效果。按任意键退出。
; ============================================================================
start:
    mov ah, 70h
    int 21h                 ; 进入图形模式

    ; --- 左上：正方形外框 ---
    mov bx, 20
    mov cx, 20
    mov si, 85
    mov di, 85
    mov dl, 13
    mov ah, 76h
    int 21h                 ; 描边正方形

    ; --- 左中：正方形填充 ---
    mov bx, 20
    mov cx, 105
    mov si, 85
    mov di, 170
    mov dl, 9
    mov ah, 75h
    int 21h                 ; 填充正方形

    ; --- 中上：圆环 ---
    mov bx, 160
    mov cx, 55
    mov si, 42
    mov dl, 14
    mov ah, 77h
    int 21h                 ; 描边圆

    ; --- 中中：填充圆 ---
    mov bx, 160
    mov cx, 140
    mov si, 45
    mov dl, 4
    mov ah, 78h
    int 21h                 ; 填充圆

    ; --- 右上：长方形外框 ---
    mov bx, 220
    mov cx, 20
    mov si, 300
    mov di, 90
    mov dl, 12
    mov ah, 76h
    int 21h                 ; 描边长方形

    ; --- 右下：圆环 + 内部填充矩形对比 ---
    mov bx, 240
    mov cx, 150
    mov si, 45
    mov dl, 11
    mov ah, 77h
    int 21h                 ; 圆环
    mov bx, 225
    mov cx, 135
    mov si, 255
    mov di, 165
    mov dl, 2
    mov ah, 75h
    int 21h                 ; 圆环内填充矩形

    mov ah, 0
    int 16h                 ; 等待按键
    int 20h                 ; 退出，内核自动恢复文本模式

include 'inc/std.asm'