start:
    mov  ah, 70h
    int  21h                  ; 进入图形模式

    mov  ah, 0
    int  1Ah                  ; 读时钟
    mov  [seed], dx           ; 用时钟低字作 LFSR 种子
    cmp  word [seed], 0
    jne  .seeded
    mov  word [seed], 0ABCDh
.seeded:
    call init_grid            ; 随机播种并首画
    mov  byte [paused], 0

.frame:
    mov  ah, 01h
    int  16h                  ; 检查按键，ZF=1 无键
    jz   .nokey
    call get_key
    cmp  al, ' '              ; 空格暂停/继续
    je   .toggle
    cmp  al, 'q'
    je   .exit
    cmp  al, 'Q'
    je   .exit
    cmp  al, 1Bh              ; Esc 退出
    je   .exit
    jmp  .nokey

.toggle:
    xor  byte [paused], 1
    cmp  byte [paused], 1
    jne  .resume
    ; 已暂停：左上角画 PAUSED
    mov  si, spause
    mov  word [gx], 8
    mov  word [gy], 0
    mov  dl, 11
    call text_g
    jmp  .frame
.resume:
    call redraw_all           ; 恢复：重画全网格清掉提示残留
    jmp  .frame

.nokey:
    cmp  byte [paused], 0
    jne  .wait
    call evolve               ; 推进一代并增量更新像素
.wait:
    mov  cx, 1
    call delay_ticks
    jmp  .frame

.exit:
    int  20h                  ; 内核自动恢复文本

