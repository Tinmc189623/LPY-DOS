use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  glife.com — 康威生命游戏（像素版，64x40 环绕网格）
;  玩法：进入图形模式后随机播种，按空格暂停/继续，Q 或 Esc 退出。
;  每一代按康威规则推进：活邻居=3 时生，2/3 存活，否则死/消失。
;  用 16 位 Galois LFSR 播种（种子取时钟低字）。
;  图形协议经 INT 21h：AH=70 进入图形，AH=75 填充方块，AH=7A 画文本；
;  程序经 int 20h 退出，内核自动恢复文本模式。
;  Copyright (C) 2026 Nexsteaduser
; ============================================================================

COLS equ 64                ; 网格列数
ROWS equ 40                ; 网格行数
CELL equ 4                 ; 每格像素边长
OX   equ 32                ; 网格在屏幕上的 X 偏移
OY   equ 20                ; 网格在屏幕上的 Y 偏移
LIVE equ 10                ; 活细胞颜色（亮绿）
DEAD equ 0                 ; 死细胞颜色（黑）

; ----------------------------------------------------------------------------
;  宏：把 (xpos,ypos) 这一格画成 color 色的 CELL*CELL 填充方块
; ----------------------------------------------------------------------------
macro gcell color {
    mov  ax, [xpos]
    mov  bx, CELL
    mul  bx
    add  ax, OX
    mov  bx, ax               ; bx = px0
    mov  ax, [ypos]
    mov  cx, CELL
    mul  cx
    add  ax, OY
    mov  cx, ax               ; cx = py0
    mov  ax, bx
    add  ax, CELL
    dec  ax
    mov  si, ax               ; si = px1
    mov  ax, cx
    add  ax, CELL
    dec  ax
    mov  di, ax               ; di = py1
    mov  ah, 75h
    mov  dl, color
    int  21h
}


; ============================================================================
;  子模块（按 include 顺序拼接为完整程序；勿在 include 间插代码，新内容进对应子模块）
; ============================================================================
include 'glife/main.asm'
include 'glife/init.asm'
include 'glife/evolve.asm'
include 'glife/draw.asm'
include 'glife/screen.asm'
include 'glife/rand.asm'
include 'inc/std.asm'