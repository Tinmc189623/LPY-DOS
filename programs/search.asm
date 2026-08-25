use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  search.com — 在文件中统计指定字符串的出现次数
;  用法：SEARCH <文件名> <关键字>
; ============================================================================
start:
    lea di, [fname]
    mov bl, 1
    call get_cmd_arg
    jc .usage
    lea di, [kw]
    mov bl, 2
    call get_cmd_arg
    jc .usage
    ; 关键字长度
    lea si, [kw]
    call strlen
    mov [kwlen], cx
    test cx, cx
    jz .usage
    ; 打开文件
    lea dx, [fname]
    mov ax, 3D00h
    int 21h
    jc .err
    mov bx, ax
    ; 一次性读入缓冲（文件需小于 4096 字节）
    mov ah, 3Fh
    mov cx, 4096
    lea dx, [buf]
    int 21h
    jc .close_err
    mov [dlen], ax
    mov ah, 3Eh
    int 21h
    ; 从位置 0 开始扫描
    mov word [cnt], 0
    mov word [i], 0
.scan:
    ; 终止条件：i + kwlen > dlen
    mov ax, [i]
    add ax, [kwlen]
    cmp ax, [dlen]
    ja .done
    ; 逐字节比较 buf[i..] 与 kw
    mov bx, [i]
    lea si, [buf]
    add si, bx
    lea di, [kw]
    mov cx, [kwlen]
.cmpb:
    mov al, [si]
    cmp al, [di]
    jne .notmatch
    inc si
    inc di
    loop .cmpb
    ; 完全匹配
    inc word [cnt]
.notmatch:
    inc word [i]
    jmp .scan
.done:
    puts s_out
    mov ax, [cnt]
    call print_dec16
    puts s_times
    call crlf
    int 20h

.usage:
    puts s_usage
    int 20h

.err:
.close_err:
    puts s_err
    int 20h

; ----------------------------------------------------------------------------
;  strlen：DS:SI 的 0 结尾字符串长度 → CX
; ----------------------------------------------------------------------------
strlen:
    xor cx, cx
.loop:
    cmp byte [si], 0
    je .done
    inc si
    inc cx
    jmp .loop
.done:
    ret

s_usage db 'Usage: SEARCH <file> <keyword>$'
s_out   db 'Found: $'
s_times db ' time(s).', 0Dh, 0Ah, '$'
s_err   db 'Cannot open file.', 0Dh, 0Ah, '$'
fname   db 64 dup(0)
kw      db 64 dup(0)
buf     db 4096 dup(0)
kwlen   dw 0
dlen    dw 0
cnt     dw 0
i       dw 0

include 'inc/std.asm'