; ============================================================================
;  logo.inc — LPY-DOS SDK 库 LOGO（纯字符 ASCII + 颜色）
;  为五个 SDK 库各提供一份 ASCII 横幅，并共享一个渲染例程
;  （直接写文本显存 0B800h，char+attr，居中渲染）。
;  带重复 include 保护：被 lpydos/conio/fs/numeric/sysinfo 多次 include 不会重定义。
;  Copyright (C) 2026 Nexsteaduser
;  Licensed under GPL v3 or later.
; ============================================================================

if defined LOGO_INC
else
LOGO_INC equ 1

; ----------------------------------------------------------------------------
;  颜色属性字节（高半字节背景，低半字节前景 = 亮白 F）
; ----------------------------------------------------------------------------
lpy_logo_attr    = 4Fh   ; 白字 / 红底
conio_logo_attr  = 1Fh   ; 白字 / 蓝底
fs_logo_attr     = 2Fh   ; 白字 / 绿底
num_logo_attr    = 6Fh   ; 白字 / 黄底
sys_logo_attr    = 3Fh   ; 白字 / 青底

; ----------------------------------------------------------------------------
;  横幅数据：'.' 背景 / '#' 前景，每行 宽/字符 字节，行连续存储
; ----------------------------------------------------------------------------
lpy_logo_w = 35
lpy_logo_h = 5
lpy_logo_data:
    db '#.... ###.. #..#. ###.. .##.. .###.'
    db '#.... #..#. #..#. #..#. #..#. #....'
    db '#.... ###.. .##.. #..#. #..#. .##..'
    db '#.... #.... ..#.. #..#. #..#. ....#'
    db '####. #.... ..#.. ###.. .##.. ###..'

conio_logo_w = 29
conio_logo_h = 5
conio_logo_data:
    db '.##.. .##.. #...# ###.. .##..'
    db '#..#. #..#. ##..# ..#.. #..#.'
    db '#.... #..#. #.#.# ..#.. #..#.'
    db '#..#. #..#. #..## ..#.. #..#.'
    db '.##.. .##.. #...# ###.. .##..'

fs_logo_w = 11
fs_logo_h = 5
fs_logo_data:
    db '####. .###.'
    db '#.... #....'
    db '###.. .##..'
    db '#.... ....#'
    db '#.... ###..'

num_logo_w = 41
num_logo_h = 5
num_logo_data:
    db '#...# #..#. #...# ####. ###.. ###.. .##..'
    db '##..# ##..# ##..# #.... #..#. ..#.. #..#.'
    db '#.#.# #..#. #.#.# ###.. ###.. ..#.. #....'
    db '#..## #..#. #..## #.... #.#.. ..#.. #..#.'
    db '#...# .##.. #...# ####. #..#. ###.. .##..'

sys_logo_w = 41
sys_logo_h = 5
sys_logo_data:
    db '.###. #..#. .###. ###.. #...# ####. .##..'
    db '#.... #..#. #.... ..#.. ##..# #.... #..#.'
    db '.##.. .##.. .##.. ..#.. #.#.# ###.. #..#.'
    db '....# ..#.. ....# ..#.. #..## #.... #..#.'
    db '###.. ..#.. ###.. ###.. #...# #.... .##..'

; ----------------------------------------------------------------------------
;  render_logo：将一副 ASCII 横幅居中写入文本显存
;  入口：DS:SI = 横幅数据，BX = 行宽（字符），CX = 行数，DL = 颜色属性
;  出口：无（直接改写 0B800h 段，不清屏）
; ----------------------------------------------------------------------------
render_logo:
    push ax bx cx dx si di es bp
    mov ax, 0B800h
    mov es, ax
    ; 垂直居中 start_row = (25 - h) / 2
    mov al, 25
    sub al, cl
    shr al, 1
    mov ah, 0
    push cx
    mov cx, ax
    mov ax, 160
    mul cx
    mov bp, ax
    pop cx
    ; 水平居中 start_col = (80 - w) / 2，偏移 = col*2，加到段基点
    mov al, 80
    sub al, bl
    shr al, 1
    mov ah, 0
    shl ax, 1
    add bp, ax
.outer:
    push cx                 ; 保存剩余行数
    mov di, bp              ; 当前行起始 cell 偏移
    mov cx, bx              ; 行宽字符数
.char:
    mov al, [si]
    mov [es:di], al
    mov al, dl
    mov [es:di+1], al
    add si, 1
    add di, 2
    loop .char
    mov al, 160             ; 行递进步长 = 160 - w*2
    mov bh, 0
    shl bx, 1
    sub ax, bx
    shr bx, 1               ; 恢复 bx = 行宽
    add bp, ax
    pop cx
    loop .outer
    pop bp es di si dx cx bx ax
    ret

; ----------------------------------------------------------------------------
;  五个库各自的 LOGO 打印例程（仅装载各自参数后复用 render_logo）
; ----------------------------------------------------------------------------
lpy_logo_print:
    lea si, [lpy_logo_data]
    mov bx, lpy_logo_w
    mov cx, lpy_logo_h
    mov dl, lpy_logo_attr
    jmp render_logo

conio_logo_print:
    lea si, [conio_logo_data]
    mov bx, conio_logo_w
    mov cx, conio_logo_h
    mov dl, conio_logo_attr
    jmp render_logo

fs_logo_print:
    lea si, [fs_logo_data]
    mov bx, fs_logo_w
    mov cx, fs_logo_h
    mov dl, fs_logo_attr
    jmp render_logo

num_logo_print:
    lea si, [num_logo_data]
    mov bx, num_logo_w
    mov cx, num_logo_h
    mov dl, num_logo_attr
    jmp render_logo

sys_logo_print:
    lea si, [sys_logo_data]
    mov bx, sys_logo_w
    mov cx, sys_logo_h
    mov dl, sys_logo_attr
    jmp render_logo

end if