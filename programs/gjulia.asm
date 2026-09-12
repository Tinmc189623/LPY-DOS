; ============================================================================
;  gjulia.asm — 朱利亚集分形查看器 (.COM)
;  功能：把 320x200 屏幕逐像素映射为中心区间约 ±1.5 的复数平面作为
;        z0 初值，c 固定为三个常数之一，循环渲染三种朱利亚集，期间
;        用 Q14 定点(14 位小数)实现复数迭代 z'=z²+c，按逃逸次数着色，
;        渲染结束后等待按键退出。
;  仅用 8086 指令；图形协议经 INT 21h。
;
;  Copyright (C) 2026 Nexsteaduser
; ============================================================================
use16
org 0100h
include 'inc/macro.asm'

; ---- Q14 常量 ----
ZMUL equ 154               ; 像素缩放系数（约 1.5/160）
MAXIT equ 64               ; 最大迭代次数
KCENT equ 160              ; 屏幕中心 X
RCENT equ 100              ; 屏幕中心 Y
NDELAY equ 90              ; 两图间延时（时钟滴答）
THRH equ 4000h             ; 逃逸阈值高 16 位 2^30
THRL equ 0000h             ; 逃逸阈值低 16 位

start:
    mov ah, 70h
    int 21h
    mov si, ctab
    mov word [csel], 0
.cloop:
    mov ax, [si]
    mov [cr], ax
    mov ax, [si+2]
    mov [ci], ax
    call render_all
    mov cx, NDELAY
    call delay_ticks
    add si, 4
    inc word [csel]
    cmp word [csel], 3
    jb .cloop
    call get_key
    mov ah, 71h
    int 21h
    int 20h

; ----------------------------------------------------------------------------
;  render_all：整屏渲染当前 cr/ci 的朱利亚集
; ----------------------------------------------------------------------------
render_all:
    mov word [ycnt], 0
    mov word [ry], 0
.ly:
    mov word [xcnt], 0
    mov word [rx], 0
.lx:
    mov ax, [rx]
    sub ax, KCENT
    imul word [zmul]       ; z0x = (X-160)*154
    mov [zr], ax
    mov ax, RCENT
    sub ax, [ry]
    imul word [zmul]       ; z0y = (100-Y)*154
    mov [zi], ax
    call render_pixel
    mov ax, [rx]
    inc ax
    mov [rx], ax
    inc word [xcnt]
    cmp word [xcnt], 320
    jb .lx
    mov ax, [ry]
    inc ax
    mov [ry], ax
    inc word [ycnt]
    cmp word [ycnt], 200
    jb .ly
    ret

; ----------------------------------------------------------------------------
;  render_pixel：对 [zr],[zi],[cr],[ci] 迭代着色，在 [rx],[ry] 画点
; ----------------------------------------------------------------------------
render_pixel:
    mov word [it], 0
.ip:
    mov ax, [zr]
    imul word [zr]
    mov [zrh], dx
    mov [zrl], ax
    mov ax, [zi]
    imul word [zi]
    mov [zih], dx
    mov [zil], ax
    ; 逃逸判定：|z|² 原始 32 位是否 > 2^30
    mov ax, [zrl]
    add ax, [zil]
    mov bx, ax
    mov ax, [zrh]
    adc ax, [zih]
    cmp ax, THRH
    ja .esc
    jb .cont
    cmp bx, THRL
    jbe .cont
.esc:
    mov ax, [it]
    jmp .draw
.cont:
    ; nzi = (2*zr*zi)>>14 + ci
    mov ax, [zr]
    imul word [zi]
    shl ax, 1
    rcl dx, 1
    call norm14
    add ax, [ci]
    mov [nzi], ax
    ; nzr = (zr*zr - zi*zi)>>14 + cr
    mov ax, [zrl]
    sub ax, [zil]
    mov bx, ax
    mov ax, [zrh]
    sbb ax, [zih]
    mov dx, ax
    mov ax, bx
    call norm14
    add ax, [cr]
    mov [zr], ax
    mov ax, [nzi]
    mov [zi], ax
    inc word [it]
    cmp word [it], MAXIT
    jb .ip
    xor ax, ax
.draw:
    mov bx, [rx]
    mov cx, [ry]
    mov dl, al
    mov ah, 72h
    int 21h
    ret

; ----------------------------------------------------------------------------
;  norm14：DX:AX(32位有符号) 右移 14 位，低 16 位结果在 AX
; ----------------------------------------------------------------------------
norm14:
    mov cx, dx
    and cx, 3FFFh
    shl cx, 1
    shl cx, 1
    mov bx, ax
    shr bx, 14
    or bx, cx
    mov ax, bx
    ret

; ---- 数据区 ----
ctab:                      ; 三个 c 常数（Q14）：cr, ci 交替
    dw -11469, 4424        ; -0.70 + 0.27i
    dw -13107, 2458        ; -0.80 + 0.15i
    dw  4669, 164          ;  0.285+ 0.01i
zmul dw ZMUL
zr  dw 0
zi  dw 0
cr  dw 0
ci  dw 0
zrl dw 0
zrh dw 0
zil dw 0
zih dw 0
nzi dw 0
rx  dw 0
ry  dw 0
it  dw 0
xcnt dw 0
ycnt dw 0
csel dw 0

include 'inc/std.asm'