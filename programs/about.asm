use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  about.com — 显示本程序包信息与版权
; ============================================================================
start:
    call check_about
    puts s1
    puts s2
    puts s3
    puts s4
    puts s5
    int 20h

s1 db 'LPY-DOS external program pack', 0Dh, 0Ah, '$'
s2 db 'Over 50 small .COM utilities & games.', 0Dh, 0Ah, '$'
s3 db 'Built with FASM, running on LPY-DOS kernel.', 0Dh, 0Ah, 0Dh, 0Ah, '$'
s4 db 'This program is free software under the GNU GPL v3 or later.', 0Dh, 0Ah, '$'
s5 db 'Copyright (C) 2026 Nexsteaduser. All Rights Reserved', 0Dh, 0Ah, '$'

logo_attr db 1Eh
logo_data db ' ##  ###   ##  #  # ####$','#  # #  # #  # #  #   # $','#### ###  #  # #  #   # $','#  # #  # #  # #  #   # $','#  # ###   ##   ##    # $', 0

include 'inc/std.asm'
include 'inc/logo.asm'