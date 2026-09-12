; ============================================================================
;  gstar.com — 下坠星空/流星动画 (LPY-DOS 图形模式)
;
;  功能：在图形模式下生成 48 颗随机流星，自屏幕顶部向下坠落，
;        落到底部后回到顶部并重新随机，呈现下坠星空效果。
;  用法：运行后进入图形模式并循环播放，按任意键退出（内核自动恢复文本）。
;
;  实现要点：
;    - 16 位 Galois LFSR 生成伪随机 (lfsr_rand)
;    - 每帧先用 0 色全屏填充矩形清屏，再重绘全部星星
;    - 每颗星：y += 速度；y>=200 时回到顶部重新随机
;    - 头部为亮色点，下方用偏暗色画一小段尾迹
;
;  Copyright (C) 2026 Nexsteaduser
; ============================================================================
use16
org 0100h
include 'inc/macro.asm'

STARS = 48

start:
    mov ah, 70h             ; 进入图形模式
    int 21h
    mov word [lfsr], 0AC40h ; LFSR 种子（非零）
    call init_stars

frame:
    mov ah, 01h             ; 非阻塞检查按键
    int 16h
    jnz quit                ; 有键则退出
    ; 全屏填充 0 色，清除上一帧
    xor bx, bx
    xor cx, cx
    mov si, 319
    mov di, 199
    xor dl, dl
    mov ah, 75h
    int 21h
    ; 绘制全部星星
    mov cx, STARS
    xor si, si              ; SI = 星星序号 i（字节数组下标）
star_loop:
    mov di, si
    shl di, 1               ; DI = i*2（字数组下标）
    ; y += 速度
    mov ax, [sty+di]
    mov dx, 0
    mov dl, [spd+si]
    add ax, dx
    mov word [sty+di], ax
    cmp ax, 200
    jb star_ok
    ; 到底部 -> 回到顶部并重新随机
    mov word [sty+di], 0
    call rand_x
    mov [stx+di], ax
    call rand_speed
    mov [spd+si], al
    call rand_col
    mov [col+si], al
star_ok:
    ; 头部亮色点
    mov bx, [stx+di]
    mov cx, [sty+di]
    mov dl, [col+si]
    mov ah, 72h
    int 21h
    ; 下方尾迹（偏暗）
    mov bx, [stx+di]
    mov cx, [sty+di]
    inc cx
    mov dl, [col+si]
    shr dl, 1
    mov ax, cx
    add ax, 2               ; 尾迹长度：从 Y+1 到 Y+3
    mov di, ax
    mov ah, 74h             ; 垂直尾迹线
    int 21h
    inc si
    loop star_loop

    mov cx, 1
    call delay_ticks
    jmp frame
quit:
    int 20h

; ----------------------------------------------------------------------------
;  init_stars：初始化所有星星的 X/Y/速度/颜色
; ----------------------------------------------------------------------------
init_stars:
    mov cx, STARS
    xor si, si
.is:
    mov di, si
    shl di, 1
    call rand_x
    mov [stx+di], ax
    call rand_y
    mov [sty+di], ax
    call rand_speed
    mov [spd+si], al
    call rand_col
    mov [col+si], al
    inc si
    loop .is
    ret

; ----------------------------------------------------------------------------
;  lfsr_rand：返回 AX = LFSR 下一个 16 位伪随机值
; ----------------------------------------------------------------------------
lfsr_rand:
    mov ax, [lfsr]
    shr ax, 1
    jnc .no
    xor ax, 0B400h
.no:
    mov [lfsr], ax
    ret

; ----------------------------------------------------------------------------
;  rand_x：返回 AX = 0..319 随机横坐标
; ----------------------------------------------------------------------------
rand_x:
    call lfsr_rand
    xor dx, dx
    mov bx, 320
    div bx
    mov ax, dx
    ret

; ----------------------------------------------------------------------------
;  rand_y：返回 AX = 0..199 随机纵坐标
; ----------------------------------------------------------------------------
rand_y:
    call lfsr_rand
    xor dx, dx
    mov bx, 200
    div bx
    mov ax, dx
    ret

; ----------------------------------------------------------------------------
;  rand_speed：返回 AL = 1..4 随机速度
; ----------------------------------------------------------------------------
rand_speed:
    call lfsr_rand
    and ax, 3
    inc ax
    ret

; ----------------------------------------------------------------------------
;  rand_col：返回 AL = 8..15 随机亮度色
; ----------------------------------------------------------------------------
rand_col:
    call lfsr_rand
    and ax, 7
    add ax, 8
    ret

lfsr dw 0
stx  rw STARS               ; 横坐标（字数组）
sty  rw STARS               ; 纵坐标（字数组）
spd  rb STARS               ; 速度（字节数组：1..4）
col  rb STARS               ; 亮度色（字节数组：8..15）

include 'inc/std.asm'