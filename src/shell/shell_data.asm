;  数据
; ============================================================================
star_all        db '*.*',0
cmdline_len     dw 0
dir_count       dw 0
s_echo_on       db 'ECHO is on',0Dh,0Ah,'$'
s_echo_off      db 'ECHO is off',0Dh,0Ah,'$'

; LPY-DOS ASCII 横幅（每行以 $ 结尾，末尾 0 结束；末行缺 $ 会让
; print_logo 的行扫描越过 0 终止符，把整块内存当横幅渲染）
s_logo          db 'L    PPPP  Y   Y - DDDD   OOO  SSSS','$'
                db 'L    P   P Y Y - D   D O   O S    ','$'
                db 'L    PPPP   Y   - D   D O   O  SSS ','$'
                db 'L    P       Y   - D   D O   O     S','$'
                db 'L    P     Y Y - D   D O   O S    ','$'
                db 'LLLLL P      Y   - DDDD   OOO  SSSS','$'
                db 0
logo_attr       db 0Bh            ; 横幅颜色：亮青
logo_base       db 0
logo_row        db 0
logo_col        db 0
