use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  gdemo.com — 图形综合演示
;  依次用水平线/垂直线/矩形边框/填充矩形/圆/填充圆绘制色条与图形，
;  最后用图形文本在底部显示品牌行。按任意键退出。
; ============================================================================
start:
    mov ah, 70h
    int 21h                 ; 进入图形模式

    ; --- 底部 3 条水平色条 ---
    mov bx, 0
    mov cx, 194
    mov di, 319
    mov dl, 9
    mov ah, 73h
    int 21h                 ; 第1条 hline
    mov bx, 0
    mov cx, 186
    mov di, 319
    mov dl, 11
    mov ah, 73h
    int 21h                 ; 第2条
    mov bx, 0
    mov cx, 178
    mov di, 319
    mov dl, 13
    mov ah, 73h
    int 21h                 ; 第3条

    ; --- 中部垂直线 ---
    mov bx, 60
    mov cx, 10
    mov di, 170
    mov dl, 14
    mov ah, 74h
    int 21h                 ; 左侧垂直分隔线
    mov bx, 260
    mov cx, 10
    mov di, 170
    mov dl, 14
    mov ah, 74h
    int 21h                 ; 右侧垂直分隔线

    ; --- 左区：填充矩形 + 边框 ---
    mov bx, 20
    mov cx, 20
    mov si, 90
    mov di, 90
    mov dl, 2
    mov ah, 76h
    int 21h                 ; 矩形边框
    mov bx, 30
    mov cx, 30
    mov si, 80
    mov di, 80
    mov dl, 10
    mov ah, 75h
    int 21h                 ; 内部填充矩形

    ; --- 中区：填充圆 + 圆环 ---
    mov bx, 160
    mov cx, 55
    mov si, 35
    mov dl, 13
    mov ah, 77h
    int 21h                 ; 圆环（描边圆）
    mov bx, 160
    mov cx, 55
    mov si, 25
    mov dl, 4
    mov ah, 78h
    int 21h                 ; 内部填充圆

    ; --- 右区：大填充圆 + 小矩形边框 ---
    mov bx, 230
    mov cx, 100
    mov si, 48
    mov dl, 9
    mov ah, 78h
    int 21h                 ; 填充大半圆
    mov bx, 210
    mov cx, 85
    mov si, 250
    mov di, 115
    mov dl, 15
    mov ah, 76h
    int 21h                 ; 圆内矩形边框

    ; --- 图形文本：显示品牌字串 ---
    mov word [txp], gmsg
    mov word [gx], 60
.txt:
    mov si, [txp]
    lodsb
    mov word [txp], si
    test al, al
    jz .tdone
    mov bh, al              ; bh = 字符
    mov dl, 15              ; 颜色
    mov si, [gx]
    mov di, 160             ; Y 固定
    mov ah, 7Ah
    int 21h
    add word [gx], 8
    jmp .txt
.tdone:
    mov ah, 0
    int 16h                 ; 等待按键
    int 20h

gmsg db 'LPY-DOS 320x200', 0
txp  dw 0
gx   dw 0

include 'inc/std.asm'