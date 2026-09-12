use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  bin.com — 输入十进制数值，输出其二进制表示（每 4 位空格分隔）
; ============================================================================
start:
    call check_about
    mov dx, s_in
    call read_num
    puts s_out
    call print_bits16
    call crlf
    int 20h

s_in  db 'Enter decimal: $'
s_out db 'Binary: $'

logo_attr db 04h
logo_data db '###   ##  #  #$','#  #   #  ## #$','###    #  # ##$','#  #   #  #  #$','###   ##  #  #$', 0

include 'inc/std.asm'
include 'inc/logo.asm'