use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  copyf.com — 复制文件：源文件 → 目标文件
;  用法：COPYF <源> <目标>
; ============================================================================
start:
    lea di, [src]
    mov bl, 1
    call get_cmd_arg
    jc .usage
    lea di, [dst]
    mov bl, 2
    call get_cmd_arg
    jc .usage
    ; 打开源（只读）
    lea dx, [src]
    mov ax, 3D00h
    int 21h
    jc .err
    mov si, ax              ; 源句柄
    ; 创建目标
    lea dx, [dst]
    mov cx, 0
    mov ah, 3Ch
    int 21h
    jc .close_src
    mov di, ax              ; 目标句柄
.copy:
    ; 读源
    mov bx, si
    mov ah, 3Fh
    mov cx, 512
    lea dx, [buf]
    int 21h
    jc .close_err
    test ax, ax
    jz .copied
    ; 写目标
    mov cx, ax
    mov bx, di
    mov ah, 40h
    lea dx, [buf]
    int 21h
    jc .close_err
    jmp .copy
.copied:
    ; 关闭两个句柄
    mov bx, di
    mov ah, 3Eh
    int 21h
    mov bx, si
    mov ah, 3Eh
    int 21h
    puts s_ok
    jmp .fin
.close_err:
    mov bx, di
    mov ah, 3Eh
    int 21h
.close_src:
    mov bx, si
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

s_usage db 'Usage: COPYF <src> <dst>$'
s_ok    db 'Copied.', 0Dh, 0Ah, '$'
s_err   db 'Copy failed.', 0Dh, 0Ah, '$'
src     db 64 dup(0)
dst     db 64 dup(0)
buf     db 512 dup(0)

include 'inc/std.asm'