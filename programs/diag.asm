use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  diag.com — 从左上到右下的斜线扫描
; ============================================================================
start:
    mov bx, 0
.loop:
    cmp bx, 24
    jg .done
    mov dh, bl
    mov dl, bl
    call setcurs
    putch '*'
    inc bx
    jmp .loop
.done:
    mov dh, 25
    mov dl, 0
    call setcurs
    puts s_msg
    int 20h

s_msg db 'Diagonal drawn.$'

logo_attr db 0x0E
logo_data db '####  #####  ###   ####$'
db '#   #   #   #   # #    $'
db '#   #   #   ##### #  ##$'
db '#   #   #   #   # #   #$'
db '####  ##### #   #  ####$'
db 0

include 'inc/std.asm'
include 'inc/logo.asm'