use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  caesar.com — 凯撒移位：输入文本与位移量，输出加密/解密结果
; ============================================================================
start:
    puts s_txt
    lea dx, [inbuf]
    mov ah, 0Ah
    int 21h
    call crlf
    mov dx, s_shift
    call read_num           ; 位移量 AX
    mov cx, 26
    xor dx, dx
    div cx
    mov [k], dl             ; 归一化为 0..25
    puts s_out
    mov cl, [inbuf+1]
    xor ch, ch              ; cx = 剩余字符数
    lea si, [inbuf+2]
.loop:
    test cx, cx
    jz .done
    mov al, [si]
    ; 分类处理
    cmp al, 'A'
    jb .emit                ; 小于 A 的（数字/标点）原样
    cmp al, 'Z'
    jbe .upper
    cmp al, 'a'
    jb .emit                ; 介于 Z 与 a 之间
    cmp al, 'z'
    ja .emit
    ; 小写字母
    sub al, 'a'
    call shift_letter
    add al, 'a'
    jmp .emit
.upper:
    sub al, 'A'
    call shift_letter
    add al, 'A'
.emit:
    mov dl, al
    mov ah, 02h
    int 21h
    inc si
    dec cx
    jmp .loop
.done:
    call crlf
    int 20h

; ----------------------------------------------------------------------------
;  shift_letter：AL = 字母序号(0..25)，加 [k] 后取模 26 返回
;  注意：不触碰 CX 与 SI，供外层循环安全使用
; ----------------------------------------------------------------------------
shift_letter:
    xor ah, ah
    mov bl, [k]
    xor bh, bh
    add ax, bx              ; 序号 + 位移
    mov bl, 26
    xor dx, dx
    div bx                  ; 余数 -> DL
    mov al, dl
    ret

s_txt   db 'Enter text: $'
s_shift db 'Shift amount: $'
s_out   db 'Result: $'
k       db 0
inbuf   db 128
        db 0
        db 128 dup(0)

include 'inc/std.asm'