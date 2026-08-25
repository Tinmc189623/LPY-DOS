use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  matrix.com — 数字雨：20 列字符自上而下漂落，按键退出
; ============================================================================
start:
    ; 用时钟初始化随机种子
    mov ah, 0
    int 1Ah
    mov byte [seed], dl
    ; 初始化 20 列：随机起始行与字符
    mov si, 0
.init:
    cmp si, 20
    jae .frame
    call lfsr
    mov cx, 24
    xor dx, dx
    div cx
    mov [cy+si], dl        ; 起始行 0..23
    call rand_chr
    mov [cch+si], al       ; 字符
    inc si
    jmp .init
.frame:
    ; 检查按键退出
    mov ah, 01h
    int 16h
    jnz .exit
    mov si, 0
.col:
    cmp si, 20
    jae .frame_next
    mov [col], si
    ; 清除旧头部格子 (y, col)
    mov al, [cy+si]
    cmp al, 24
    jae .skip_clr
    mov dh, al
    mov ax, [col]
    mov dl, al
    call setcurs
    putch ' '
.skip_clr:
    ; 头部下移一行，越界则回到顶部并换字符
    mov al, [cy+si]
    inc al
    cmp al, 24
    jb .ok
    xor al, al
    call rand_chr
    mov [cch+si], al
.ok:
    mov [cy+si], al
    ; 在新位置写字符
    cmp al, 24
    jae .skip_wr
    mov dh, al
    mov ax, [col]
    mov dl, al
    call setcurs
    mov dl, [cch+si]
    mov ah, 02h
    int 21h
.skip_wr:
    inc si
    jmp .col
.frame_next:
    mov cx, 1
    call delay_ticks
    jmp .frame
.exit:
    call get_key
    int 20h

; ----------------------------------------------------------------------------
;  rand_chr：产生一个可打印 ASCII 随机字符（33..126）
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
col  dw 0
cy   db 20 dup(0)
cch  db 20 dup(0)

include 'inc/std.asm'