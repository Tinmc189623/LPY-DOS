use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  bin.com — 输入十进制数值，输出其二进制表示（每 4 位空格分隔）
; ============================================================================
start:
    mov dx, s_in
    call read_num
    puts s_out
    call print_bits16
    call crlf
    int 20h

s_in  db 'Enter decimal: $'
s_out db 'Binary: $'

include 'inc/std.asm'