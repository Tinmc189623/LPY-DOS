; ----------------------------------------------------------------------------
;  redraw_all：按 cur 重画整个网格（用于恢复时清掉提示残留）
; ----------------------------------------------------------------------------
redraw_all:
    push ax bx cx si
    mov  word [ypos], 0
.yl:
    cmp  word [ypos], ROWS
    jae  .dl
    mov  word [xpos], 0
.xl:
    cmp  word [xpos], COLS
    jae  .dy
    mov  ax, [ypos]
    mov  cx, COLS
    mul  cx
    add  ax, [xpos]
    mov  si, ax
    cmp  byte [cur+si], 0
    je   .d
    gcell LIVE
    jmp  .nx
.d:
    gcell DEAD
.nx:
    inc  word [xpos]
    jmp  .xl
.dy:
    inc  word [ypos]
    jmp  .yl
.dl:
    pop  si cx bx ax
    ret

