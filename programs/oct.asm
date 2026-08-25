use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  oct.com — 输入十进制数值，输出其八进制表示
; ============================================================================
start:
    mov dx, s_in
    call read_num
    puts s_out
    call print_oct16
    call crlf
    int 20h

; ----------------------------------------------------------------------------
;  print_oct16：输出 AX 的八进制（无前导零）
; ----------------------------------------------------------------------------
print_oct16:
    push ax bx cx dx
    mov bx, 8
    xor cx, cx
.split:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .split
.out:
    pop dx
    add dl, '0'
    call putc
    loop .out
    pop dx cx bx ax
    ret

s_in  db 'Enter decimal: $'
s_out db 'Octal: $'

include 'inc/std.asm'