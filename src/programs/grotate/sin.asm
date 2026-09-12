; ----------------------------------------------------------------------------
;  sincomp：输入 AX=角度(0..255)、BX=半径，返回 AX = sin(角)*半径/256（有符号）
; ----------------------------------------------------------------------------
sincomp:
    push cx dx
    mov word [rr_tmp], bx
    mov [ang_tmp], ax
    ; idx60 = 角 & 63
    and ax, 63
    mov [idx_tmp], ax
    ; quad = 角 >> 6
    mov ax, [ang_tmp]
    mov cl, 6
    shr ax, cl
    mov [quad_tmp], ax
    ; 查表下标：quad 为 1 或 3 时用 64-idx60，否则用 idx60
    mov ax, [idx_tmp]
    cmp word [quad_tmp], 1
    je .mirror
    cmp word [quad_tmp], 3
    jne .got
.mirror:
    mov ax, 64
    sub ax, [idx_tmp]
.got:
    mov bx, ax
    mov al, [sin_t+bx]      ; 0..256
    xor ah, ah
    ; 第 2、3 象限为负
    cmp word [quad_tmp], 2
    je .neg
    cmp word [quad_tmp], 3
    jne .pos
.neg:
    neg ax
.pos:
    ; 乘以半径 / 256
    imul word [rr_tmp]      ; DX:AX = AX*半径（有符号）
    mov cl, 8
    sar ax, cl              ; 除以 256
    pop dx cx
    ret

