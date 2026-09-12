; ============================================================================
;  exec_external：尝试把 cmd_name 作为 .COM 程序执行（AH=4B AL=0）
; ============================================================================
exec_external:
        push ax bx cx dx si di es
        ; 无命令名则报错
        cmp byte [cmd_name], 0
        je .bad
        ; 拷贝 cmd_name（命令字本身）到 exec_path，并记录是否含 '.'
        lea si, [cmd_name]
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
        ; 构造 EXEC 命令行尾部并设置参数块命令段
        call build_exec_tail
        mov [exec_pb+4], ds      ; 命令段 = 本程序段
        push ds
        pop es
        lea dx, [exec_path]
        mov bx, exec_pb
        mov ax, 4B00h
        int 21h
        jnc .done
.bad:
        mov si, s_badcmd
        call puts
.done:
        pop es di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  build_exec_tail：把 arg1/arg2 拼成 " 参数..." 命令尾部放入 exec_tail
;  出口：exec_tail[0]=长度，数据后以 0Dh 结尾
; ----------------------------------------------------------------------------
build_exec_tail:
        push ax si di bx
        lea di, [exec_tail+1]    ; 数据起点
        xor bx, bx               ; 长度
        lea si, [arg1]
        cmp byte [si], 0
        je .arg2
        mov byte [di], ' '
        inc di
        inc bx
.cp1:
        mov al, [si]
        test al, al
        jz .arg2
        mov [di], al
        inc di
        inc bx
        inc si
        jmp .cp1
.arg2:
        lea si, [arg2]
        cmp byte [si], 0
        je .done
        mov byte [di], ' '
        inc di
        inc bx
.cp2:
        mov al, [si]
        test al, al
        jz .done
        mov [di], al
        inc di
        inc bx
        inc si
        jmp .cp2
.done:
        mov byte [exec_tail], bl
        mov byte [di], 0Dh       ; 回车
        pop bx di si ax
        ret

