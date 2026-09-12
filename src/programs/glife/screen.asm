; ----------------------------------------------------------------------------
;  text_g：在 ([gx],[gy]) 处画 0 结尾字符串，每字符 8x8，颜色 dl
;  入口：ds:si=字符串地址，dl=颜色
; ----------------------------------------------------------------------------
text_g:
    push ax bx di
    mov  [sptr], si
    xor  bx, bx               ; 字符序号
.textc:
    mov  si, [sptr]
    mov  bh, [si]
    test bh, bh
    jz   .done
    inc  si
    mov  [sptr], si
    mov  ax, bx
    shl  ax, 3
    add  ax, [gx]
    mov  si, ax               ; x
    mov  di, [gy]             ; y
    mov  ah, 7Ah
    int  21h
    inc  bx
    jmp  .textc
.done:
    pop  di bx ax
    ret

