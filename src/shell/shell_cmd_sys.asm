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
        mov bl, dl              ; 暂存“日”（DL 稍后会被分隔符覆盖）
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
        mov al, bl
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
        call print_logo
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

