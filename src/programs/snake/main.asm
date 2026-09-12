start:
    call check_about
    ; 清屏
    mov ax, 0600h
    mov bh, 07h
    xor cx, cx
    mov dx, 184Fh
    int 10h
    mov word [len], 3
    mov byte [dir], 1        ; 初始方向：右
    call place_food
    puts s_msg
.frame:
    ; 读取方向键（WASD）
    mov ah, 01h
    int 16h
    jz .nokey
    call get_key
    mov bl, al
    cmp bl, 'w'
    je .up
    cmp bl, 's'
    je .down
    cmp bl, 'a'
    je .left
    cmp bl, 'd'
    je .right
    jmp .nokey
.up:
    mov byte [dir], 0
    jmp .nokey
.down:
    mov byte [dir], 2
    jmp .nokey
.left:
    mov byte [dir], 3
    jmp .nokey
.right:
    mov byte [dir], 1
.nokey:
    ; 保存旧头（画体用）
    mov al, [sx+0]
    mov [ohx], al
    mov al, [sy+0]
    mov [ohy], al
    ; 新头 = 旧头 + 方向
    mov al, [ohx]
    mov [nhx], al
    mov al, [ohy]
    mov [nhy], al
    mov al, [dir]
    cmp al, 0
    jne .nu
    dec byte [nhy]           ; 上
    jmp .movedir
.nu:
    cmp al, 2
    jne .nd
    inc byte [nhy]           ; 下
    jmp .movedir
.nd:
    cmp al, 3
    jne .nl
    dec byte [nhx]           ; 左
    jmp .movedir
.nl:
    inc byte [nhx]           ; 右
.movedir:
    ; 撞墙检测（byte 越界会回绕成 255，均 > 上限即撞）
    cmp byte [nhy], 24
    ja .die
    cmp byte [nhx], 79
    ja .die
    ; 自撞检测
    mov si, 1
.self:
    cmp si, [len]
    jae .game
    mov al, [sx+si]
    cmp al, [nhx]
    jne .snext
    mov al, [sy+si]
    cmp al, [nhy]
    je .die
.snext:
    inc si
    jmp .self
.game:
    ; 判断是否吃到食物
    mov al, [nhx]
    cmp al, [fx]
    jne .nogrow
    mov al, [nhy]
    cmp al, [fy]
    je .grow
.nogrow:
    ; 不增长：记住旧尾以便删除格
    mov si, [len]
    dec si
    mov al, [sx+si]
    mov [tx], al
    mov al, [sy+si]
    mov [ty], al
    jmp .move
.grow:
    ; 增长：尾巴保留，长度 +1
    inc word [len]
    mov si, [len]
    dec si
    mov al, [sx+si]
    mov [tx], al
    mov al, [sy+si]
    mov [ty], al
    call place_food
.move:
    ; 主体后移：for i=len-1 downto 1
    mov si, [len]
    dec si
.mv:
    test si, si
    jz .mv_done
    mov al, [sx+si-1]
    mov [sx+si], al
    mov al, [sy+si-1]
    mov [sy+si], al
    dec si
    jmp .mv
.mv_done:
    ; 写入新头
    mov al, [nhx]
    mov [sx+0], al
    mov al, [nhy]
    mov [sy+0], al
    ; 若没增长，删除旧尾格；增长时旧尾格保留
    mov ax, [len]
    cmp ax, 3
    je .del_tail            ; 没增长过（len 仍为 3）
    jmp .draw
.del_tail:
    mov dh, [ty]
    mov dl, [tx]
    call setcurs
    putch ' '
.draw:
    ; 旧头位置画成身体 '#'
    mov dh, [ohy]
    mov dl, [ohx]
    call setcurs
    putch '#'
    ; 新头位置画 'O'
    mov dh, [nhy]
    mov dl, [nhx]
    call setcurs
    putch 'O'
    ; 食物
    mov dh, [fy]
    mov dl, [fx]
    call setcurs
    putch '*'
    mov cx, 1
    call delay_ticks
    jmp .frame
.die:
    ; 游戏结束提示
    mov dh, 25
    mov dl, 0
    call setcurs
    puts s_over
    int 20h

