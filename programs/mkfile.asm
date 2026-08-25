use16
org 0100h
include 'inc/macro.asm'
msg_len equ 28

; ============================================================================
;  mkfile.com — 用参数创建文件并写入示例文本
;  用法：MKFILE <文件名>
; ============================================================================
start:
    jmp main

; 数据需在使用前定义（FASM 不允许前向引用 equ）
msg     db 'Hello from LPY-DOS MKFILE.', 0Dh, 0Ah

main:
    lea di, [fname]
    mov bl, 1
    call get_cmd_arg
    jnc .go
    ; 无参数：显示用法
    puts s_usage
    jmp .fin
.go:
    ; AH=3C 创建文件
    lea dx, [fname]
    mov cx, 0
    mov ah, 3Ch
    int 21h
    jnc .created
    puts s_err
    jmp .fin
.created:
    mov bx, ax              ; 句柄
    ; 写入内容
    mov cx, msg_len
    lea dx, [msg]
    mov ah, 40h
    int 21h
    jc .close_err
    ; 关闭
    mov ah, 3Eh
    int 21h
    jc .fin
    puts s_ok
    jmp .fin
.close_err:
    mov ah, 3Eh
    int 21h
    puts s_err
.fin:
    int 20h

s_usage db 'Usage: MKFILE <filename>$'
s_ok    db 'File created.', 0Dh, 0Ah, '$'
s_err   db 'Cannot create file.', 0Dh, 0Ah, '$'
fname   db 64 dup(0)

include 'inc/std.asm'