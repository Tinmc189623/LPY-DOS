; ============================================================================
;  hello.asm — LPY-DOS SDK 最小示例
;  展示：字符串输出（AH=09）、版本号获取（AH=30）、退出（AH=4C）。
;  编译：fasm hello.asm hello.COM
; ============================================================================
use16
org 0100h

include '../include/lpydos.inc'

start:
    puts msg_hi
    call crlf

    ; ---- 获取并打印系统版本 ----
    call get_sysver                 ; AX = 主.次版本
    push ax
    mov al, ah                      ; 主版本
    call put_dec16
    putch '.'
    pop ax
    call put_dec16                  ; 次版本
    call crlf

    mov ah, AH_TERM_CD              ; 退出，返回码 0
    xor al, al
    int 21h

msg_hi db 'Hello, this app runs on LPY-DOS via the SDK!$'