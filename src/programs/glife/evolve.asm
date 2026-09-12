; ----------------------------------------------------------------------------
;  evolve：按康威规则从 cur 计算下一代写入 prev，逐格比较后增量重画
;  死细胞邻居=3 生；活细胞邻居 2/3 存活，否则死。边界环绕（环面）。
; ----------------------------------------------------------------------------
evolve:
    push ax bx cx dx si di
    mov  word [ypos], 0
.yloop:
    cmp  word [ypos], ROWS
    jae  .done
    mov  word [xpos], 0
.xloop:
    cmp  word [xpos], COLS
    jae  .nexty
    mov  ax, [ypos]
    mov  cx, COLS
    mul  cx
    add  ax, [xpos]
    mov  si, ax               ; 当前格索引
    xor  bx, bx               ; bx = 活邻居计数
    mov  word [dyloop], -1
.dy:
    cmp  word [dyloop], 1
    jg   .counted
    mov  word [dxloop], -1
.dx:
    cmp  word [dxloop], 1
    jg   .nextdy
    cmp  word [dxloop], 0
    jne  .calc
    cmp  word [dyloop], 0
    je   .nextdx
.calc:
    mov  ax, [xpos]
    add  ax, [dxloop]
    cmp  ax, 0
    jl   .wnegx
    cmp  ax, COLS
    jge  .wposx
    jmp  .xok
.wnegx:
    add  ax, COLS
    jmp  .xok
.wposx:
    sub  ax, COLS
.xok:
    mov  [nx], ax
    mov  ax, [ypos]
    add  ax, [dyloop]
    cmp  ax, 0
    jl   .wnegy
    cmp  ax, ROWS
    jge  .wposy
    jmp  .yok
.wnegy:
    add  ax, ROWS
    jmp  .yok
.wposy:
    sub  ax, ROWS
.yok:
    mov  [ny], ax
    mov  ax, [ny]
    mov  cx, COLS
    mul  cx
    add  ax, [nx]
    mov  di, ax
    cmp  byte [cur+di], 0
    je   .deadn
    inc  bl
.deadn:
.nextdx:
    inc  word [dxloop]
    jmp  .dx
.nextdy:
    inc  word [dyloop]
    jmp  .dy
.counted:
    cmp  byte [cur+si], 0
    jne  .alivecell
    ; 死细胞：恰好 3 个邻居则生
    cmp  bl, 3
    jne  .staydead
    mov  byte [prev+si], 1
    mov  byte [cur+si], 1
    gcell LIVE
    jmp  .nextx
.staydead:
    mov  byte [prev+si], 0
    jmp  .nextx
.alivecell:
    ; 活细胞：2/3 存活，否则死
    cmp  bl, 2
    jb   .dienow
    cmp  bl, 3
    ja   .dienow
    mov  byte [prev+si], 1
    jmp  .nextx
.dienow:
    mov  byte [prev+si], 0
    mov  byte [cur+si], 0
    gcell DEAD
    jmp  .nextx
.nextx:
    inc  word [xpos]
    jmp  .xloop
.nexty:
    inc  word [ypos]
    jmp  .yloop
.done:
    pop  di si dx cx bx ax
    ret

