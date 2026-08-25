use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  guess.com — 猜数字游戏：电脑想一个 1..100 的数，玩家猜
; ============================================================================
start:
    ; 生成秘密数：1..100
    mov ah, 0
    int 1Ah
    mov byte [seed], dl
    call lfsr
    mov cx, 100
    xor dx, dx
    div cx
    inc dl
    mov [secret], dl
    mov byte [tries], 0
    puts s_head
.loop:
    inc byte [tries]
    mov dx, s_enter
    call read_num           ; AL(低字节 AX) = 玩家猜测
    mov dl, [secret]
    cmp al, dl
    je .got
    ja .high
    puts s_low
    jmp .loop
.high:
    puts s_high
    jmp .loop
.got:
    puts s_got
    xor ax, ax
    mov al, [tries]
    call print_dec16
    puts s_tries
    call crlf
    int 20h

; ----------------------------------------------------------------------------
;  lfsr：Galois LFSR，返回 AX = 伪随机数
; ----------------------------------------------------------------------------
lfsr:
    push cx dx
    mov ax, [seed]
    mov cx, 8
.l:
    mov dx, ax
    and dx, 1
    shr ax, 1
    test dx, dx
    jz .no
    xor ax, 0B400h
.no:
    loop .l
    mov [seed], ax
    pop dx cx
    ret

s_head  db 'Guess the number (1..100):', 0Dh, 0Ah, '$'
s_enter db 'Your guess: $'
s_low   db '  Too low.', 0Dh, 0Ah, '$'
s_high  db '  Too high.', 0Dh, 0Ah, '$'
s_got   db '  Correct! Guessed in $'
s_tries db ' try(tries).', 0Dh, 0Ah, '$'
seed    dw 0
secret  db 0
tries   db 0

include 'inc/std.asm'