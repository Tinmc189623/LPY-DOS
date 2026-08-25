use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  rain.com — 随机星点下落效果，按键退出
; ============================================================================
N equ 24

start:
    mov ah, 0
    int 1Ah
    mov byte [seed], dl
    ; 初始化 N 个粒子：随机 y、随机 x（0..43）
    mov si, 0
.init:
    cmp si, N
    jae .frame
    call lfsr
    mov cx, 24
    xor dx, dx
    div cx
    mov [py+si], dl        ; 随机行
    call lfsr
    mov cx, 44
    xor dx, dx
    div cx
    mov [px+si], dl        ; 随机列
    call rand_chr
    mov [pc+si], al        ; 随机字符
    inc si
    jmp .init
.frame:
    mov ah, 01h
    int 16h
    jnz .exit
    mov si, 0
.part:
    cmp si, N
    jae .frame_next
    mov [pi], si
    ; 清除当前粒子旧位置
    mov ax, [pi]
    mov bx, ax
    mov al, [py+bx]
    mov dh, al
    mov al, [px+bx]
    mov dl, al
    call setcurs
    putch ' '
    ; 向下移动
    mov al, [py+bx]
    inc al
    cmp al, 24
    jb .move
    ; 底部回顶：重置行、列、字符
    xor al, al
    call lfsr
    mov cx, 44
    xor dx, dx
    div cx
    mov [px+bx], dl
    call rand_chr
    mov [pc+bx], al
.move:
    mov [py+bx], al
    ; 在新位置画字符
    mov dh, al
    mov al, [px+bx]
    mov dl, al
    call setcurs
    mov al, [pc+bx]
    mov dl, al
    mov ah, 02h
    int 21h
    mov ax, [pi]
    inc ax
    mov si, ax
    jmp .part
.frame_next:
    mov cx, 1
    call delay_ticks
    jmp .frame
.exit:
    call get_key
    int 20h

; ----------------------------------------------------------------------------
;  rand_chr：产生可打印随机字符（33..126）
; ----------------------------------------------------------------------------
rand_chr:
    call lfsr
    xor dx, dx
    mov cx, 94
    div cx
    mov al, dl
    add al, 33
    ret

; ----------------------------------------------------------------------------
;  lfsr：Galois LFSR，返回 AX = 伪随机数
; ----------------------------------------------------------------------------
lfsr:
    push cx dx
    mov ax, [seed]
    mov cx, 8
.l:
    mov dx, ax
    and dx, 1
    shr ax, 1
    test dx, dx
    jz .no
    xor ax, 0B400h
.no:
    loop .l
    mov [seed], ax
    pop dx cx
    ret

seed dw 0
pi   dw 0
px   db N dup(0)
py   db N dup(0)
pc   db N dup(0)

include 'inc/std.asm'