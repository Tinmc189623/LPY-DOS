use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  args.com — 打印命令行传入的原始参数（取 PSP +0x80 长度区）
;  用法：ARGS CPU 123 X
; ============================================================================
start:
    mov si, 0080h           ; PSP:0x80 = 命令行长度
    mov cl, [si]
    xor ch, ch
    inc si                  ; 指向 0x81 起的数据
    test cl, cl
    jz .empty
    ; 去除前导空格
.skip:
    mov al, [si]
    cmp al, ' '
    jne .print
    dec cx
    jz .empty
    inc si
    jmp .skip
.print:
    ; 逐字符输出参数
.p:
    test cx, cx
    jz .done
    mov dl, [si]
    mov ah, 02h
    int 21h
    inc si
    dec cx
    jmp .p
.done:
    call crlf
    jmp .fin
.empty:
    ; 无参数时给出提示
    puts s_none
.fin:
    int 20h

s_none  db 'No arguments given.$'

include 'inc/std.asm'