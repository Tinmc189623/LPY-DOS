use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  react.com — 键盘检测器：显示按下键的 ASCII 码与扫描码，ESC 退出
; ============================================================================
start:
    puts s_head
.key:
    ; 读一个键（含扫描码）
    xor ah, ah
    int 16h                  ; AL = 字符, AH = 扫描码
    cmp al, 1Bh              ; ESC 退出
    je .exit
    mov [chr], al
    mov [scan], ah
    ; 输出格式 "char(0xHH) scan=0xHH"
    mov dl, ':'
    call putc
    mov dl, ' '
    call putc
    ; 显示字符本身（可打印才显示，否则显示点）
    mov al, [chr]
    cmp al, 20h
    jb .tick
    cmp al, 7Fh
    jae .tick
    mov dl, al
    call putc
    jmp .scan
.tick:
    mov dl, '.'
    call putc
.scan:
    putch ' '
    puts s_sc
    mov al, [scan]
    call print_hex8
    putch ' '
    puts s_ac
    mov al, [chr]
    call print_hex8
    call crlf
    jmp .key
.exit:
    int 20h

s_head db 'Keyboard test - press any key (ESC=quit):', 0Dh, 0Ah, '$'
s_sc   db 'scan=$'
s_ac   db 'ascii=$'
chr    db 0
scan   db 0

include 'inc/std.asm'