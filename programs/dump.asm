use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  dump.com — 以十六进制 + ASCII 形式查看文件内容
;  用法：DUMP <文件名>
; ============================================================================
start:
    lea di, [fname]
    mov bl, 1
    call get_cmd_arg
    jc .usage
    lea dx, [fname]
    mov ax, 3D00h
    int 21h
    jc .err
    mov bx, ax
    mov word [off], 0
.read:
    mov ah, 3Fh
    mov cx, 16
    lea dx, [b16]
    int 21h
    jc .close_err
    test ax, ax
    jz .done
    mov [got], ax
    ; 当前偏移
    mov ax, [off]
    call print_hex16
    putch ' '
    ; 十六进制字节
    lea si, [b16]
    mov cx, [got]
    xor di, di              ; 实际计数
.hx:
    lodsb
    call print_hex8
    putch ' '
    inc di
    loop .hx
    ; 不足 16 字节时补齐空格
    mov ax, 16
    sub ax, di
    mov cx, ax
.pad:
    push cx
    putch ' '
    putch ' '
    putch ' '
    pop cx
    loop .pad
    ; ASCII 栏
    putch '|'
    lea si, [b16]
    mov cx, [got]
.asc:
    lodsb
    cmp al, 20h
    jb .dot
    cmp al, 7Fh
    jae .dot
    mov dl, al
    jmp .puta
.dot:
    mov dl, '.'
.puta:
    mov ah, 02h
    int 21h
    loop .asc
    putch '|'
    call crlf
    mov ax, [got]
    add [off], ax
    jmp .read
.done:
    mov ah, 3Eh
    int 21h
    jmp .fin
.close_err:
    mov ah, 3Eh
    int 21h
    puts s_err
    jmp .fin
.usage:
    puts s_usage
    jmp .fin
.err:
    puts s_err
.fin:
    int 20h

s_usage db 'Usage: DUMP <filename>$'
s_err   db 'Cannot open file.', 0Dh, 0Ah, '$'
fname   db 64 dup(0)
b16     db 16 dup(0)
got     dw 0
off     dw 0

include 'inc/std.asm'