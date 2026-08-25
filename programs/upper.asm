use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  upper.com — 输入一行字符串，转为大写输出
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
    cmp al, 'a'
    jb .ok
    cmp al, 'z'
    ja .ok
    sub al, 20h             ; 小写转大写
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
s_out  db 'Uppercase: $'
inbuf  db 128
       db 0
       db 128 dup(0)

include 'inc/std.asm'