; ============================================================================
;  gfx.asm — 内核 VGA 图形服务（INT 21h AH=70..7A）
;  提供 VGA 模式 13h（320x200x256）下的绘制能力：
;     AH=70 进入图形模式      AH=71 恢复文本模式
;     AH=72 画点              AH=73 水平线
;     AH=74 垂直线            AH=75 填充矩形
;     AH=76 矩形边框          AH=77 画圆
;     AH=78 填充圆            AH=79 设置调色板
;     AH=7A 图形文本（BH=字符, DL=颜色, SI=X, DI=Y）
;
;  调用约定：进入时 DS=ES=KERNEL_SEG（由 int21_handler 保证），
;  寄存器 BX/CX/DX/SI/DI 携带调用者参数；AX 已被分发逻辑占用。
;  未进入图形模式时，画图类调用返回 CF=1。
;
;  Copyright (C) 2026 Nexsteaduser
;  This program is free software under the GNU GPL v3 or later.
; ============================================================================

; ----------------------------------------------------------------------------
;  图形状态
; ----------------------------------------------------------------------------
gfx_on        db 0            ; 1 = 处于图形模式
gfx_old_mode  db 0Fh          ; 进入图形前的旧模式
g_x           dw 0
g_y           dw 0
g_x1          dw 0
g_y1          dw 0
g_r           dw 0
g_col         db 0
g_px          dw 0            ; 圆：当前 x 偏移
g_py          dw 0            ; 圆：当前 y 偏移
g_d           dw 0            ; 圆/圆填充：误差项或差量
g_dy          dw 0            ; 圆填充：行偏移
g_r2          dw 0            ; 圆填充：半径平方
g_d2          dw 0            ; 圆填充：行偏移平方
g_char        db 0            ; 文本：字符
g_tx          dw 0            ; 文本：x
g_ty          dw 0            ; 文本：y
g_row         dw 0            ; 文本：当前字形行
g_fidx        dw 0            ; 文本：字形字节偏移
g_fseg        dw 0            ; 文本：字形段（BIOS 8x8 字体）
g_foff        dw 0            ; 文本：字形基址偏移

; ============================================================================
;  模式切换
; ============================================================================

; ----------------------------------------------------------------------------
;  fn_gfx_init：进入 VGA13h 图形模式（AH=70）
; ----------------------------------------------------------------------------
fn_gfx_init:
        cmp byte [gfx_on], 0
        jne .already
        ; 记录当前视频模式
        mov ah, 0Fh
        int 10h
        mov [gfx_old_mode], al
        ; 切换 VGA 13h（320x200x256）
        mov ax, 13h
        int 10h
        mov byte [gfx_on], 1
.already:
        clc
        ret

; ----------------------------------------------------------------------------
;  fn_gfx_exit：恢复文本模式（AH=71）
; ----------------------------------------------------------------------------
fn_gfx_exit:
        mov ax, 0003h
        int 10h
        mov byte [gfx_on], 0
        clc
        ret

; ----------------------------------------------------------------------------
;  gfx_terminate：程序终止路径调用——若处于图形模式则恢复文本
; ----------------------------------------------------------------------------
gfx_terminate:
        cmp byte [gfx_on], 0
        je .ret
        push ax bx cx dx es
        mov ax, 0003h
        int 10h
        mov byte [gfx_on], 0
        pop es dx cx bx ax
.ret:
        ret

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

; ----------------------------------------------------------------------------
;  fn_gfx_pal：AH=79 设置调色板（BL=颜色索引, BH=RGB）
;  经 BIOS INT 10h AX=1000h 设置单色调色板寄存器
; ----------------------------------------------------------------------------
fn_gfx_pal:
        mov ax, 1000h
        int 10h
        clc
        ret

; ----------------------------------------------------------------------------
;  fn_gfx_text：AH=7A 图形模式绘制字符（BH=字符, DL=颜色, SI=X, DI=Y）
;  用 BIOS 8x8 点阵字体（INT 10h AX=1130h BH=03h 获取）逐像素着色
; ----------------------------------------------------------------------------
fn_gfx_text:
        cmp byte [gfx_on], 0
        je .err
        ; 保存参数
        mov [g_char], bh
        mov [g_col], dl
        mov [g_tx], si
        mov [g_ty], di
        ; 非法字符不做
        mov al, [g_char]
        cmp al, 20h
        jb .done
        cmp al, 7Fh
        ja .done
        ; 获取 8x8 ASCII ROM 字体：ES:BP
        push es
        mov ax, 1130h
        mov bh, 03h
        int 10h
        mov ax, es
        mov [g_fseg], ax
        mov [g_foff], bp
        pop es
        ; 字形字节偏移 = (char-0x20)*8
        mov al, [g_char]
        sub al, 20h
        xor ah, ah
        mov cx, 8
        mul cx
        mov [g_fidx], ax
        ; 逐行 0..7
        mov word [g_row], 0
.row:
        cmp word [g_row], 8
        jae .finish
        ; 取一个字形行字节
        push es si di
        mov ax, [g_fseg]
        mov es, ax
        mov di, [g_foff]
        add di, [g_fidx]
        add di, [g_row]
        mov bl, [es:di]
        pop di si es
        ; 逐列（位 7..0 为左..右）
        mov cx, 8
.col:
        push cx
        test bl, 80h
        jz .bit0
        ; 该位为前景色
        push ax bx cx dx
        mov ax, 8
        sub ax, cx          ; 列索引 0..7
        add ax, [g_tx]
        mov bx, ax
        mov ax, [g_ty]
        add ax, [g_row]
        mov cx, ax
        mov dl, [g_col]
        call put_pixel
        pop dx cx bx ax
.bit0:
        shl bl, 1
        pop cx
        loop .col
        inc word [g_row]
        jmp .row
.finish:
.done:
        clc
        ret
.err:
        stc
        ret