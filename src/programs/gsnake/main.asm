start:
    mov  ah, 70h
    int  21h                 ; 进入图形模式

    mov  ah, 0
    int  1Ah
    mov  [seed], dx
    cmp  word [seed], 0
    jne  .seeded
    mov  word [seed], 0123h
.seeded:
    mov  word [len], 3
    mov  byte [dir], 1       ; 初始方向：右
    mov  byte [sx+0], 12     ; 头
    mov  byte [sy+0], 11
    mov  byte [sx+1], 11
    mov  byte [sy+1], 11
    mov  byte [sx+2], 10     ; 尾
    mov  byte [sy+2], 11
    call place_food

    ; 首画蛇身
    xor  di, di
.drbody:
    cmp  di, [len]
    jae  .drbend
    mov  bl, [sx+di]
    mov  cl, [sy+di]
    mov  dl, 10
    call draw_cell
    inc  di
    jmp  .drbody
.drbend:
    call draw_food           ; 画食物
    mov  si, scap            ; 底部提示栏
    mov  word [gx], 8
    mov  word [gy], 184
    mov  dl, 7
    call text_g

.frame:
    ; 读按键（含方向键扫描码）
    mov  ah, 01h
    int  16h
    jz   .nokey
    mov  ah, 0
    int  16h
    test al, al
    jnz  .ascii
    ; 扩展键：按扫描码判方向
    cmp  ah, 48h             ; 上
    je   .uper
    cmp  ah, 50h             ; 下
    je   .downer
    cmp  ah, 4Bh             ; 左
    je   .leftar
    cmp  ah, 4Dh             ; 右
    je   .rightar
    jmp  .nokey
.ascii:
    cmp  al, 'w'
    je   .uper
    cmp  al, 'W'
    je   .uper
    cmp  al, 's'
    je   .downer
    cmp  al, 'S'
    je   .downer
    cmp  al, 'a'
    je   .leftar
    cmp  al, 'A'
    je   .leftar
    cmp  al, 'd'
    je   .rightar
    cmp  al, 'D'
    je   .rightar
    cmp  al, 1Bh             ; Esc 退出
    je   .quit
    jmp  .nokey
.uper:
    cmp  byte [dir], 2
    je   .nokey
    mov  byte [dir], 0
    jmp  .nokey
.downer:
    cmp  byte [dir], 0
    je   .nokey
    mov  byte [dir], 2
    jmp  .nokey
.leftar:
    cmp  byte [dir], 1
    je   .nokey
    mov  byte [dir], 3
    jmp  .nokey
.rightar:
    cmp  byte [dir], 3
    je   .nokey
    mov  byte [dir], 1
.nokey:

    ; 记录旧头
    mov  al, [sx+0]
    mov  [ohx], al
    mov  al, [sy+0]
    mov  [ohy], al
    ; 由方向算新头
    mov  al, [ohx]
    mov  [nhx], al
    mov  al, [ohy]
    mov  [nhy], al
    mov  al, [dir]
    cmp  al, 0
    jne  .nu
    dec  byte [nhy]          ; 上
    jmp  .mvd
.nu:
    cmp  al, 2
    jne  .nl
    inc  byte [nhy]          ; 下
    jmp  .mvd
.nl:
    cmp  al, 3
    jne  .nr
    dec  byte [nhx]          ; 左
    jmp  .mvd
.nr:
    inc  byte [nhx]          ; 右
.mvd:
    ; 边界检测（回绕成大值必然越界）
    mov  al, [nhx]
    cmp  al, COLS
    jae  .over
    mov  al, [nhy]
    cmp  al, ROWS
    jae  .over

    ; 是否吃到食物
    mov  byte [grow], 0
    mov  al, [nhx]
    cmp  al, [fx]
    jne  .cgrow
    mov  al, [nhy]
    cmp  al, [fy]
    jne  .cgrow
    mov  byte [grow], 1
.cgrow:
    ; 自撞检测：非生长时忽略将离开的尾节
    xor  bx, bx
.self:
    mov  cl, [sx+bx]
    cmp  cl, [nhx]
    jne  .scn
    mov  cl, [sy+bx]
    cmp  cl, [nhy]
    jne  .scn
    jmp  .collide
.scn:
    inc  bx
    cmp  bx, [len]
    jae  .selfdone
    jmp  .self
.collide:
    cmp  byte [grow], 0
    jne  .over
    mov  ax, bx
    inc  ax
    cmp  ax, [len]
    jne  .over
    jmp  .selfdone           ; 撞到即将移动的尾节，视为安全
.selfdone:

    ; 非生长：擦旧尾
    cmp  byte [grow], 0
    jne  .tkeep
    mov  ax, [len]
    dec  ax
    mov  di, ax
    mov  bl, [sx+di]
    mov  cl, [sy+di]
    mov  dl, 0
    call draw_cell
.tkeep:
    ; 旧头变身体颜色
    mov  bl, [ohx]
    mov  cl, [ohy]
    mov  dl, 10
    call draw_cell

    ; 生长时长度 +1
    cmp  byte [grow], 0
    je   .lenok
    inc  word [len]
.lenok:
    ; 主体后移：for i=len-1 downto 1
    mov  ax, [len]
    dec  ax
.sh:
    test ax, ax
    jz   .shdone
    mov  si, ax
    mov  di, ax
    dec  di
    mov  dl, [sx+di]
    mov  [sx+si], dl
    mov  dl, [sy+di]
    mov  [sy+si], dl
    dec  ax
    jmp  .sh
.shdone:
    ; 写入新头
    mov  al, [nhx]
    mov  [sx+0], al
    mov  al, [nhy]
    mov  [sy+0], al

    ; 吃到食物：重放食物；放不下则胜利
    cmp  byte [grow], 0
    je   .curfood
    cmp  word [len], MAXLEN
    jae  .win
    call place_food
    call draw_food
.curfood:
    ; 画新头
    mov  bl, [nhx]
    mov  cl, [nhy]
    mov  dl, 15
    call draw_cell
    mov  cx, 2
    call delay_ticks
    jmp  .frame

.quit:
    int  20h

.over:
    ; 游戏结束：清一块区域画红色 GAME OVER
    mov  ah, 75h
    mov  bx, 100
    mov  cx, 88
    mov  si, 219
    mov  di, 104
    mov  dl, 0
    int  21h
    mov  si, sover
    mov  word [gx], 124
    mov  word [gy], 92
    mov  dl, 12
    call text_g
    jmp  .endw
.win:
    ; 胜利：画绿色 YOU WIN
    mov  ah, 75h
    mov  bx, 110
    mov  cx, 88
    mov  si, 209
    mov  di, 104
    mov  dl, 0
    int  21h
    mov  si, swin
    mov  word [gx], 132
    mov  word [gy], 92
    mov  dl, 10
    call text_g
.endw:
    call get_key
    int  20h

