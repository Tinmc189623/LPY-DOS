; ============================================================================
;  主循环
; ============================================================================
main:
        call print_logo
        mov si, s_ver
        call puts
main_loop:
        call show_prompt
        call read_cmd           ; 读一行到 cmdline
        call parse_cmd          ; 解析 cmd_name/arg1/arg2
        call dispatch
        jmp main_loop

; ----------------------------------------------------------------------------
;  read_cmd：用 AH=0A 读一行，拷贝到 cmdline（0 结尾）
; ----------------------------------------------------------------------------
read_cmd:
        push ax bx cx dx si di
        mov dx, rbuf
        mov ah, 0Ah
        int 21h
        ; 实际长度 = rbuf_len，数据从 rbuf_data
        mov cl, [rbuf_len]
        xor ch, ch
        lea si, [rbuf_data]
        lea di, [cmdline]
        mov byte [cmdline], 0
        mov [cmdline_len], cx
        test cx, cx
        jz .done
        rep movsb
        mov byte [di], 0
.done:
        pop di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  parse_cmd：从 cmdline 依次取 cmd_name、arg1、arg2（均 0 结尾）
; ----------------------------------------------------------------------------
parse_cmd:
        push ax bx cx dx si di
        lea si, [cmdline]
        ; 命令名
        lea di, [cmd_name]
        call get_token
        call upper_str
        ; 参数 1
        lea di, [arg1]
        call get_token
        ; 参数 2
        lea di, [arg2]
        call get_token
        pop di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  get_token：从 [si] 取一个 token 到 [di]（0 结尾）
;  入口：DS:SI = 待解析串；出口：SI 指向下一 token 起点，DI 写入 token
;  分隔符：空格/Tab；跳过前导分隔符
; ----------------------------------------------------------------------------
get_token:
        push ax
        mov byte [di], 0
.skip:
        mov al, [si]
        cmp al, ' '
        je .adv
        cmp al, 9
        je .adv
        cmp al, 0
        je .done
        jmp .copy
.adv:
        inc si
        jmp .skip
.copy:
        mov al, [si]
        cmp al, ' '
        je .end
        cmp al, 9
        je .end
        cmp al, 0
        je .end
        mov [di], al
        inc si
        inc di
        jmp .copy
.end:
        mov byte [di], 0
.skip_sep:
        mov al, [si]
        cmp al, ' '
        je .adv2
        cmp al, 9
        je .adv2
        jmp .done
.adv2:
        inc si
        jmp .skip_sep
.done:
        pop ax
        ret

