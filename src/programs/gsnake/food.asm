; ----------------------------------------------------------------------------
;  place_food：用 LFSR 随机生成食物坐标，避开蛇身
; ----------------------------------------------------------------------------
place_food:
.gen:
    call lfsr
    mov  cx, COLS
    xor  dx, dx
    div  cx
    mov  [fx], dl
    call lfsr
    mov  cx, ROWS
    xor  dx, dx
    div  cx
    mov  [fy], dl
    xor  bx, bx
.ck:
    cmp  bx, [len]
    jae  .ok
    mov  al, [sx+bx]
    cmp  al, [fx]
    jne  .n
    mov  al, [sy+bx]
    cmp  al, [fy]
    je   .gen
.n:
    inc  bx
    jmp  .ck
.ok:
    ret

; ----------------------------------------------------------------------------
;  draw_food：在 (fx, fy) 格中心画一个填充圆
; ----------------------------------------------------------------------------
draw_food:
    push ax bx cx si
    mov  al, [fx]
    xor  ah, ah
    mov  bx, CELL
    mul  bx
    add  ax, 4
    mov  bx, ax
    mov  al, [fy]
    xor  ah, ah
    mov  cx, CELL
    mul  cx
    add  ax, 4
    mov  cx, ax
    mov  si, 3
    mov  dl, 14
    mov  ah, 78h
    int  21h
    pop  si cx bx ax
    ret

