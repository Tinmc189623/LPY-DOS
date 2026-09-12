use16
org 0100h
include 'inc/macro.asm'

; ============================================================================
;  wcount.com — 统计输入行的字符数与单词数（空格/制表分隔）
; ============================================================================
start:
    puts s_in
    call readstr
    mov cl, [inbuf+1]
    xor ch, ch
    mov [chars], cx         ; 保存字符数（后面 cx 会被循环消耗）
    lea si, [inbuf+2]
    mov word [wcnt], 0
    xor bx, bx              ; 是否处于单词内（0=否）
.word_scan:
    mov al, [si]
    cmp al, ' '
    je .sp
    cmp al, 9               ; Tab
    je .sp
    ; 非空白：开始/处于单词内
    cmp bl, 0
    jne .next
    inc word [wcnt]         ; 新单词开始
    mov bl, 1
    jmp .next
.sp:
    xor bl, bl              ; 离开单词
.next:
    inc si
    loop .word_scan
    ; 输出统计
    puts s_cnt
    mov ax, [chars]
    call print_dec16
    call crlf
    puts s_wrd
    mov ax, [wcnt]
    call print_dec16
    call crlf
    int 20h

readstr:
    lea dx, [inbuf]
    mov ah, 0Ah
    int 21h
    call crlf
    ret

s_in  db 'Enter text: $'
s_cnt db 'Characters: $'
s_wrd db 'Words: $'
wcnt  dw 0
chars dw 0
inbuf db 128
      db 0
      db 128 dup(0)

logo_attr db 2Ah
logo_data db 'W   W  CCCC   OOO   U   U  N   N  TTTTT$'
          db 'W   W  C     O   O  U   U  NN  N    T  $'
          db 'W W W  C     O   O  U   U  N N N    T  $'
          db 'W W W  C     O   O  U   U  N  NN    T  $'
          db ' W W    CCCC   OOO    UUU   N   N    T  $'
          db 0

include 'inc/std.asm'
include 'inc/logo.asm'