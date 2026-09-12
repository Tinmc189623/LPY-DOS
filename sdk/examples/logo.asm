; ============================================================================
;  logo.asm — LPY-DOS SDK LOGO 展示示例
;  用命令行参数指定要打印的库 LOGO：
;     logo lpydos | conio | fs | numeric | sysinfo
;  将对应 ASCII 横幅（带颜色属性）居中渲染到文本显存。
;  编译：fasm logo.asm logo.COM
;  Copyright (C) 2026 Nexsteaduser
;  Licensed under GPL v3 or later.
; ============================================================================
use16
org 0100h

include '../include/lpydos.inc'

start:
    lea si, [token_buf]
    call parse_token            ; 取命令行参数并转大写

    lea si, [token_buf]
    lea di, [s_lpydos]
    call strcmpeq
    jz .lpy
    lea di, [s_conio]
    call strcmpeq
    jz .conio
    lea di, [s_fs]
    call strcmpeq
    jz .fs
    lea di, [s_numeric]
    call strcmpeq
    jz .numeric
    lea di, [s_sysinfo]
    call strcmpeq
    jz .sysinfo

    lea dx, [msg_usage]
    call puts_str
    call crlf
    mov ah, AH_TERM_CD
    mov al, 1
    int 21h

.lpy:
    call lpy_logo_print
    jmp done_ok
.conio:
    call conio_logo_print
    jmp done_ok
.fs:
    call fs_logo_print
    jmp done_ok
.numeric:
    call num_logo_print
    jmp done_ok
.sysinfo:
    call sys_logo_print
    jmp done_ok

done_ok:
    call crlf
    mov ah, AH_TERM_CD
    xor al, al
    int 21h

; ----------------------------------------------------------------------------
;  parse_token：把 DS:0081h 的命令行首个词（至空白）复制到 DS:SI 并转大写
; ----------------------------------------------------------------------------
parse_token:
    push ax si di
    mov di, 0081h
.loop:
    mov al, [di]
    cmp al, ' '
    jbe .done
    cmp al, 'a'
    jb .keep
    cmp al, 'z'
    ja .keep
    sub al, 32
.keep:
    mov [si], al
    inc si
    inc di
    jmp .loop
.done:
    mov byte [si], 0
    pop di si ax
    ret

; ----------------------------------------------------------------------------
;  strcmpeq：比较 DS:SI 与 DS:DI（均 0 结尾字符串）；相等则 ZF=1
; ----------------------------------------------------------------------------
strcmpeq:
.loop:
    mov al, [si]
    cmp al, [di]
    jne .ne
    test al, al
    jz .eq
    inc si
    inc di
    jmp .loop
.eq:
    ret
.ne:
    ret

; ---------------- 只读数据 ----------------
msg_usage db '用法: logo <lpydos|conio|fs|numeric|sysinfo>',0Dh,0Ah,'$'
s_lpydos  db 'LPYDOS',0
s_conio   db 'CONIO',0
s_fs      db 'FS',0
s_numeric db 'NUMERIC',0
s_sysinfo db 'SYSINFO',0

; ---------------- 可变数据 ----------------
token_buf db 16 dup(0)