; ----------------------------------------------------------------------------
;  draw_line：Bresenham 画线段。入口 BX=X0,CX=Y0,SI=X1,DI=Y1,DL=颜色
; ----------------------------------------------------------------------------
draw_line:
    push ax bx cx dx si di bp
    mov [col_tmp], dl
    ; DX = |X1-X0|，SX 步进
    mov ax, si
    sub ax, bx
    mov dx, ax
    mov word [sxh_tmp], 1
    cmp ax, 0
    jge .dx1
    neg dx
    mov word [sxh_tmp], -1
.dx1:
    mov [dx_tmp], dx
    ; DY = |Y1-Y0|，SY 步进
    mov ax, di
    sub ax, cx
    mov bp, ax
    mov word [syh_tmp], 1
    cmp ax, 0
    jge .dy1
    neg bp
    mov word [syh_tmp], -1
.dy1:
    mov [dy_tmp], bp
    ; err = DX - DY
    mov ax, [dx_tmp]
    sub ax, [dy_tmp]
    mov [err_tmp], ax
.lp:
    mov dl, [col_tmp]
    mov ah, 72h             ; 画点 (bx,cx)
    int 21h
    cmp bx, si
    jne .go
    cmp cx, di
    je .done
.go:
    mov ax, [err_tmp]
    shl ax, 1               ; e2 = 2*err
    mov bp, ax
    ; if e2 > -DY：ERR-=DY，X+=SX
    mov dx, [dy_tmp]
    neg dx
    cmp bp, dx
    jle .skipx
    mov ax, [err_tmp]
    sub ax, [dy_tmp]
    mov [err_tmp], ax
    add bx, [sxh_tmp]
.skipx:
    ; if e2 < DX：ERR+=DX，Y+=SY
    mov dx, [dx_tmp]
    cmp bp, dx
    jge .skipy
    mov ax, [err_tmp]
    add ax, [dx_tmp]
    mov [err_tmp], ax
    add cx, [syh_tmp]
.skipy:
    jmp .lp
.done:
    pop bp di si dx cx bx ax
    ret

angle    dw 0
a_tmp    dw 0
ex_t     dw 0
ey_t     dw 0
rr_tmp   dw 0
ang_tmp  dw 0
idx_tmp  dw 0
quad_tmp dw 0
col_tmp  db 0
sxh_tmp  dw 0
syh_tmp  dw 0
dx_tmp   dw 0
dy_tmp   dw 0
err_tmp  dw 0

; 正弦表：sin_t[i] = sin(i*90/64度)*256，i=0..64（最大 255）
sin_t db 0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92
      db 98,104,109,115,121,126,132,137,142,147,153,158,163,167,172,177
      db 181,185,190,194,198,202,206,209,213,216,220,223,227,230,233,236
      db 239,242,245,247,250,252,255,255,251,252,253,254,255,255,255,255,255

