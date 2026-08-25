use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  fsize.com — 显示文件大小（字节）
;  用法：FSIZE <文件名>
; ============================================================================
start:
    lea di, [fname]
    mov bl, 1
    call get_cmd_arg
    jc .usage
    ; 打开文件
    lea dx, [fname]
    mov ax, 3D00h
    int 21h
    jc .err
    mov bx, ax
    ; AH=42 移动指针到文件末尾（AL=2），AX=DWORD 高位，DX=... 
    ;   AH=42 AL=2：从文件末尾，CX:DX=0 偏移
    xor cx, cx
    xor dx, dx
    mov ax, 4202h
    int 21h
    ; 返回的 DX:AX = 文件长度
    mov [hi], dx
    mov [lo], ax
    ; 关闭
    mov ah, 3Eh
    int 21h
    puts s_out
    ; 先输出高位（若不为 0）再输出低位
    cmp word [hi], 0
    je .low_only
    mov ax, [hi]
    call print_dec16
.low_only:
    mov ax, [lo]
    call print_dec16
    puts s_bytes
    jmp .fin
.usage:
    puts s_usage
    jmp .fin
.err:
    puts s_err
.fin:
    int 20h

s_usage db 'Usage: FSIZE <filename>$'
s_out   db 'Size: $'
s_bytes db ' bytes.', 0Dh, 0Ah, '$'
s_err   db 'Cannot open file.', 0Dh, 0Ah, '$'
fname   db 64 dup(0)
lo      dw 0
hi      dw 0

include 'inc/std.asm'