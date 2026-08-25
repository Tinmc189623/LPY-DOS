use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  colors.com — 用 BIOS INT 10h 显示 16 色块（前景属性 0..15）
; ============================================================================
start:
    mov word [idx], 0
.next:
    mov ax, [idx]
    cmp ax, 16
    jae .done
    ; 列 = idx*2 + 1
    mov dx, ax
    shl dx, 1
    inc dl
    mov dh, 12
    call setcurs
    ; 用属性色写两个空格
    mov bl, al              ; 属性色 = 当前索引
    mov ah, 09h
    mov al, ' '
    mov bh, 0
    mov cx, 2
    int 10h
    inc word [idx]
    jmp .next
.done:
    ; 标注色号 00..0F
    mov word [idx], 0
.lab:
    mov ax, [idx]
    cmp ax, 16
    jae .fin
    mov dx, ax
    shl dx, 1
    inc dl
    mov dh, 13
    call setcurs
    ; 显示两位十六进制
    mov al, BYTE [idx]
    call print_hex8
    inc word [idx]
    jmp .lab
.fin:
    mov dh, 15
    mov dl, 0
    call setcurs
    puts s_msg
    int 20h

s_msg db '16 attribute colors.$'
idx   dw 0

include 'inc/std.asm'