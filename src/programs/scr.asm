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

logo_attr db 0Ah
logo_data db ' SSSS   CCCC  RRRR$'
          db 'S      C     R   R$'
          db ' SSS    C     RRRR$'
          db '    S   C     R  R$'
          db 'SSSS    CCCC  R   R$'
          db 0

include 'inc/std.asm'
include 'inc/logo.asm'