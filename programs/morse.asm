use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  morse.com — 把一行文本转成摩尔斯电码输出并发声
;  点 '.' 短音，划 '-' 长音
; ============================================================================
start:
    puts s_prompt
    lea dx, [inbuf]
    mov ah, 0Ah
    int 21h
    call crlf
    puts s_out
    mov cl, [inbuf+1]
    xor ch, ch              ; 字符数
    lea si, [inbuf+2]
.loop:
    lodsb
    ; 转大写字母
    cmp al, 'a'
    jb .up
    cmp al, 'z'
    ja .up
    sub al, 20h
    jmp .have
.up:
    cmp al, 'A'
    jb .space
    cmp al, 'Z'
    ja .space
.have:
    ; 索引 = AL - 'A'
    sub al, 'A'
    xor ah, ah
    lea bx, [mor_tab]
    shl ax, 1
    shl ax, 1               ; *4
    add bx, ax
    ; 逐个符号输出并发声
.code:
    mov dl, [bx]
    test dl, dl
    jz .emit_spc
    ; 输出 '.' 或 '-'
    mov al, dl
    mov ah, 02h
    int 21h
    putch ' '
    ; 发声：点为 1 滴答，划为 2 滴答
    cmp dl, '.'
    jne .dash
    mov cx, 1
    jmp .beep
.dash:
    mov cx, 2
.beep:
    call beep
    inc bx
    jmp .code
.emit_spc:
    ; 字母间多一个空格
    putch ' '
    dec cx
    jnz .loop
    jmp .done
.space:
    ; 空格：输出 '/' 分界
    mov dl, '/'
    mov ah, 02h
    int 21h
    putch ' '
    dec cx
    jnz .loop
.done:
    call crlf
    int 20h

; ----------------------------------------------------------------------------
;  beep：以 1000Hz 蜂鸣 CX 个滴答
; ----------------------------------------------------------------------------
beep:
    push ax dx
    in al, 61h
    or al, 3
    out 61h, al
    mov al, 0B6h
    out 43h, al
    mov ax, 1193           ; 1193182/1000
    out 42h, al
    mov al, ah
    out 42h, al
    call delay_ticks
    in al, 61h
    and al, 0FCh
    out 61h, al
    pop dx ax
    ret

s_prompt db 'Enter text: $'
s_out    db 'Morse: $'
inbuf    db 128
         db 0
         db 128 dup(0)
; 摩尔斯码表，每项 4 字节（'.' / '-' / 0）
mor_tab db '.','-',0,0       ; A
        db '-','.','.','.'   ; B
        db '-','.','-','.'   ; C
        db '-','.','.',0     ; D
        db '.',0,0,0         ; E
        db '.','.','-','.'   ; F
        db '-','-','.',0     ; G
        db '.','.','.','.'   ; H
        db '.','.',0,0       ; I
        db '.','-','-','-'   ; J
        db '-','.','-',0     ; K
        db '.','-','.','.'   ; L
        db '-','-',0,0       ; M
        db '-','.',0,0       ; N
        db '-','-','-',0     ; O
        db '.','-','-','.'   ; P
        db '-','-','.','-'   ; Q
        db '.','-','.',0     ; R
        db '.','.','.',0     ; S
        db '-',0,0,0         ; T
        db '.','.','-',0     ; U
        db '.','.','.','-'   ; V
        db '.','-','-',0     ; W
        db '-','.','.','-'   ; X
        db '-','.','-','-'   ; Y
        db '-','-','.','.'   ; Z

include 'inc/std.asm'