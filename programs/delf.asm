use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  delf.com — 删除指定的文件
;  用法：DELF <文件名>
; ============================================================================
start:
    lea di, [fname]
    mov bl, 1
    call get_cmd_arg
    jc .usage
    ; AH=41 删除文件
    lea dx, [fname]
    mov ah, 41h
    int 21h
    jc .err
    puts s_ok
    jmp .fin
.usage:
    puts s_usage
    jmp .fin
.err:
    puts s_err
.fin:
    int 20h

s_usage db 'Usage: DELF <filename>$'
s_ok    db 'Deleted.', 0Dh, 0Ah, '$'
s_err   db 'Cannot delete file.', 0Dh, 0Ah, '$'
fname   db 64 dup(0)

include 'inc/std.asm'