; ----------------------------------------------------------------------------
;  fn_gfx_circle：AH=77 画圆（Bresenham 中点法）
;  入口：BX=圆心X, CX=圆心Y, SI=半径, DL=颜色
; ----------------------------------------------------------------------------
fn_gfx_circle:
        cmp byte [gfx_on], 0
        je .err
        mov [g_x], bx
        mov [g_y], cx
        mov [g_r], si
        mov [g_col], dl
        mov word [g_px], 0
        mov [g_py], si
        mov ax, 1
        sub ax, si
        mov [g_d], ax
.lp:
        mov ax, [g_px]
        cmp ax, [g_py]
        jg .done
        call draw_sym8
        mov ax, [g_d]
        test ax, ax
        jns .c_dec            ; d >= 0
        ; d < 0：d += 2*x + 3
        mov bx, [g_px]
        shl bx, 1
        add ax, bx
        add ax, 3
        mov [g_d], ax
        jmp .incx
.c_dec:
        ; d >= 0：d += 2*(x-y) + 5；y--
        mov bx, [g_px]
        sub bx, [g_py]
        shl bx, 1
        add ax, bx
        add ax, 5
        mov [g_d], ax
        dec word [g_py]
.incx:
        inc word [g_px]
        jmp .lp
.done:
        clc
        ret
.err:
        stc
        ret

; ----------------------------------------------------------------------------
;  draw_sym8：画圆当前点的 8 个对称点
; ----------------------------------------------------------------------------
draw_sym8:
        ; 4 组 (±px,±py) 与 (±py,±px)
l1:
        push ax bx cx dx
        mov ax, [g_x]
        add ax, [g_px]
        mov bx, ax
        mov ax, [g_y]
        add ax, [g_py]
        mov cx, ax
        mov dl, [g_col]
        call put_pixel
        pop dx cx bx ax
        ; X-px, Y+py
        push ax bx cx dx
        mov ax, [g_x]
        sub ax, [g_px]
        mov bx, ax
        mov ax, [g_y]
        add ax, [g_py]
        mov cx, ax
        mov dl, [g_col]
        call put_pixel
        pop dx cx bx ax
        ; X+px, Y-py
        push ax bx cx dx
        mov ax, [g_x]
        add ax, [g_px]
        mov bx, ax
        mov ax, [g_y]
        sub ax, [g_py]
        mov cx, ax
        mov dl, [g_col]
        call put_pixel
        pop dx cx bx ax
        ; X-px, Y-py
        push ax bx cx dx
        mov ax, [g_x]
        sub ax, [g_px]
        mov bx, ax
        mov ax, [g_y]
        sub ax, [g_py]
        mov cx, ax
        mov dl, [g_col]
        call put_pixel
        pop dx cx bx ax
        ; X+py, Y+px
        push ax bx cx dx
        mov ax, [g_x]
        add ax, [g_py]
        mov bx, ax
        mov ax, [g_y]
        add ax, [g_px]
        mov cx, ax
        mov dl, [g_col]
        call put_pixel
        pop dx cx bx ax
        ; X-py, Y+px
        push ax bx cx dx
        mov ax, [g_x]
        sub ax, [g_py]
        mov bx, ax
        mov ax, [g_y]
        add ax, [g_px]
        mov cx, ax
        mov dl, [g_col]
        call put_pixel
        pop dx cx bx ax
        ; X+py, Y-px
        push ax bx cx dx
        mov ax, [g_x]
        add ax, [g_py]
        mov bx, ax
        mov ax, [g_y]
        sub ax, [g_px]
        mov cx, ax
        mov dl, [g_col]
        call put_pixel
        pop dx cx bx ax
        ; X-py, Y-px
        push ax bx cx dx
        mov ax, [g_x]
        sub ax, [g_py]
        mov bx, ax
        mov ax, [g_y]
        sub ax, [g_px]
        mov cx, ax
        mov dl, [g_col]
        call put_pixel
        pop dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  fn_gfx_fillcircle：AH=78 填充圆（逐行扫描画水平线）
;  入口：BX=圆心X, CX=圆心Y, SI=半径, DL=颜色
; ----------------------------------------------------------------------------
fn_gfx_fillcircle:
        cmp byte [gfx_on], 0
        je .err
        mov [g_x], bx
        mov [g_y], cx
        mov [g_r], si
        mov [g_col], dl
        ; r^2
        mov ax, [g_r]
        mov bx, ax
        mul bx
        mov [g_r2], ax
        ; dy 从 -r 到 +r
        mov ax, [g_r]
        neg ax
        mov [g_dy], ax
.lp:
        mov ax, [g_dy]
        cmp ax, [g_r]
        jg .done
        ; dy^2
        mov ax, [g_dy]
        mov bx, ax
        imul bx
        mov [g_d2], ax
        ; d = r^2 - dy^2
        mov ax, [g_r2]
        sub ax, [g_d2]
        mov [g_d], ax
        ; dx = floor(sqrt(d))，逐增试探
        xor cx, cx
.sqr:
        cmp cx, [g_r]
        ja .sqr_done
        inc cx
        push cx dx
        mov ax, cx
        mul cx
        pop dx cx
        test dx, dx
        jnz .sqr_done       ; cx^2 已溢出必然 >= d
        cmp ax, [g_d]
        jb .sqr
.sqr_done:
        ; 画 (X-dx, Y+dy)..(X+dx, Y+dy)
        mov ax, [g_x]
        sub ax, cx
        mov bx, ax
        mov ax, [g_x]
        add ax, cx
        mov di, ax
        mov ax, [g_y]
        add ax, [g_dy]
        mov cx, ax
        mov dl, [g_col]
        call fn_gfx_hline
        inc word [g_dy]
        jmp .lp
.done:
        clc
        ret
.err:
        stc
        ret

