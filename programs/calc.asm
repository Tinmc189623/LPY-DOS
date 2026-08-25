use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  calc.com — 内联表达式计算器，支持 + - * /，输入 q 退出
;  示例：12+34 或 8*7
; ============================================================================
start:
    call crlf
    puts s_tip
.loop:
    ; 读一行表达式
    lea dx, [l_buf]
    mov ah, 0Ah
    int 21h
    call crlf
    ; 检查退出
    lea si, [l_buf+2]
    mov al, [si]
    cmp al, 'q'
    je .exit
    cmp al, 'Q'
    je .exit
    cmp al, 0Dh
    je .exit
    ; 解析 "a op b"
    call do_calc
    jmp .loop
.exit:
    int 20h

; ----------------------------------------------------------------------------
;  do_calc：把 [l_buf+2] 的 "A op B" 拆分并计算输出
; ----------------------------------------------------------------------------
do_calc:
    lea si, [l_buf+2]
    lea di, [tbuff]
.copy_a:
    mov al, [si]
    cmp al, '+'
    je .got_op
    cmp al, '-'
    je .got_op
    cmp al, '*'
    je .got_op
    cmp al, '/'
    je .got_op
    mov [di], al
    inc si
    inc di
    jmp .copy_a
.got_op:
    mov byte [di], 0            ; A 段结束
    mov [opch], al
    inc si                      ; 跳过运算符
    ; 跳过运算符后的空格
.skip_sp:
    cmp byte [si], ' '
    jne .skip_done
    inc si
    jmp .skip_sp
.skip_done:
    ; 复制 B 段
    lea di, [tbuff+16]
.copy_b:
    mov al, [si]
    cmp al, 0Dh
    je .b_done
    mov [di], al
    inc si
    inc di
    jmp .copy_b
.b_done:
    mov byte [di], 0
    ; A -> AX, B -> DX
    lea si, [tbuff]
    call atoi_dec
    mov [va], ax
    lea si, [tbuff+16]
    call atoi_dec
    mov [vb], ax
    ; 运算分派
    mov al, [opch]
    mov bx, [va]
    mov dx, [vb]
    cmp al, '+'
    je .add
    cmp al, '-'
    je .sub
    cmp al, '*'
    je .mul
    ; 除法
    test dx, dx
    jz .div0
    xor dx, dx
    mov ax, bx
    div word [vb]
    jmp .emit
.add:
    mov ax, bx
    add ax, dx
    jmp .emit
.sub:
    mov ax, bx
    sub ax, dx
    jmp .emit
.mul:
    mov ax, bx
    imul dx
.emit:
    call print_dec16
    call crlf
    ret
.div0:
    puts s_div0
    ret

s_tip db 'Simple calculator:  A op B   (q=quit)$'
s_div0 db 'Divide by zero.$'

l_buf db 64
      db 0
      db 64 dup(0)
tbuff db 32 dup(0)
va    dw 0
vb    dw 0
opch  db 0

include 'inc/std.asm'