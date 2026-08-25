use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  box.com — 用 BIOS 光标定位画一个矩形框
; ============================================================================
start:
    ; 顶边：row 3，col 3..38
    mov dh, 3
    mov dl, 3
    call setcurs
    putch '+'
    mov cx, 34
.top:
    putch '-'
    loop .top
    putch '+'
    ; 两侧：rows 4..11
    mov bx, 4
.side:
    cmp bx, 11
    jg .bottom
    mov dh, bl
    mov dl, 3
    call setcurs
    putch '|'
    mov dl, 38
    call setcurs
    putch '|'
    inc bx
    jmp .side
.bottom:
    mov dh, 12
    mov dl, 3
    call setcurs
    putch '+'
    mov cx, 34
.bt:
    putch '-'
    loop .bt
    putch '+'
    ; 下方提示
    mov dh, 14
    mov dl, 0
    call setcurs
    puts s_msg
    int 20h

s_msg db 'A box drawn with BIOS cursor moves.$'

include 'inc/std.asm'