use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  readf.com — 读取并显示文本文件内容
;  用法：READF <文件名>
; ============================================================================
start:
    lea di, [fname]
    mov bl, 1
    call get_cmd_arg
    jc .usage
    ; AH=3D 打开（只读）
    lea dx, [fname]
    mov ax, 3D00h
    int 21h
    jc .err
    mov bx, ax
.read:
    mov ah, 3Fh
    mov cx, 512
    lea dx, [buf]
    int 21h
    jc .err_close
    test ax, ax
    jz .done
    ; 输出读取的字节
    mov cx, ax
    lea si, [buf]
.put:
    lodsb
    push cx
    mov dl, al
    mov ah, 02h
    int 21h
    pop cx
    loop .put
    jmp .read
.done:
    mov ah, 3Eh
    int 21h
    jmp .fin
.err_close:
    mov ah, 3Eh
    int 21h
.err:
    puts s_err
    jmp .fin
.usage:
    puts s_usage
.fin:
    int 20h

s_usage db 'Usage: READF <filename>$'
s_err   db 'Cannot open file.', 0Dh, 0Ah, '$'
fname   db 64 dup(0)
buf     db 512 dup(0)

include 'inc/std.asm'