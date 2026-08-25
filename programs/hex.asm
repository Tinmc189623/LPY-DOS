use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  hex.com — 输入十进制数值，输出其十六进制表示
; ============================================================================
start:
    mov dx, s_in
    call read_num           ; 十进制 -> AX
    puts s_out
    call print_hex16
    call crlf
    int 20h

s_in  db 'Enter decimal: $'
s_out db 'Hex: $'

include 'inc/std.asm'