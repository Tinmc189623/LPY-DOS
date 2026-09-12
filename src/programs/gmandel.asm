; ============================================================================
;  gmandel.asm — 曼德博集分形查看器 (.COM)
;  功能：把 320x200 屏幕逐像素映射到复数平面 x∈[-2,1]、y∈[-1,1]，
;        以 Q14 定点(14 位小数)实现复数迭代 z'=z²+c，c=像素坐标、
;        z0=0，按逃逸迭代次数着色，绘制完成后等待按键退出。
;  仅用 8086 指令；图形协议经 INT 21h（AH=70h 进图形 / 72h 画点 / 71h 退文本）。
;
;  Copyright (C) 2026 Nexsteaduser
; ============================================================================
use16
org 0100h
include 'inc/macro.asm'

; ---- Q14 常量（值 = 整数<<14）----
XMIN equ -32768            ; -2.0
DXS  equ 154               ; 3/319 取 14 位
YCTR equ 16384             ; +1.0
DYS  equ 165               ; 2/199 取 14 位
MAXIT equ 64               ; 最大迭代次数
THRH equ 4000h             ; 逃逸阈值 4<<(2*14)=2^30 的高 16 位
THRL equ 0000h             ; 逃逸阈值低 16 位

start:
    mov ah, 70h
    int 21h
    mov word [ycnt], 0
    mov word [ci], YCTR
.ly:
    mov word [xcnt], 0
    mov word [rx], 0
    mov word [cr], XMIN
.lx:
    mov word [zr], 0
    mov word [zi], 0
    call render_pixel
    mov ax, [cr]
    add ax, DXS
    mov [cr], ax
    mov ax, [rx]
    inc ax
    mov [rx], ax
    inc word [xcnt]
    cmp word [xcnt], 320
    jb .lx
    mov ax, [ci]
    sub ax, DYS
    mov [ci], ax
    mov ax, [ry]
    inc ax
    mov [ry], ax
    inc word [ycnt]
    cmp word [ycnt], 200
    jb .ly
    call get_key
    mov ah, 71h
    int 21h
    int 20h

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

include 'inc/std.asm'