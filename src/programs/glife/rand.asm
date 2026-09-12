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

spause db 'PAUSED', 0
seed   dw 0
paused db 0
xpos   dw 0
ypos   dw 0
nx     dw 0
ny     dw 0
dxloop dw 0
dyloop dw 0
gx     dw 0
gy     dw 0
sptr   dw 0
cur    db COLS*ROWS dup(0)     ; 当前代
prev   db COLS*ROWS dup(0)     ; 下一代工作缓冲

