use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  renf.com — 重命名文件
;  用法：RENF <旧名> <新名>
; ============================================================================
start:
    lea di, [oldname]
    mov bl, 1
    call get_cmd_arg
    jc .usage
    lea di, [newname]
    mov bl, 2
    call get_cmd_arg
    jc .usage
    ; AH=56 重命名
    lea dx, [oldname]
    lea di, [newname]
    mov ah, 56h
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

s_usage db 'Usage: RENF <old> <new>$'
s_ok    db 'Renamed.', 0Dh, 0Ah, '$'
s_err   db 'Cannot rename.', 0Dh, 0Ah, '$'
oldname db 64 dup(0)
newname db 64 dup(0)

logo_attr db 05h
logo_data db 'RRRR   EEEEE  N   N  FFFFF$'
          db 'R   R  E      NN  N  F    $'
          db 'RRRR   EEE    N N N  FFF  $'
          db 'R   R  E      N  NN  F    $'
          db 'R   R  EEEEE  N   N  F    $'
          db 0

include 'inc/std.asm'
include 'inc/logo.asm'