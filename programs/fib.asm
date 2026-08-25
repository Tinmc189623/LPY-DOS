use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  fib.com — 打印斐波那契数列前 N 项（16 位，溢出即停）
; ============================================================================
start:
    mov dx, s_in
    call read_num           ; N -> AX
    test ax, ax
    jz .done
    mov [count], ax         ; 剩余项数
    puts s_out
    mov ax, 1               ; prev = F1
    mov dx, 1               ; cur  = F2
.loop:
    ; 打印当前项 DX
    push ax dx
    mov ax, dx
    call print_dec16
    putch ' '
    pop dx ax
    dec word [count]        ; 已打印一项
    jz .done
    ; 计算下一项：cx = prev + cur
    mov cx, ax
    add cx, dx
    jc .done                ; 进位溢出则终止
    mov ax, dx              ; 新 prev = 旧 cur
    mov dx, cx              ; 新 cur = prev + cur
    jmp .loop
.done:
    call crlf
    int 20h

s_in   db 'How many terms? $'
s_out  db 'Fibonacci: $'
count  dw 0

include 'inc/std.asm'