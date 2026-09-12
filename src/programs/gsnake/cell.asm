; ----------------------------------------------------------------------------
;  draw_cell：画 (bx, cx) 格的 CELL*CELL 填充方块，dl=颜色
; ----------------------------------------------------------------------------
draw_cell:
    push ax
    mov  ax, bx
    mov  bx, CELL
    mul  bx
    mov  bx, ax              ; bx = px0
    add  ax, CELL
    dec  ax
    mov  si, ax              ; si = px1
    mov  ax, cx
    mov  cx, CELL
    mul  cx
    mov  cx, ax              ; cx = py0
    add  ax, CELL
    dec  ax
    mov  di, ax              ; di = py1
    mov  ah, 75h
    int  21h                 ; dl = color 保留
    pop  ax
    ret

