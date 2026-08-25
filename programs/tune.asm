use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  tune.com — 用 PC 扬声器播放一段上行音阶（C D E F G A B C'）
; ============================================================================
start:
    puts s_msg
    lea si, [song]
.t:
    mov ax, [si]
    test ax, ax
    jz .done
    mov bx, ax              ; 频率
    mov cx, [si+2]          ; 时长（滴答）
    call play_freq
    mov cx, 1
    call delay_ticks        ; 音符间隔
    add si, 4
    jmp .t
.done:
    int 20h

; ----------------------------------------------------------------------------
;  play_freq：用扬声器播放频率 BX、持续 CX 滴答
; ----------------------------------------------------------------------------
play_freq:
    push ax dx
    ; 开启扬声器
    in al, 61h
    or al, 3
    out 61h, al
    ; 定时器 2 分频
    mov al, 0B6h
    out 43h, al
    mov dx, 0012h           ; 1193182 的高 16 位
    mov ax, 34DEh           ; 低 16 位
    div bx                  ; AX = 分频值
    out 42h, al
    mov al, ah
    out 42h, al
    call delay_ticks
    ; 关闭扬声器
    in al, 61h
    and al, 0FCh
    out 61h, al
    pop dx ax
    ret

s_msg db 'Playing a scale...', 0Dh, 0Ah, '$'
; 频率(Hz), 时长(滴答), ..., 0 结尾
song dw 262,6, 294,6, 330,6, 349,6, 392,6, 440,6, 494,6, 523,12, 0

include 'inc/std.asm'