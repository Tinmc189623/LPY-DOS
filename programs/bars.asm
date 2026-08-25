use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  bars.com — 画 8 根高度递增的垂直条，模拟柱状图
; ============================================================================
start:
    mov word [bi], 0
.nextbar:
    mov ax, [bi]
    cmp ax, 8
    jae .done
    ; 高度 = bi + 2
    mov ax, [bi]
    add ax, 2
    mov [h], ax
    ; 列 = 2 + bi*3  （8 根，columns 2,5,...,23）
    mov ax, [bi]
    mov cx, 3
    mul cx
    add ax, 2
    mov [col], ax
    ; 从底部行 20 向上画 h 个 '#'
    mov bx, [h]             ; 已画计数
    mov cx, 20
    sub cx, [h]             ; 起始行 = 20 - h
.draw:
    test bx, bx
    jz .nextb
    mov dh, cl
    mov dl, BYTE [col]
    call setcurs
    putch '#'
    inc cx
    dec bx
    jmp .draw
.nextb:
    inc word [bi]
    jmp .nextbar
.done:
    mov dh, 22
    mov dl, 0
    call setcurs
    puts s_msg
    int 20h

s_msg db 'Bar chart drawn.$'
bi    dw 0
h     dw 0
col   dw 0

include 'inc/std.asm'