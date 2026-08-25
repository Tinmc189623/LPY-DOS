use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  rainbow.com — 用 BIOS INT 10h 逐字符写彩色 "RAINBOW" 横幅
; ============================================================================
start:
    mov si, msg
    mov di, 8               ; 起始列
    mov byte [col], 1       ; 起始属性色
.next:
    lodsb
    test al, al
    jz .done
    ; 光标定位到 (行12, 列DI)
    mov ah, 02h
    mov bh, 0
    mov dh, 12
    mov ax, di
    mov dl, al
    int 10h
    ; 写单个字符带属性色
    mov ah, 09h
    mov bh, 0
    mov cx, 1
    mov bl, [col]
    int 10h
    inc di
    inc byte [col]
    cmp byte [col], 7
    jbe .next
    mov byte [col], 1       ; 7 色循环
    jmp .next
.done:
    call crlf
    puts s_tip
    call wait_key
    int 20h

msg   db 'RAINBOW', 0
s_tip db 'Press a key.$'
col   db 1

include 'inc/std.asm'