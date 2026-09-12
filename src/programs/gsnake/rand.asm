; ----------------------------------------------------------------------------
;  lfsr：16 位 Galois LFSR，返回 AX=伪随机数，状态存 [seed]
; ----------------------------------------------------------------------------
lfsr:
    push cx dx
    mov  ax, [seed]
    mov  cx, 8
.l:
    mov  dx, ax
    and  dx, 1
    shr  ax, 1
    test dx, dx
    jz   .no
    xor  ax, 0B400h
.no:
    loop .l
    mov  [seed], ax
    pop  dx cx
    ret

scap   db 'SNAKE: WASD/ARROWS  ESC QUIT', 0
sover  db 'GAME OVER', 0
swin   db 'YOU WIN', 0
seed   dw 0
len    dw 0
dir    db 0
nhx    db 0
nhy    db 0
ohx    db 0
ohy    db 0
fx     db 0
fy     db 0
grow   db 0
gx     dw 0
gy     dw 0
sptr   dw 0
sx     db MAXLEN dup(0)       ; 蛇身 X 坐标（每节一格）
sy     db MAXLEN dup(0)       ; 蛇身 Y 坐标

