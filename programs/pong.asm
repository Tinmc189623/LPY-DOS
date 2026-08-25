use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  pong.com — 单杆反弹球：W/S 移动左挡板，球撞板得分，漏球重置
; ============================================================================
start:
    mov ax, 0600h
    mov bh, 07h
    xor cx, cx
    mov dx, 184Fh
    int 10h
    mov byte [py], 10
    mov word [score], 0
    call reset_ball
    mov dh, 0
    mov dl, 40
    call setcurs
    puts s_msg
.frame:
    ; 读取按键
    mov ah, 01h
    int 16h
    jz .nokey
    call get_key
    cmp al, 'w'
    je .up
    cmp al, 's'
    je .down
    cmp al, 1Bh
    je .exit
    jmp .nokey
.nokey:
    call draw_paddle
    ; 擦除旧球
    mov dh, [row]
    mov dl, [col]
    call setcurs
    putch ' '
    ; 移动球
    mov al, [row]
    add al, [dr]
    mov [row], al
    mov al, [col]
    add al, [dc]
    mov [col], al
    ; 上下墙反弹
    cmp byte [row], 0
    jne .rl
    mov byte [dr], 1
    jmp .colc
.rl:
    cmp byte [row], 23
    jne .colc
    mov byte [dr], -1
.colc:
    ; 右墙反弹
    cmp byte [col], 79
    jne .leftc
    mov byte [dc], -1
    jmp .wr
.leftc:
    ; 球到挡板列
    cmp byte [col], 1
    jne .wr
    mov al, [row]
    cmp al, [py]
    jb .miss
    mov bl, [py]
    add bl, 3
    cmp al, bl
    ja .miss
    ; 命中：反弹并加分
    mov byte [dc], 1
    inc word [score]
    jmp .wr
.miss:
    call reset_ball
.wr:
    ; 画球
    mov dh, [row]
    mov dl, [col]
    call setcurs
    putch 'O'
    ; 顶部显示分数
    mov dh, 0
    mov dl, 0
    call setcurs
    puts s_sc
    mov ax, [score]
    call print_dec16
    putch ' '
    mov cx, 1
    call delay_ticks
    jmp .frame
.up:
    cmp byte [py], 0
    jbe .nokey
    dec byte [py]
    jmp .nokey
.down:
    cmp byte [py], 20
    jae .nokey
    inc byte [py]
    jmp .nokey
.exit:
    int 20h

; ----------------------------------------------------------------------------
;  reset_ball：把球放回中间并让它朝左挡板移动
; ----------------------------------------------------------------------------
reset_ball:
    mov byte [row], 12
    mov byte [col], 30
    mov byte [dr], 1
    mov byte [dc], -1
    ret

; ----------------------------------------------------------------------------
;  draw_paddle：清理 0 列后重画挡板（py..py+3 为 '|'）
; ----------------------------------------------------------------------------
draw_paddle:
    push ax bx dx
    mov bx, 0
.er:
    cmp bx, 24
    jae .dr
    mov dh, bl
    mov dl, 0
    call setcurs
    putch ' '
    inc bx
    jmp .er
.dr:
    mov bl, byte [py]
    xor bh, bh
    add bx, 3
    mov dx, bx
    mov bl, byte [py]
    xor bh, bh
.v:
    mov dh, bl
    mov dl, 0
    call setcurs
    putch '|'
    inc bl
    cmp bl, dl
    jbe .v
    pop dx bx ax
    ret

s_msg db 'PONG - W/S move paddle, ESC quit$'
s_sc  db 'Score: $'
py    db 0
row   db 0
col   db 0
dr    db 0
dc    db 0
score dw 0

include 'inc/std.asm'