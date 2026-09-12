; ----------------------------------------------------------------------------
;  place_food：随机放置食物坐标到 (fx, fy)
; ----------------------------------------------------------------------------
place_food:
    call lfsr
    mov cx, 79
    xor dx, dx
    div cx
    inc dl
    mov [fx], dl
    call lfsr
    mov cx, 23
    xor dx, dx
    div cx
    inc dl
    mov [fy], dl
    ret

; ----------------------------------------------------------------------------
;  lfsr：Galois LFSR，返回 AX = 伪随机数
; ----------------------------------------------------------------------------
lfsr:
    push cx dx
    mov ax, [seed]
    mov cx, 8
.l:
    mov dx, ax
    and dx, 1
    shr ax, 1
    test dx, dx
    jz .no
    xor ax, 0B400h
.no:
    loop .l
    mov [seed], ax
    pop dx cx
    ret

s_msg db 'SNAKE: WASD to steer, eat * to grow$'
s_over db 'Game over!$'
len   dw 0
dir   db 0
nhx   db 0
nhy   db 0
ohx   db 0
ohy   db 0
tx    db 0
ty    db 0
fx    db 0
fy    db 0
seed  dw 0
sx    db 10, 9, 8
      db MAXLEN dup(0)
sy    db 12, 12, 12
      db MAXLEN dup(0)

logo_attr db 0Ch
logo_data db ' SSSS  N   N  A     K   K  EEEEE$'
          db 'S      NN  N  A A   K  K   E    $'
          db ' SSS   N N N  AAAAA  KKK    EEE $'
          db '    S  N  NN  A   A  K  K   E    $'
          db 'SSSS   N   N  A   A  K   K  EEEEE$'
          db 0

