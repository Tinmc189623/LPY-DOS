start:
    mov ah, 70h
    int 21h

frame:
    mov ah, 01h
    int 16h
    jnz quit
    ; 全屏清黑
    xor bx, bx
    xor cx, cx
    mov si, 319
    mov di, 199
    xor dl, dl
    mov ah, 75h
    int 21h

    ; 逐条绘制半径线，用运行游标法避免乘法
    mov ax, [angle]         ; AX = 本条线角度
    mov cx, ARMS            ; 线条计数
arm_loop:
    mov [a_tmp], ax         ; 保存当前线角度
    ; 外端点 X = CENTER_X + cos(a)*RHI/256  (cos 用 sin(a+64))
    push ax
    add ax, 64
    and ax, 255
    mov bx, RHI
    call sincomp
    add ax, CENTER_X
    mov [ex_t], ax
    mov ax, [a_tmp]
    mov bx, RHI
    call sincomp            ; 外端点 Y = CENTER_Y + sin(a)*RHI/256
    add ax, CENTER_Y
    mov [ey_t], ax
    pop ax

    ; 画中心 -> 外端点的半径线，颜色随序号变化
    mov bx, CENTER_X
    mov cx, CENTER_Y
    mov si, [ex_t]
    mov di, [ey_t]
    mov dl, 5               ; 指定高亮色
    call draw_line

    ; 下一条线角度 += MS
    add ax, MS
    and ax, 255
    loop arm_loop

    ; 角度前进
    add word [angle], 3
    mov cx, 2
    call delay_ticks
    jmp frame
quit:
    int 20h

