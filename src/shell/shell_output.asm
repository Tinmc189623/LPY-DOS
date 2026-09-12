; ============================================================================
;  工具函数
; ============================================================================

; ----------------------------------------------------------------------------
;  upper：AL 转大写
; ----------------------------------------------------------------------------
upper:
        cmp al, 'a'
        jb .done
        cmp al, 'z'
        ja .done
        sub al, 20h
.done:
        ret

; ----------------------------------------------------------------------------
;  upper_str：把 [si] 0 结尾字符串转大写
; ----------------------------------------------------------------------------
upper_str:
        push ax si
.loop:
        mov al, [si]
        test al, al
        jz .done
        call upper
        mov [si], al
        inc si
        jmp .loop
.done:
        pop si ax
        ret

; ----------------------------------------------------------------------------
;  strcmp_i：比较 [si] 与 [di]（均 0 结尾，忽略大小写）
;  出口：ZF=1 相等
; ----------------------------------------------------------------------------
strcmp_i:
        push ax bx si di
.loop:
        mov al, [si]
        call upper
        mov ah, al
        mov al, [di]
        call upper
        cmp al, ah
        jne .ne
        test al, al
        jz .eq
        inc si
        inc di
        jmp .loop
.eq:
        pop di si bx ax
        ret                     ; ZF=1
.ne:
        pop di si bx ax
        ret                     ; ZF=0

; ----------------------------------------------------------------------------
;  puts：输出 $ 结尾字符串（AH=09）
;  入口：DS:SI = 字符串
; ----------------------------------------------------------------------------
puts:
        push ax dx
        mov dx, si
        mov ah, 09h
        int 21h
        pop dx ax
        ret

; ----------------------------------------------------------------------------
;  print_logo：用 BIOS 绘制彩色 ASCII "LPY-DOS" 横幅
;  每行以 $ 结尾、末尾 0 结束，水平居中，颜色取 logo_attr；起始行取当前光标
; ----------------------------------------------------------------------------
print_logo:
        push ax bx cx dx si
        mov ah, 03h
        xor bh, bh
        int 10h
        mov byte [logo_base], dh   ; 起始行
        mov byte [logo_row], 0
        lea si, [s_logo]
.next:
        cmp byte [si], 0
        je .fin
        push si
        xor cx, cx
.len:
        cmp byte [si], '$'
        je .len_done
        cmp byte [si], 0        ; 行扫描必须同步识别数据终止符，
        je .len_done            ; 否则末行缺 $ 时会扫穿整块内存
        inc cx
        inc si
        jmp .len
.len_done:
        pop si
        mov ax, 80
        sub ax, cx
        shr ax, 1                    ; 起始列
        mov byte [logo_col], al
.write:
        mov al, [si]
        cmp al, '$'
        je .done_row
        push si
        mov ah, 02h
        mov bh, 0
        mov dh, [logo_base]
        add dh, [logo_row]
        mov dl, [logo_col]
        int 10h                      ; 定位光标
        mov ah, 09h
        mov al, [si]
        mov bl, [logo_attr]
        mov cx, 1
        int 10h                      ; 写字符+属性
        pop si
        inc byte [logo_col]
        inc si
        jmp .write
.done_row:
        inc si
        inc byte [logo_row]
        jmp .next
.fin:
        mov bh, 0
        mov al, [logo_base]
        add al, [logo_row]
        mov dh, al
        xor dl, dl
        mov ah, 02h
        int 10h                      ; 光标移到横幅末行下
        pop si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  print0：输出 0 结尾字符串（AH=02）
;  入口：DS:SI = 字符串
; ----------------------------------------------------------------------------
print0:
        push ax si
.loop:
        lodsb
        test al, al
        jz .done
        mov dl, al
        push ax
        mov ah, 02h
        int 21h
        pop ax
        jmp .loop
.done:
        pop si ax
        ret

; ----------------------------------------------------------------------------
;  putch：输出 DL 字符
; ----------------------------------------------------------------------------
putch:
        push ax
        mov ah, 02h
        int 21h
        pop ax
        ret

; ----------------------------------------------------------------------------
;  print_dec16：输出 AX 无符号十进制（无前导零）
; ----------------------------------------------------------------------------
print_dec16:
        push ax bx cx dx
        mov bx, 10
        xor cx, cx
.div_loop:
        xor dx, dx
        div bx
        push dx
        inc cx
        test ax, ax
        jnz .div_loop
.out_loop:
        pop dx
        add dl, '0'
        call putch
        loop .out_loop
        pop dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  print_dword：输出 DX:AX 32 位无符号十进制
;  用 10 的幂表逐位试减
; ----------------------------------------------------------------------------
print_dword:
        push ax bx cx dx si
        lea si, [pow10]
        mov byte [nonzerop], 0
.p10_loop:
        mov bx, [si]            ; 幂低字
        mov cx, [si+2]          ; 幂高字
        test bx, bx
        jnz .have_pow
        test cx, cx
        jz .done
.have_pow:
        ; 试减：DX:AX 含剩余值
        xor cx, cx              ; cx = 当前位数字
.try_sub:
        cmp dx, [si+2]
        ja .sub
        jb .no_sub
        cmp ax, [si]
        jb .no_sub
.sub:
        sub ax, [si]
        sbb dx, [si+2]
        inc cx
        jmp .try_sub
.no_sub:
        ; 输出该位（跳过前导零）
        cmp byte [nonzerop], 0
        jne .emit
        test cx, cx
        jz .skip
        mov byte [nonzerop], 1
.emit:
        mov al, cl
        add al, '0'
        mov dl, al
        call putch
.skip:
        add si, 4
        jmp .p10_loop
.done:
        cmp byte [nonzerop], 0
        jne .fin
        mov dl, '0'
        call putch
.fin:
        pop si dx cx bx ax
        ret

pow10:
        dd 10000000
        dd 1000000
        dd 100000
        dd 10000
        dd 1000
        dd 100
        dd 10
        dd 1
        dd 0
nonzerop        db 0

; ----------------------------------------------------------------------------
;  print_bin_pad：输出 AL 的十进制，固定 2 位（前导零）
; ----------------------------------------------------------------------------
print_bin_pad:
        push ax bx cx dx
        mov bl, al
        ; 十位
        mov al, bl
        xor ah, ah
        mov cl, 10
        div cl                  ; AL=十位, AH=个位
        mov dl, al
        add dl, '0'
        call putch
        mov dl, ah
        add dl, '0'
        call putch
        pop dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  print_cwd：显示 "A:\当前目录"（驱动器号 + AH=47）
; ----------------------------------------------------------------------------
print_cwd:
        push ax bx cx dx si di es
        ; 驱动器号
        mov ah, 19h
        int 21h
        add al, 'A'
        mov dl, al
        call putch
        mov dl, ':'
        call putch
        ; 当前目录
        lea si, [curpath]
        mov byte [si], 0
        mov dx, 0
        mov ah, 47h
        int 21h
        ; 若无路径则显示 '\'
        cmp byte [curpath], 0
        jne .has
        mov dl, '\'
        call putch
        jmp .done
.has:
        lea si, [curpath]
        call print0
.done:
        pop es di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  print_date：输出 AX 的 DOS 日期字 "MM-DD-YYYY"
; ----------------------------------------------------------------------------
print_date:
        push ax bx cx dx si
        ; 日 = AX & 0x1F
        mov bx, ax
        and bx, 1Fh             ; bx = 日
        ; 月 = (AX>>5) & 0xF
        mov cx, ax
        shr cx, 5
        and cx, 0Fh             ; cx = 月
        ; 年 = (AX>>9) + 1980
        mov si, ax
        shr si, 9
        add si, 1980            ; si = 年
        ; 输出 月-日-年
        mov al, cl
        call print_bin_pad
        mov dl, '-'
        call putch
        mov al, bl
        call print_bin_pad
        mov dl, '-'
        call putch
        mov ax, si
        call print_dec16
        pop si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  print_time：输出 AX 的 DOS 时间字 "HH:MM"
; ----------------------------------------------------------------------------
print_time:
        push ax bx cx dx
        ; 分 = (AX>>5) & 0x3F
        mov cx, ax
        shr cx, 5
        and cx, 3Fh             ; cx = 分
        ; 时 = (AX>>11) & 0x1F
        mov bx, ax
        shr bx, 11
        and bx, 1Fh             ; bx = 时
        mov al, bl
        call print_bin_pad
        mov dl, ':'
        call putch
        mov al, cl
        call print_bin_pad
        pop dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  show_prompt：按 ECHO 状态显示提示符
; ----------------------------------------------------------------------------
show_prompt:
        push ax bx cx dx si
        cmp byte [echo_flag], 0
        je .done
        call print_cwd
        mov dl, '>'
        call putch
.done:
        pop si dx cx bx ax
        ret

; ============================================================================
