; ============================================================================
;  内部工具：字符输出 / 键盘输入 / 字符串输出 / BCD 转换
; ============================================================================

; ----------------------------------------------------------------------------
;  put_char：向屏幕输出一个字符
;  入口：AL = 字符
;  说明：QEMU 的 VGABIOS teletype（AH=0Eh）不遵守 BIOS 约定，实测会破坏
;        CX/SI/DX。调用方（print_dec16 的 loop、print_str 的 lodsb 循环）
;        依赖这些寄存器跨调用存活，故在此统一保存全部现场。
; ----------------------------------------------------------------------------
put_char:
        push ax bx cx dx si di bp
        push ds es
        mov ah, 0Eh
        mov bx, 0007h
        int 10h
        pop es ds
        pop bp di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  kbd_read_char：从键盘读取一个字符（阻塞）
;  出口：AL = 字符；若是扩展键则 AL = 0
; ----------------------------------------------------------------------------
kbd_read_char:
        xor ah, ah
        int 16h
        test al, al
        jnz .done
        ; 扩展键：丢弃第二字节，返回 0
        xor ah, ah
        int 16h
        xor al, al
.done:
        ret

; ----------------------------------------------------------------------------
;  print_str：输出以 0 结尾的字符串（内核段内使用）
;  入口：DS:SI = 字符串
; ----------------------------------------------------------------------------
print_str:
        push ax
        push si
.loop:
        lodsb
        test al, al
        jz .done
        call put_char
        jmp .loop
.done:
        pop si
        pop ax
        ret

; ----------------------------------------------------------------------------
;  read_line：从键盘读入一行到 line_data（line_buf[0] 为最大长度）
;  支持退格、Enter、Ctrl-C；行数据以 0 结尾；line_len 保存实际长度
; ----------------------------------------------------------------------------
read_line:
        push ax bx cx dx si di
        mov byte [line_len], 0
        mov si, line_data
        mov bl, [line_buf]
        xor bh, bh
.loop:
        call kbd_read_char
        cmp al, 0Dh             ; Enter
        je .done
        cmp al, 08h             ; Backspace
        je .bs
        cmp al, 03h             ; Ctrl-C
        je .ctrlc
        cmp al, 1Bh             ; ESC
        je .ctrlc
        cmp al, ' '
        jb .loop                ; 其他控制字符忽略
        mov cl, [line_len]
        cmp cl, [line_buf]
        jae .loop               ; 已满则忽略
        mov [si], al
        inc si
        inc byte [line_len]
        call put_char
        jmp .loop
.bs:
        cmp byte [line_len], 0
        je .loop
        dec si
        dec byte [line_len]
        mov al, 08h
        call put_char
        mov al, ' '
        call put_char
        mov al, 08h
        call put_char
        jmp .loop
.ctrlc:
        mov al, '^'             ; 打印 ^C
        call put_char
        mov al, 'C'
        call put_char
        mov byte [line_len], 0
        mov si, line_data
        jmp .loop
.done:
        mov al, 0Dh
        call put_char
        mov al, 0Ah
        call put_char
        mov byte [si], 0
        pop di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  upper：将 AL 转为大写字母
;  入口：AL = 字符；出口：AL = 大写形式（非字母不变）
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
;  bcd_to_bin：BCD 码转二进制
;  入口：AL = BCD；出口：AL = 二进制
; ----------------------------------------------------------------------------
bcd_to_bin:
        push bx cx
        mov bl, al
        and bl, 0Fh              ; 低位
        mov cl, al
        shr cl, 4                ; 高位
        mov al, cl
        mov cl, 10
        mul cl                   ; ax = 高位 * 10
        add al, bl
        pop cx bx
        ret

