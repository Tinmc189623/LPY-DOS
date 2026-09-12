use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  hex.com — 输入十进制数值，输出其十六进制表示
; ============================================================================
start:
    call check_about
    mov dx, s_in
    call read_num           ; 十进制 -> AX
    puts s_out
    call print_hex16
    call crlf
    int 20h

s_in  db 'Enter decimal: $'
s_out db 'Hex: $'

logo_attr db 0Ah
logo_data db 'H  H EEEE X  X$'
          db 'H  H E    XX $'
          db 'HHHH EEE  X  $'
          db 'H  H E    XX $'
          db 'H  H EEEE X  X$', 0

include 'inc/std.asm'
include 'inc/logo.asm'