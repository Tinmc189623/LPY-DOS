; ============================================================================
;  logo.asm — LPY-DOS 外部 .COM 程序彩色 LOGO 渲染库
;  提供 show_logo（写 0B800h 文本显存居中渲染）与 check_about（about 命令入口）。
;  本文件不单独编译，应由调用方在文件末尾 include 'inc/logo.asm'。
;  依赖调用方定义两个标签：
;    logo_attr  db <文本属性字节>   ; 高4位背景色 + 低4位前景色
;    logo_data  db '<行1>$','<行2>$',...,0  ; $ 结尾多行，末字节 0 结束
;
;  Copyright (C) 2026 Nexsteaduser
; ============================================================================

; ----------------------------------------------------------------------------
;  show_logo：把 DS:SI 指向的 LOGO 数据用 BIOS 彩色写入居中渲染。
;  入口：DS:SI=LOGO 数据，AL=文本属性；出口：光标移到横幅末行下方。
; ----------------------------------------------------------------------------
show_logo:
    push ax bx cx dx
    mov [logo_attr_tmp], al        ; 保存属性
    mov ah, 03h
    mov bh, 0
    int 10h                        ; 取当前光标行到 DH
    mov [logo_cur_row], dh
.next_row:
    push si
    xor cx, cx
.scan:                             ; 查当前行长度（不含 $）
    cmp byte [si], '$'
    je .have
    cmp byte [si], 0
    je .done
    inc si
    inc cx
    jmp .scan
.have:
    mov ax, 80
    sub ax, cx
    shr ax, 1                      ; AX = 起始列
    mov dl, al                     ; DL = 起始列
    pop si                         ; 回到行首
.fill:
    mov cl, [si]
    cmp cl, '$'
    je .row_done
    mov dh, [logo_cur_row]
    push dx
    mov ah, 02h
    mov bh, 0
    int 10h                        ; 光标定位
    mov ah, 09h
    mov al, cl
    mov bl, [logo_attr_tmp]
    mov cx, 1
    int 10h                        ; 写字符+属性
    pop dx
    inc dl
    inc si
    jmp .fill
.row_done:
    inc byte [logo_cur_row]
    inc si                         ; 跳过 '$'
    jmp .next_row
.done:
    pop si                         ; 平衡 next_row 的 push si
    mov bh, 0
    mov dl, 0
    mov dh, [logo_cur_row]
    mov ah, 02h
    int 10h                        ; 光标定位到末行下方
    pop dx cx bx ax
    ret

; ----------------------------------------------------------------------------
;  to_upper：把 AL 中的小写字母转为大写
; ----------------------------------------------------------------------------
to_upper:
    cmp al, 'a'
    jb .done
    cmp al, 'z'
    ja .done
    sub al, 32
.done:
    ret

; ----------------------------------------------------------------------------
;  check_about：命令行首 token 若为 ABOUT（大小写不敏感）则打印 LOGO 并退出。
;  从 PSP+81h 起扫描（不依赖 PSP+80h 长度字节），跳过空白后匹配前 5 字符。
; ----------------------------------------------------------------------------
check_about:
    push ax bx cx si
    mov si, 0081h
    mov cx, 200                    ; 安全扫描上限
.skip_sp:
    cmp byte [si], ' '
    jne .chk
    inc si
    dec cx
    jnz .skip_sp
    jmp .not
.chk:
    cmp byte [si], 0
    je .not
    cmp byte [si], 0Dh
    je .not
    mov di, s_about
    mov ch, 5
.loop:
    mov al, [si]
    call to_upper
    cmp al, [di]
    jne .not
    inc si
    inc di
    dec ch
    jnz .loop
.is:
    pop si cx bx ax
    mov al, [logo_attr]
    mov si, logo_data
    call show_logo
    int 20h                        ; 干净退出
.not:
    pop si cx bx ax
    ret

s_about db 'ABOUT'

logo_cur_row  db 0
logo_attr_tmp db 0