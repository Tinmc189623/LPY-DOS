use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  revstr.com — 输入一行字符串，反转输出
; ============================================================================
start:
    call check_about
    puts s_in
    call readstr            ; 读取一行到 inbuf
    mov cl, [inbuf+1]
    xor ch, ch              ; 长度
    lea si, [inbuf+1]
    add si, cx              ; si -> 最后一个字符
    puts s_out
.print:
    mov dl, [si]
    mov ah, 02h
    int 21h
    dec si
    loop .print
    call crlf
    int 20h

; ----------------------------------------------------------------------------
;  readstr：提示后读一行到 inbuf
; ----------------------------------------------------------------------------
readstr:
    lea dx, [inbuf]
    mov ah, 0Ah
    int 21h
    call crlf
    ret

s_in   db 'Enter string: $'
s_out  db 'Reversed: $'
inbuf  db 128
       db 0
       db 128 dup(0)

logo_attr db 09h
logo_data db 'RRRR   EEEEE  V   V   SSSS  TTTTT  RRRR$'
          db 'R   R  E      V   V  S      T     R   R$'
          db 'RRRR   EEE    V   V   SSS   T     RRRR$'
          db 'R   R  E       V V      S   T     R  R$'
          db 'R   R  EEEEE    V   SSSS    T     R   R$'
          db 0

include 'inc/std.asm'
include 'inc/logo.asm'