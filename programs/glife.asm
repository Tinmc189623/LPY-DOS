use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  glife.com — 康威生命游戏（像素版，64x40 环绕网格）
;  玩法：进入图形模式后随机播种，按空格暂停/继续，Q 或 Esc 退出。
;  每一代按康威规则推进：活邻居=3 时生，2/3 存活，否则死/消失。
;  用 16 位 Galois LFSR 播种（种子取时钟低字）。
;  图形协议经 INT 21h：AH=70 进入图形，AH=75 填充方块，AH=7A 画文本；
;  程序经 int 20h 退出，内核自动恢复文本模式。
;  Copyright (C) 2026 Nexsteaduser
; ============================================================================

COLS equ 64                ; 网格列数
ROWS equ 40                ; 网格行数
CELL equ 4                 ; 每格像素边长
OX   equ 32                ; 网格在屏幕上的 X 偏移
OY   equ 20                ; 网格在屏幕上的 Y 偏移
LIVE equ 10                ; 活细胞颜色（亮绿）
DEAD equ 0                 ; 死细胞颜色（黑）

; ----------------------------------------------------------------------------
;  宏：把 (xpos,ypos) 这一格画成 color 色的 CELL*CELL 填充方块
; ----------------------------------------------------------------------------
macro gcell color {
    mov  ax, [xpos]
    mov  bx, CELL
    mul  bx
    add  ax, OX
    mov  bx, ax               ; bx = px0
    mov  ax, [ypos]
    mov  cx, CELL
    mul  cx
    add  ax, OY
    mov  cx, ax               ; cx = py0
    mov  ax, bx
    add  ax, CELL
    dec  ax
    mov  si, ax               ; si = px1
    mov  ax, cx
    add  ax, CELL
    dec  ax
    mov  di, ax               ; di = py1
    mov  ah, 75h
    mov  dl, color
    int  21h
}

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

; ----------------------------------------------------------------------------
;  lfsr：16 位 Galois LFSR，返回 AX=伪随机数，状态存 [seed]
; ----------------------------------------------------------------------------
lfsr:
    push cx dx
    mov  ax, [seed]
    mov  cx, 8
.l:
    mov  dx, ax
    and  dx, 1
    shr  ax, 1
    test dx, dx
    jz   .no
    xor  ax, 0B400h
.no:
    loop .l
    mov  [seed], ax
    pop  dx cx
    ret

spause db 'PAUSED', 0
seed   dw 0
paused db 0
xpos   dw 0
ypos   dw 0
nx     dw 0
ny     dw 0
dxloop dw 0
dyloop dw 0
gx     dw 0
gy     dw 0
sptr   dw 0
cur    db COLS*ROWS dup(0)     ; 当前代
prev   db COLS*ROWS dup(0)     ; 下一代工作缓冲

include 'inc/std.asm'