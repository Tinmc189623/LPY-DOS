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