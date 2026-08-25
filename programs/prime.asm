use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  prime.com — 列出小于等于 N 的全部素数（试除法判定）
; ============================================================================
start:
    mov dx, s_in
    call read_num           ; N -> AX
    mov bx, ax              ; 上限
    cmp bx, 2
    jb .none
    puts s_out
    mov si, 2               ; 当前候选
.next:
    cmp si, bx
    ja .done
    push si
    call is_prime           ; SI 素数则打印
    pop si
    inc si
    jmp .next
.none:
    puts s_small
    jmp .fin
.done:
    call crlf
.fin:
    int 20h

; ----------------------------------------------------------------------------
;  is_prime：判断 SI 是否素数，是则打印
; ----------------------------------------------------------------------------
is_prime:
    cmp si, 2
    je .yes
    mov di, 2
.try:
    mov ax, si
    xor dx, dx
    div di                  ; SI % DI
    test dx, dx
    jz .no
    inc di
    mov ax, si
    shr ax, 1               ; 试到 SI/2
    cmp di, ax
    jbe .try
.yes:
    push ax
    mov ax, si
    call print_dec16
    putch ' '
    pop ax
.no:
    ret

s_in    db 'Enter upper bound N: $'
s_out   db 'Primes below N: $'
s_small db 'No primes.', 0Dh, 0Ah, '$'

include 'inc/std.asm'