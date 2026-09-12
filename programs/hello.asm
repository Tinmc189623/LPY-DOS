use16
org 0100h
include 'inc/macro.asm'
    call check_about

_start:
    mov dx, msg        ; DX = 字符串偏移地址
    mov ah, 09h
    int 21h

    mov ah, 4Ch        ; DOS程序退出
    int 21h

msg db 'Hello, World!$'  ; 必须以 $ 结尾

logo_attr db 0x3C
logo_data db '#   # ##### #     #      ### $'
db '#   # #     #     #     #   #$'
db '##### ####  #     #     #   #$'
db '#   # #     #     #     #   #$'
db '#   # ##### ##### #####  ### $'
db 0

include 'inc/logo.asm'
