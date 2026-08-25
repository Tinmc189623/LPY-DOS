use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  dec.com — 输入十六进制数值，输出其十进制表示
; ============================================================================
start:
    puts s_in
    ; 读一行到共享缓冲再按十六进制解析
    mov dx, num_buf
    mov ah, 0Ah
    int 21h
    call crlf
    lea si, [num_buf+2]
    call htoi              ; 十六进制串 -> AX
    puts s_out
    call print_dec16
    call crlf
    int 20h

; ----------------------------------------------------------------------------
;  htoi：把 DS:SI 的十六进制字符串（0-9 A-F a-f）解析为 AX
; ----------------------------------------------------------------------------
htoi:
    push bx cx dx si
    xor ax, ax
    mov bx, 16
.loop:
    mov cl, [si]
    cmp cl, '0'
    jb .done
    cmp cl, '9'
    ja .aft
    and cl, 0Fh             ; 数字位
    jmp .add
.aft:
    ; 字母转大写
    cmp cl, 'a'
    jb .chk
    sub cl, 20h
.chk:
    cmp cl, 'A'
    jb .done
    cmp cl, 'F'
    ja .done
    sub cl, 'A'-10          ; A=10..F=15
.add:
    mul bx                  ; AX*16
    add ax, cx
    inc si
    jmp .loop
.done:
    pop si dx cx bx
    ret

s_in  db 'Enter hex number: $'
s_out db 'Decimal: $'

include 'inc/std.asm'