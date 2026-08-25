; ============================================================================
;  LPY-DOS 命令解释器 LPYCMD.COM
;  对标 MS-DOS 的 COMMAND.COM：内建命令 + 外部 .COM 程序执行
;
;  编译：fasm shell.asm LPYCMD.COM
;  运行：由内核 reshell 加载，DS=ES=SS=PSP 段，入口 org 100h
;
;  Copyright (C) 2026 Nexlyh
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
; ============================================================================

use16
org 100h

start:
        jmp main

; ----------------------------------------------------------------------------
;  常量
; ----------------------------------------------------------------------------
MAXLINE         equ 120         ; 命令行最大长度
BUF512          equ 512         ; COPY/TYPE 传输缓冲

; ----------------------------------------------------------------------------
;  数据区
; ----------------------------------------------------------------------------
echo_flag       db 1            ; 1=显示提示符（ECHO ON）
rbuf            db MAXLINE      ; AH=0A 缓冲：最大长度
rbuf_len        db 0            ; 实际长度
rbuf_data       db MAXLINE dup(0)
cmdline         db MAXLINE dup(0) ; 命令行（0 结尾）
cmd_name        db 16 dup(0)    ; 命令名（大写）
arg1            db MAXLINE dup(0)
arg2            db MAXLINE dup(0)
curpath         db 80 dup(0)    ; 当前目录串（AH=47）
search_mode     db MAXLINE dup(0) ; DIR 搜索模式
exec_path       db MAXLINE dup(0) ; 外部命令路径
copy_buf        db BUF512 dup(0)  ; COPY/TYPE 传输缓冲

; 错误/提示字符串（$ 结尾，供 AH=09）
s_crlf          db 0Dh,0Ah,'$'
s_prompt_drv    db 'A:$'        ; 盘符前缀（'A' 占位）
s_prompt_end    db '>$'
s_badcmd        db 'Bad command or file name',0Dh,0Ah,'$'
s_file_not      db 'File not found',0Dh,0Ah,'$'
s_dir_of        db ' Directory of $'
s_file_s        db ' file(s)',0Dh,0Ah,'$'
s_bytes_s       db ' bytes',0Dh,0Ah,'$'
s_copy_ok       db '        1 file(s) copied',0Dh,0Ah,'$'
s_dir_mark      db '<DIR>   $'
s_space4        db '    $'
s_crlf2         db 0Dh,0Ah,0Dh,0Ah,'$'
s_curdate       db 'Current date is $'
s_curtime       db 'Current time is $'
s_ver           db 'LPY-DOS Version 1.0.0',0Dh,0Ah
                db 'Copyright (C) 2026 Nexlyh',0Dh,0Ah
                db 'GNU GPL v3 or later',0Dh,0Ah,'$'

s_help          db 'LPY-DOS internal commands:',0Dh,0Ah
                db '  DIR     List directory',0Dh,0Ah
                db '  CD/CHDIR  Change directory',0Dh,0Ah
                db '  MD/MKDIR Make directory',0Dh,0Ah
                db '  RD/RMDIR Remove directory',0Dh,0Ah
                db '  DEL/ERASE  Delete file',0Dh,0Ah
                db '  REN/RENAME Rename file',0Dh,0Ah
                db '  TYPE    Display text file',0Dh,0Ah
                db '  COPY    Copy file',0Dh,0Ah
                db '  CLS     Clear screen',0Dh,0Ah
                db '  VER     Show version',0Dh,0Ah
                db '  DATE/TIME  Show date/time',0Dh,0Ah
                db '  ECHO    Toggle prompt',0Dh,0Ah
                db '  EXIT    Terminate shell',0Dh,0Ah
                db 'Other .COM programs can be run directly.',0Dh,0Ah,'$'

; ============================================================================
;  命令表：12 字节名字（0 结尾对齐）+ 2 字节处理例程
; ============================================================================
cmd_table:
        db 'DIR',0
        rb 12-4
        dw cmd_dir
        db 'CD',0
        rb 12-3
        dw cmd_cd
        db 'CHDIR',0
        rb 12-6
        dw cmd_cd
        db 'MD',0
        rb 12-3
        dw cmd_md
        db 'MKDIR',0
        rb 12-6
        dw cmd_md
        db 'RD',0
        rb 12-3
        dw cmd_rd
        db 'RMDIR',0
        rb 12-6
        dw cmd_rd
        db 'DEL',0
        rb 12-4
        dw cmd_del
        db 'ERASE',0
        rb 12-6
        dw cmd_del
        db 'REN',0
        rb 12-4
        dw cmd_ren
        db 'RENAME',0
        rb 12-7
        dw cmd_ren
        db 'TYPE',0
        rb 12-5
        dw cmd_type
        db 'COPY',0
        rb 12-5
        dw cmd_copy
        db 'CLS',0
        rb 12-4
        dw cmd_cls
        db 'VER',0
        rb 12-4
        dw cmd_ver
        db 'DATE',0
        rb 12-5
        dw cmd_date
        db 'TIME',0
        rb 12-5
        dw cmd_time
        db 'ECHO',0
        rb 12-5
        dw cmd_echo
        db 'HELP',0
        rb 12-5
        dw cmd_help
        db 'REM',0
        rb 12-4
        dw cmd_rem
        db 'EXIT',0
        rb 12-5
        dw cmd_exit
        db 0                    ; 表尾

; ============================================================================
;  主循环
; ============================================================================
main:
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

; ============================================================================
;  命令分发
; ============================================================================
dispatch:
        push ax bx si di
        lea si, [cmd_table]
.find:
        cmp byte [si], 0        ; 表尾
        je .external
        lea di, [cmd_name]
        push si
        call strcmp_i
        pop si
        je .found
        add si, 14
        jmp .find
.found:
        mov bx, [si+12]
        pop di si bx ax
        call bx                 ; 调用命令处理
        jmp dispatch_done
.external:
        pop di si bx ax
        call exec_external
dispatch_done:
        ret

; ============================================================================
;  exec_external：尝试把 arg1 作为 .COM 程序执行（AH=4B AL=0）
; ============================================================================
exec_external:
        push ax bx cx dx si di es
        ; 无参数则报错
        cmp byte [arg1], 0
        je .bad
        ; 拷贝 arg1 到 exec_path，并记录是否含 '.'
        lea si, [arg1]
        lea di, [exec_path]
        xor bx, bx              ; bx = 0：无扩展名
.copy:
        mov al, [si]
        mov [di], al
        test al, al
        jz .copied
        cmp al, '.'
        jne .nextc
        mov bx, 1
.nextc:
        inc si
        inc di
        jmp .copy
.copied:
        test bx, bx
        jnz .do_exec
        ; 无扩展名：追加 ".COM"
        mov byte [di], '.'
        inc di
        mov byte [di], 'C'
        inc di
        mov byte [di], 'O'
        inc di
        mov byte [di], 'M'
        inc di
        mov byte [di], 0
.do_exec:
        ; 执行：AH=4B AL=0，DS:DX = 路径
        push ds
        pop es
        lea dx, [exec_path]
        mov ax, 4B00h
        int 21h
        jnc .done
.bad:
        mov si, s_badcmd
        call puts
.done:
        pop es di si dx cx bx ax
        ret

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

; ----------------------------------------------------------------------------
;  cmd_cls：清屏
; ----------------------------------------------------------------------------
cmd_cls:
        push ax bx cx dx
        mov ax, 0600h
        mov bh, 07h
        xor cx, cx
        mov dx, 184Fh
        int 10h
        xor bh, bh
        mov ah, 02h
        xor dx, dx
        int 10h
        pop dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  cmd_ver：版本
; ----------------------------------------------------------------------------
cmd_ver:
        push ax si
        mov si, s_ver
        call puts
        pop si ax
        ret

; ----------------------------------------------------------------------------
;  cmd_date：显示当前日期（AH=2A）
; ----------------------------------------------------------------------------
cmd_date:
        push ax bx cx dx si
        mov si, s_curdate
        call puts
        mov ah, 2Ah
        int 21h
        ; CX=年, DH=月, DL=日
        ; 年
        mov ax, cx
        call print_dec16
        mov dl, '-'
        call putch
        ; 月（前导零）
        mov al, dh
        call print_bin_pad
        mov dl, '-'
        call putch
        ; 日（前导零）
        mov al, dl
        call print_bin_pad
        mov si, s_crlf
        call puts
        pop si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  cmd_time：显示当前时间（AH=2C）
; ----------------------------------------------------------------------------
cmd_time:
        push ax bx cx dx si
        mov si, s_curtime
        call puts
        mov ah, 2Ch
        int 21h
        ; CH=时, CL=分, DH=秒, DL=百分秒
        mov al, ch
        call print_bin_pad
        mov dl, ':'
        call putch
        mov al, cl
        call print_bin_pad
        mov dl, ':'
        call putch
        mov al, dh
        call print_bin_pad
        mov si, s_crlf
        call puts
        pop si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  cmd_echo：ECHO ON / ECHO OFF / ECHO 文本
; ----------------------------------------------------------------------------
cmd_echo:
        push ax bx si
        ; 无参数：显示当前状态
        cmp byte [arg1], 0
        jne .has_arg
        cmp byte [echo_flag], 0
        je .off_state
        mov si, s_echo_on
        call puts
        jmp .done
.off_state:
        mov si, s_echo_off
        call puts
        jmp .done
.has_arg:
        ; 比较 OFF
        lea si, [arg1]
        cmp byte [si], 'O'
        jne .maybe_on
        cmp byte [si+1], 'F'
        jne .maybe_on
        cmp byte [si+2], 'F'
        jne .maybe_on
        mov byte [echo_flag], 0
        jmp .done
.maybe_on:
        cmp byte [si], 'O'
        jne .print_text
        cmp byte [si+1], 'N'
        jne .print_text
        mov byte [echo_flag], 1
        jmp .done
.print_text:
        call print0
        mov si, s_crlf
        call puts
.done:
        pop si bx ax
        ret

; ----------------------------------------------------------------------------
;  cmd_help：帮助
; ----------------------------------------------------------------------------
cmd_help:
        push ax si
        mov si, s_help
        call puts
        pop si ax
        ret

; ----------------------------------------------------------------------------
;  cmd_rem：注释，忽略
; ----------------------------------------------------------------------------
cmd_rem:
        ret

; ----------------------------------------------------------------------------
;  cmd_exit：退出 shell（AH=4C）
; ----------------------------------------------------------------------------
cmd_exit:
        mov al, 0
        mov ah, 4Ch
        int 21h

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
;  数据
; ============================================================================
star_all        db '*.*',0
cmdline_len     dw 0
dir_count       dw 0
s_echo_on       db 'ECHO is on',0Dh,0Ah,'$'
s_echo_off      db 'ECHO is off',0Dh,0Ah,'$'
