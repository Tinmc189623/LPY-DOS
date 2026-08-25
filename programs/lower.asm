use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  lower.com — 输入一行字符串，转为小写输出
; ============================================================================
start:
    puts s_in
    call readstr
    mov cl, [inbuf+1]
    xor ch, ch
    lea si, [inbuf+2]
    puts s_out
.loop:
    mov al, [si]
    cmp al, 'A'
    jb .ok
    cmp al, 'Z'
    ja .ok
    add al, 20h             ; 大写转小写
.ok:
    mov dl, al
    mov ah, 02h
    int 21h
    inc si
    loop .loop
    call crlf
    int 20h

readstr:
    lea dx, [inbuf]
    mov ah, 0Ah
    int 21h
    call crlf
    ret

s_in   db 'Enter string: $'
s_out  db 'Lowercase: $'
inbuf  db 128
       db 0
       db 128 dup(0)

include 'inc/std.asm'