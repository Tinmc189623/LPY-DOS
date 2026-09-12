; ----------------------------------------------------------------------------
;  init_grid：用 LFSR（约 25% 密度）填充 cur，并首画活细胞
; ----------------------------------------------------------------------------
init_grid:
    push ax bx cx si
    mov  word [ypos], 0
.yl:
    cmp  word [ypos], ROWS
    jae  .dl
    mov  word [xpos], 0
.xl:
    cmp  word [xpos], COLS
    jae  .dy
    call lfsr
    and  ax, 3
    cmp  ax, 3
    jne  .de
    mov  ax, [ypos]
    mov  cx, COLS
    mul  cx
    add  ax, [xpos]
    mov  si, ax
    mov  byte [cur+si], 1
    gcell LIVE
    jmp  .nx
.de:
    mov  ax, [ypos]
    mov  cx, COLS
    mul  cx
    add  ax, [xpos]
    mov  si, ax
    mov  byte [cur+si], 0
.nx:
    inc  word [xpos]
    jmp  .xl
.dy:
    inc  word [ypos]
    jmp  .yl
.dl:
    pop  si cx bx ax
    ret

