; ============================================================================
;  字符 I/O 服务
; ============================================================================

; AH=01：读一个字符（带回显），返回 AL
fn_read_char:
        call kbd_read_char
        push ax
        call put_char            ; 回显
        pop ax
        ret

; AH=02：写一个字符（DL）
fn_write_char:
        mov al, dl
        call put_char
        ret

; AH=06：直接控制台 I/O
;   DL=0FFh 读（无键时 AL=0）；否则写 DL
fn_con_io:
        cmp dl, 0FFh
        je .read
        mov al, dl
        call put_char
        ret
.read:
        mov ah, 01h
        int 16h
        jz .none
        xor ah, ah
        int 16h
        ret
.none:
        xor al, al
        ret

; AH=09：输出 $ 结尾字符串（DS:DX，调用者段）
fn_write_string:
        mov es, [caller_ds]
        mov si, dx
.loop:
        mov al, [es:si]
        cmp al, '$'
        je .done
        push si
        call put_char
        pop si
        inc si
        jmp .loop
.done:
        ret

; AH=0A：缓冲输入
;   入口：DS:DX = 缓冲（[0]=最大长度, [1]=实际, [2..]=数据）
fn_buffered_input:
        mov es, [caller_ds]
        mov di, dx
        mov al, [es:di]          ; 调用者最大长度
        mov [line_buf], al
        call read_line
        mov cl, [line_len]
        mov [es:di+1], cl
        mov si, line_data
        xor ch, ch
        add di, 2
        rep movsb
        ret

; AH=0B：检查输入状态，有键 AL=0FFh，无键 AL=0
fn_check_input:
        mov ah, 01h
        int 16h
        jz .none
        mov al, 0FFh
        ret
.none:
        xor al, al
        ret

; AH=0C：清键盘缓冲后按 AL 指定读方式读取
fn_clear_read:
        push ax
.flush:
        mov ah, 01h
        int 16h
        jz .done_flush
        xor ah, ah
        int 16h
        jmp .flush
.done_flush:
        pop ax
        cmp al, 0Ah
        je fn_buffered_input
        jmp fn_read_char

