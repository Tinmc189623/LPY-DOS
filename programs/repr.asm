use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  repr.com — 输入一行，分类显示每个字符及其十六进制码
;  可打印字符原样输出，控制/高位字符显示为 <HH>
; ============================================================================
start:
    puts s_in
    lea dx, [inbuf]
    mov ah, 0Ah
    int 21h
    call crlf
    mov cl, [inbuf+1]
    xor ch, ch
    lea si, [inbuf+2]
    puts s_out
.loop:
    mov al, [si]
    cmp al, ' '
    jb .ctrl
    cmp al, 7Eh
    ja .ctrl
    ; 可打印
    mov dl, al
    mov ah, 02h
    int 21h
    jmp .sp
.ctrl:
    ; 显示 <HEX>
    mov dl, '<'
    call putc
    call print_hex8
    putch '>'
.sp:
    putch ' '
    inc si
    loop .loop
    call crlf
    int 20h

s_in   db 'Enter text: $'
s_out  db 'Representation: $'
inbuf  db 128
       db 0
       db 128 dup(0)

include 'inc/std.asm'