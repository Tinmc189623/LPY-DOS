; ============================================================================
;  numeric.inc — LPY-DOS SDK 数字子程序
;  数字打印、十进制字符串解析、缓冲输入。
;  本库 LOGO：num_logo_print（见 logo.inc）
; ============================================================================
include 'logo.inc'

; ----------------------------------------------------------------------------
;  put_dec16：输出 AX 无符号十进制（无前导零）
; ----------------------------------------------------------------------------
put_dec16:
    push ax bx cx dx
    mov bx, 10
    xor cx, cx
.div:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .div
.out:
    pop dx
    add dl, '0'
    call putc
    loop .out
    pop dx cx bx ax
    ret

; ----------------------------------------------------------------------------
;  put_hex16：输出 AX 十六进制（固定 4 位，大写）
; ----------------------------------------------------------------------------
put_hex16:
    push ax bx cx dx
    mov cx, 4
    mov bx, ax
.h:
    rol bx, 4
    mov ax, bx
    and al, 0Fh
    cmp al, 10
    jb .digit
    add al, 'A'-10
    jmp .out
.digit:
    add al, '0'
.out:
    mov dl, al
    call putc
    loop .h
    pop dx cx bx ax
    ret

; ----------------------------------------------------------------------------
;  put_hex8：输出 AL 十六进制（固定 2 位，大写）
; ----------------------------------------------------------------------------
put_hex8:
    push ax bx
    mov bl, al
    shr al, 4
    call .one
    mov al, bl
    and al, 0Fh
    call .one
    pop bx ax
    ret
.one:
    cmp al, 10
    jb .d
    add al, 'A'-10
    jmp .o
.d:
    add al, '0'
.o:
    mov dl, al
    call putc
    ret

; ----------------------------------------------------------------------------
;  atoi_dec：把 DS:SI 处十进制字符串 → AX
;  边界：最大 65535；遇非数字字符结束
; ----------------------------------------------------------------------------
atoi_dec:
    push bx cx dx si
    xor ax, ax
    mov bx, 10
.loop:
    mov cl, [si]
    cmp cl, '0'
    jb .done
    cmp cl, '9'
    ja .done
    xor ch, ch
    and cl, 0Fh
    mul bx
    add ax, cx
    inc si
    jmp .loop
.done:
    pop si dx cx bx
    ret

; 共享输入缓冲（供 read_num 使用）
num_buf:
    db 8                    ; 最大长度
    db 0                    ; 实际长度（由 AH=0A 填充）
    db 8 dup(0)

; ----------------------------------------------------------------------------
;  read_num：打印 DS:DX 提示后读入一个无符号十进制数 → AX
; ----------------------------------------------------------------------------
read_num:
    push ax cx si dx
    mov ah, AH_WRITE_MSG
    int 21h
    lea dx, [num_buf]
    mov ah, AH_READ_LINE
    int 21h
    call crlf
    lea si, [num_buf+2]
    call atoi_dec
    pop dx si cx ax
    ret