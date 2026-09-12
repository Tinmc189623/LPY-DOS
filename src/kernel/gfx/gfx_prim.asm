; ============================================================================
;  像素绘制
; ============================================================================

; ----------------------------------------------------------------------------
;  put_pixel：写单个像素，越界自动忽略
;  入口：BX=X, CX=Y, DL=颜色
; ----------------------------------------------------------------------------
put_pixel:
        push ax bx cx dx di es
        cmp bx, 319
        ja .skip
        cmp cx, 199
        ja .skip
        ; 显存偏移 = Y*320 + X；320=256+64 拆成移位相加，
        ; 不能用 mul（16 位乘法会清 DX，DL 里的颜色就丢了）
        mov ax, cx
        shl ax, 8               ; Y*256
        mov di, cx
        shl di, 6               ; Y*64
        add di, ax              ; Y*320
        add di, bx              ; + X
        mov ax, 0A000h
        mov es, ax
        mov [es:di], dl
.skip:
        pop es di dx cx bx ax
        ret

; ============================================================================
;  INT 21h 图形功能
; ============================================================================

; ----------------------------------------------------------------------------
;  fn_gfx_pixel：AH=72 画点（BX=X, CX=Y, DL=颜色）
; ----------------------------------------------------------------------------
fn_gfx_pixel:
        cmp byte [gfx_on], 0
        je .err
        call put_pixel
        clc
        ret
.err:
        stc
        ret

; ----------------------------------------------------------------------------
;  fn_gfx_hline：AH=73 水平线（BX=X0, CX=Y, DI=X1, DL=颜色）
; ----------------------------------------------------------------------------
fn_gfx_hline:
        cmp byte [gfx_on], 0
        je .err
        ; X 端点按有符号数裁剪到 0..319：填充圆等调用方可能传入
        ; 回绕成大无符号数的负坐标，无符号归一化会把整行拉到右边界
        cmp bx, 0
        jge .c0
        xor bx, bx          ; X0 < 0 → 0
.c0:    cmp bx, 319
        jle .c1
        mov bx, 319
.c1:    cmp di, 0
        jge .c2
        xor di, di
.c2:    cmp di, 319
        jle .c3
        mov di, 319
.c3:    mov ax, bx
        cmp ax, di
        jle .ok
        xchg ax, di         ; 保证 X0 <= X1（此时均已在屏幕范围内）
.ok:
.lp:
        cmp ax, di
        ja .done
        push ax bx cx dx
        mov bx, ax
        call put_pixel
        pop dx cx bx ax
        inc ax
        jmp .lp
.done:
        clc
        ret
.err:
        stc
        ret

; ----------------------------------------------------------------------------
;  fn_gfx_vline：AH=74 垂直线（BX=X, CX=Y0, DI=Y1, DL=颜色）
; ----------------------------------------------------------------------------
fn_gfx_vline:
        cmp byte [gfx_on], 0
        je .err
        ; Y 端点按有符号数裁剪到 0..199（理由同 fn_gfx_hline）
        cmp cx, 0
        jge .c0
        xor cx, cx
.c0:    cmp cx, 199
        jle .c1
        mov cx, 199
.c1:    cmp di, 0
        jge .c2
        xor di, di
.c2:    cmp di, 199
        jle .c3
        mov di, 199
.c3:    mov ax, cx
        cmp ax, di
        jle .ok
        xchg ax, di         ; AX=Y0, DI=Y1
.ok:
        mov [g_x], bx
        mov [g_col], dl
.lp:
        cmp ax, di
        ja .done
        push ax bx cx dx
        mov cx, ax
        mov bx, [g_x]
        mov dl, [g_col]
        call put_pixel
        pop dx cx bx ax
        inc ax
        jmp .lp
.done:
        clc
        ret
.err:
        stc
        ret

; ----------------------------------------------------------------------------
;  fn_gfx_fillrect：AH=75 填充矩形
;  入口：BX=X0, CX=Y0, SI=X1, DI=Y1, DL=颜色
; ----------------------------------------------------------------------------
fn_gfx_fillrect:
        cmp byte [gfx_on], 0
        je .err
        ; 四个端点先按有符号数裁剪到屏幕范围（理由同 fn_gfx_hline），
        ; 之后的无符号归一化才是安全的
        cmp bx, 0
        jge .x0
        xor bx, bx
.x0:    cmp bx, 319
        jle .x1
        mov bx, 319
.x1:    cmp si, 0
        jge .x2
        xor si, si
.x2:    cmp si, 319
        jle .x3
        mov si, 319
.x3:    cmp cx, 0
        jge .y0
        xor cx, cx
.y0:    cmp cx, 199
        jle .y1
        mov cx, 199
.y1:    cmp di, 0
        jge .y2
        xor di, di
.y2:    cmp di, 199
        jle .y3
        mov di, 199
.y3:    mov ax, bx
        cmp ax, si
        jbe .xok
        xchg ax, si
        mov bx, ax
.xok:
        mov [g_x], bx
        mov [g_x1], si
        mov ax, cx
        cmp ax, di
        jbe .yok
        xchg ax, di
        mov cx, ax
.yok:
        mov [g_y], cx
        mov [g_y1], di
        mov [g_col], dl
        mov bx, [g_y]
.row:
        cmp bx, [g_y1]
        ja .done
        mov ax, [g_x]
.col:
        cmp ax, [g_x1]
        ja .rowdone
        push ax bx cx dx
        mov cx, bx
        mov bx, ax
        mov dl, [g_col]
        call put_pixel
        pop dx cx bx ax
        inc ax
        jmp .col
.rowdone:
        inc bx
        jmp .row
.done:
        clc
        ret
.err:
        stc
        ret

; ----------------------------------------------------------------------------
;  fn_gfx_frame：AH=76 矩形边框
; ----------------------------------------------------------------------------
fn_gfx_frame:
        cmp byte [gfx_on], 0
        je .err
        mov [g_x], bx
        mov [g_x1], si
        mov [g_y], cx
        mov [g_y1], di
        mov [g_col], dl
        ; 上边
        mov bx, [g_x]
        mov cx, [g_y]
        mov di, [g_x1]
        mov dl, [g_col]
        call fn_gfx_hline
        ; 下边
        mov bx, [g_x]
        mov cx, [g_y1]
        mov di, [g_x1]
        mov dl, [g_col]
        call fn_gfx_hline
        ; 左边
        mov bx, [g_x]
        mov cx, [g_y]
        mov di, [g_y1]
        mov dl, [g_col]
        call fn_gfx_vline
        ; 右边
        mov bx, [g_x1]
        mov cx, [g_y]
        mov di, [g_y1]
        mov dl, [g_col]
        call fn_gfx_vline
        clc
        ret
.err:
        stc
        ret

