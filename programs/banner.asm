use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  banner.com — 用 # 方块字符打印大号 "LPY" 三行横幅
; ============================================================================
start:
    puts s_tip
    mov si, b0
    call show
    mov si, b1
    call show
    mov si, b2
    call show
    mov si, b3
    call show
    call wait_key
    int 20h

; 每行字符串以 $ 结束，show 依次输出
show:
    push ax dx
    mov ah, 09h
    int 21h                 ; 打印 si 指向的 $ 字符串
    mov dl, 0Dh
    mov ah, 02h
    int 21h
    mov dl, 0Ah
    int 21h
    pop dx ax
    ret

s_tip db 'LPY-DOS big banner:', 0Dh, 0Ah, '$'
b0    db 'L    PPPP   Y   Y$'
b1    db 'L    P   P   Y Y $'
b2    db 'L    PPPP     Y  $'
b3    db 'LLLL PPPP     Y  $'

include 'inc/std.asm'