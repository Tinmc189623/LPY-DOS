use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  palin.com — 判断输入字符串是否为回文（区分大小写）
; ============================================================================
start:
    puts s_in
    call readstr
    mov cl, [inbuf+1]
    xor ch, ch              ; 长度
    lea si, [inbuf+2]       ; 头指针
    lea di, [inbuf+1]
    add di, cx              ; di -> 最后一个字符
.check:
    cmp si, di
    jae .yes
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .no
    inc si
    dec di
    jmp .check
.yes:
    puts s_yes
    jmp .done
.no:
    puts s_no
.done:
    int 20h

readstr:
    lea dx, [inbuf]
    mov ah, 0Ah
    int 21h
    call crlf
    ret

s_in   db 'Enter string: $'
s_yes  db 'It IS a palindrome.', 0Dh, 0Ah, '$'
s_no   db 'It is NOT a palindrome.', 0Dh, 0Ah, '$'
inbuf  db 128
       db 0
       db 128 dup(0)

include 'inc/std.asm'