; ============================================================================
;  app.asm — LPY-DOS SDK 综合示例
;  演示三类能力：
;    1) 控制台 I/O     字符串输出、按键读取
;    2) 系统信息获取   版本、日期、时间、驱动器
;    3) 文件系统操作   创建/写入/关闭/重开/读取 一个文本文件
;  编译：fasm app.asm app.COM
;  运行：把 app.COM 放入 LPY-DOS 镜像后，在 LPYCMD 命令行输入 app
; ============================================================================
use16
org 0100h

include '../include/lpydos.inc'

start:
    puts s_title
    call crlf
    call crlf

    ; ================= 1) 控制台 I/O =================
    puts s_step1
    call crlf
    puts s_ask
    call get_key_echo
    call crlf
    call crlf

    ; ================= 2) 系统信息 =================
    puts s_step2
    call crlf

    puts s_ver
    call get_sysver
    push ax
    mov al, ah
    call put_dec16
    putch '.'
    pop ax
    call put_dec16
    call crlf

    puts s_date
    call print_date_line

    puts s_time
    call print_time_line

    puts s_drive
    call get_drive
    add al, 'A'
    call putc
    call crlf
    call crlf

    ; ================= 3) 文件系统 =================
    puts s_step3
    call crlf

    ; 创建 DEMO.TXT
    lea dx, [fname]
    xor cl, cl                      ; 普通属性
    call create_file
    jc fs_err
    mov [fhandle], ax

    ; 写入一段文字
    mov bx, [fhandle]
    lea dx, [fdata]
    mov cx, fdata_len
    call write_file

    ; 关闭
    mov bx, [fhandle]
    call close_file
    puts s_written
    call crlf

    ; 重开并读回
    lea dx, [fname]
    call open_file
    jc fs_err
    mov [fhandle], ax

    mov bx, [fhandle]
    lea dx, [rbuf]
    mov cx, 64
    call read_file
    mov [rlen], ax

    mov bx, [fhandle]
    call close_file

    ; 打印读回内容
    puts s_readback
    call crlf
    lea si, [rbuf]
    mov cx, [rlen]
prt_loop:
    lodsb
    call putc
    loop prt_loop
    call crlf

    call crlf
    puts s_done
    call wait_key
    mov ah, AH_TERM_CD
    xor al, al
    int 21h

fs_err:
    puts s_fserr
    call crlf
    mov ah, AH_TERM_CD
    mov al, 1
    int 21h

; ---------------- 只读数据 ----------------
s_title  db 'LPY-DOS SDK 综合演示',0Dh,0Ah,'$'
s_step1  db '[1] 控制台 I/O',0Dh,0Ah,'$'
s_step2  db '[2] 系统信息',0Dh,0Ah,'$'
s_step3  db '[3] 文件系统操作',0Dh,0Ah,'$'
s_ask    db '按任意键继续...$'
s_ver    db '  LPY-DOS 版本: $'
s_date   db '  日期: $'
s_time   db '  时间: $'
s_drive  db '  当前驱动器: $'
s_written db '写文件完成 -> DEMO.TXT$'
s_readback db '读回内容: $'
s_done   db '演示结束。$'
s_fserr  db '文件操作失败。$'

fname    db 'DEMO.TXT',0
fdata    db 'Hello from a third-party LPY-DOS app!',0Dh,0Ah
         db 'This line was written via INT 21h AH=40h.',0Dh,0Ah
fdata_len = $ - fdata

; ---------------- 可变数据 ----------------
fhandle  dw 0
rlen     dw 0
rbuf     db 64 dup(0)