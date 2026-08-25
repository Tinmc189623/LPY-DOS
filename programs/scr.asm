use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  scr.com — 清屏并把光标移到左上角
; ============================================================================
start:
    ; 用 BIOS 滚屏窗口清屏
    mov ax, 0600h
    mov bh, 07h
    xor cx, cx
    mov dx, 184Fh
    int 10h
    ; 光标归零
    mov dh, 0
    mov dl, 0
    call setcurs
    puts s_msg
    int 20h

s_msg db 'Screen cleared.', 0Dh, 0Ah, '$'

include 'inc/std.asm'