; ============================================================================
;  内建命令实现
; ============================================================================

; ----------------------------------------------------------------------------
;  cmd_dir：列出目录
; ----------------------------------------------------------------------------
cmd_dir:
        push ax bx cx dx si di es
        ; 构造搜索模式
        cmp byte [arg1], 0
        jne .with_arg
        lea si, [star_all]
        jmp .build_done
.with_arg:
        ; 判断是否含通配符
        lea si, [arg1]
.check_wild:
        mov al, [si]
        test al, al
        jz .no_wild
        cmp al, '*'
        je .has_wild
        cmp al, '?'
        je .has_wild
        inc si
        jmp .check_wild
.has_wild:
        lea si, [arg1]
        jmp .build_done
.no_wild:
        ; 目录形式：arg1 + '\' + '*.*'
        lea si, [arg1]
        lea di, [search_mode]
.copy_arg:
        mov al, [si]
        mov [di], al
        inc si
        inc di
        test al, al
        jnz .copy_arg
        dec di
        mov al, '\'
        mov [di], al
        inc di
        lea si, [star_all]
.copy_star:
        mov al, [si]
        mov [di], al
        inc si
        inc di
        test al, al
        jnz .copy_star
        lea si, [search_mode]
.build_done:
        ; 显示 " Directory of A:\路径"
        mov si, s_crlf2
        call puts
        mov si, s_dir_of
        call puts
        call print_cwd
        mov si, s_crlf
        call puts
        ; DTA 指向 PSP:0x80（AH=1A 设置 DTA：DS:DX）
        push ds
        pop es
        mov dx, 80h
        mov ah, 1Ah
        int 21h
        ; 搜索：AH=4E，DS:DX = 模式，CX = 0x10（含目录）
        mov dx, si
        mov cx, 10h
        mov ah, 4Eh
        int 21h
        jc .none
        ; 计数器
        mov word [dir_count], 0
.next:
        ; 解析 DTA（PSP:0x80）
        mov ax, ds
        mov es, ax
        mov si, 80h+1Eh         ; 文件名
        ; 属性
        mov al, [es:80h+15h]
        test al, 10h            ; 目录？
        jz .not_dir
        ; 目录：显示名字 + <DIR>
        call print0
        mov si, s_dir_mark
        call puts
        mov si, s_crlf
        call puts
        jmp .next_file
.not_dir:
        ; 文件：名字 + 大小 + 日期 + 时间
        call print0
        ; 补空格对齐（简化：4 空格）
        mov si, s_space4
        call puts
        ; 大小（DTA+1Ah，32 位）
        mov ax, [es:80h+1Ah]
        mov dx, [es:80h+1Ch]
        call print_dword
        mov si, s_space4
        call puts
        ; 日期（DTA+18h）
        mov ax, [es:80h+18h]
        call print_date
        mov si, s_space4
        call puts
        ; 时间（DTA+16h）
        mov ax, [es:80h+16h]
        call print_time
        mov si, s_crlf
        call puts
.next_file:
        inc word [dir_count]
        ; 继续 AH=4F
        mov ah, 4Fh
        int 21h
        jnc .next
        ; 统计行
        mov si, s_crlf
        call puts
        mov ax, [dir_count]
        call print_dec16
        mov si, s_file_s
        call puts
        jmp .done
.none:
        mov si, s_file_not
        call puts
.done:
        pop es di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  cmd_cd：改变当前目录（无参数显示当前目录）
; ----------------------------------------------------------------------------
cmd_cd:
        push ax bx cx dx si di es
        cmp byte [arg1], 0
        jne .do_chdir
        call print_cwd
        mov si, s_crlf
        call puts
        jmp .done
.do_chdir:
        push ds
        pop es
        lea dx, [arg1]
        mov ah, 3Bh
        int 21h
        jnc .done
        mov si, s_badcmd
        call puts
.done:
        pop es di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  cmd_md：创建目录
; ----------------------------------------------------------------------------
cmd_md:
        push ax bx cx dx si di es
        cmp byte [arg1], 0
        je .err
        push ds
        pop es
        lea dx, [arg1]
        mov ah, 39h
        int 21h
        jnc .done
.err:
        mov si, s_badcmd
        call puts
.done:
        pop es di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  cmd_rd：删除目录
; ----------------------------------------------------------------------------
cmd_rd:
        push ax bx cx dx si di es
        cmp byte [arg1], 0
        je .err
        push ds
        pop es
        lea dx, [arg1]
        mov ah, 3Ah
        int 21h
        jnc .done
.err:
        mov si, s_badcmd
        call puts
.done:
        pop es di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  cmd_del：删除文件
; ----------------------------------------------------------------------------
cmd_del:
        push ax bx cx dx si di es
        cmp byte [arg1], 0
        je .err
        push ds
        pop es
        lea dx, [arg1]
        mov ah, 41h
        int 21h
        jnc .done
.err:
        mov si, s_file_not
        call puts
.done:
        pop es di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  cmd_ren：重命名
; ----------------------------------------------------------------------------
cmd_ren:
        push ax bx cx dx si di es
        cmp byte [arg1], 0
        je .err
        cmp byte [arg2], 0
        je .err
        push ds
        pop es
        lea dx, [arg1]
        lea di, [arg2]
        mov ah, 56h
        int 21h
        jnc .done
.err:
        mov si, s_badcmd
        call puts
.done:
        pop es di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  cmd_type：显示文本文件
; ----------------------------------------------------------------------------
cmd_type:
        push ax bx cx dx si di es
        cmp byte [arg1], 0
        je .err
        ; 打开文件
        push ds
        pop es
        lea dx, [arg1]
        mov ax, 3D00h           ; 只读
        int 21h
        jc .err
        mov bx, ax              ; 句柄
.read_loop:
        ; 读 512 字节
        mov ah, 3Fh
        mov cx, BUF512
        lea dx, [copy_buf]
        int 21h
        jc .close_err
        test ax, ax
        jz .close_ok
        ; 逐字节输出
        mov cx, ax
        lea si, [copy_buf]
.put_loop:
        lodsb
        push cx
        mov dl, al
        mov ah, 02h
        int 21h
        pop cx
        loop .put_loop
        jmp .read_loop
.close_ok:
        mov ah, 3Eh
        int 21h
        jmp .done
.close_err:
        mov ah, 3Eh
        int 21h
        jmp .err
.err:
        mov si, s_file_not
        call puts
.done:
        pop es di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  cmd_copy：复制文件
; ----------------------------------------------------------------------------
cmd_copy:
        push ax bx cx dx si di es
        cmp byte [arg1], 0
        je .err
        cmp byte [arg2], 0
        je .err
        ; 打开源
        push ds
        pop es
        lea dx, [arg1]
        mov ax, 3D00h
        int 21h
        jc .err
        mov si, ax              ; 源句柄
        ; 创建目标
        lea dx, [arg2]
        mov ah, 3Ch
        mov cx, 0
        int 21h
        jc .close_src_err
        mov di, ax              ; 目标句柄
.copy_loop:
        ; 读源
        mov bx, si
        mov ah, 3Fh
        mov cx, BUF512
        lea dx, [copy_buf]
        int 21h
        jc .close_err
        test ax, ax
        jz .copied
        ; 写目标
        mov cx, ax
        mov bx, di
        mov ah, 40h
        lea dx, [copy_buf]
        int 21h
        jc .close_err
        jmp .copy_loop
.copied:
        ; 关闭两文件
        mov bx, di
        mov ah, 3Eh
        int 21h
        mov bx, si
        mov ah, 3Eh
        int 21h
        mov si, s_copy_ok
        call puts
        jmp .done
.close_err:
        mov bx, di
        mov ah, 3Eh
        int 21h
.close_src_err:
        mov bx, si
        mov ah, 3Eh
        int 21h
.err:
        mov si, s_badcmd
        call puts
.done:
        pop es di si dx cx bx ax
        ret

