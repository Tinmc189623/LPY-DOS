use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  grid.com — 画一个 3x3 的简朴网格（用递增循环的纯 8086 指令）
; ============================================================================
start:
    ; ---- 先画横线（行 2,6,10,14，列 2..41）----
    mov bl, 2               ; 起始行号，步长 4
hrows:
    mov dh, bl
    mov dl, 2
    call setcurs
    mov cx, 40
.h:
    putch '-'
    loop .h
    add bl, 4
    cmp bl, 14
    jbe hrows
    ; ---- 再画竖线（列 2,16,30,44，行 2..13）----
    mov bl, 2               ; 起始列号，步长 14
vcols:
    mov dh, 2
    mov dl, bl
    call setcurs
    mov cx, 12
.v:
    putch '|'
    inc dh
    call setcurs
    loop .v
    add bl, 14
    cmp bl, 44
    jbe vcols
    ; 底部提示
    mov dh, 16
    mov dl, 0
    call setcurs
    puts s_msg
    int 20h

s_msg db '3x3 grid drawn.$'

include 'inc/std.asm'