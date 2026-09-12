start:
        jmp main

; ----------------------------------------------------------------------------
;  常量
; ----------------------------------------------------------------------------
MAXLINE         equ 120         ; 命令行最大长度
BUF512          equ 512         ; COPY/TYPE 传输缓冲

; ----------------------------------------------------------------------------
;  数据区
; ----------------------------------------------------------------------------
echo_flag       db 1            ; 1=显示提示符（ECHO ON）
rbuf            db MAXLINE      ; AH=0A 缓冲：最大长度
rbuf_len        db 0            ; 实际长度
rbuf_data       db MAXLINE dup(0)
cmdline         db MAXLINE dup(0) ; 命令行（0 结尾）
cmd_name        db MAXLINE dup(0)    ; 命令名（大写）
arg1            db MAXLINE dup(0)
arg2            db MAXLINE dup(0)
curpath         db 80 dup(0)    ; 当前目录串（AH=47）
search_mode     db MAXLINE dup(0) ; DIR 搜索模式
exec_path       db MAXLINE dup(0) ; 外部命令路径
copy_buf        db BUF512 dup(0)  ; COPY/TYPE 传输缓冲
exec_tail       db MAXLINE dup(0) ; EXEC 命令行尾部（首字节=长度）
exec_pb         dw 0, exec_tail, 0, 0, 0, 0, 0, 0  ; EXEC 参数块（运行前补命令段）

; 错误/提示字符串（$ 结尾，供 AH=09）
s_crlf          db 0Dh,0Ah,'$'
s_prompt_drv    db 'A:$'        ; 盘符前缀（'A' 占位）
s_prompt_end    db '>$'
s_badcmd        db 'Bad command or file name',0Dh,0Ah,'$'
s_file_not      db 'File not found',0Dh,0Ah,'$'
s_dir_of        db ' Directory of $'
s_file_s        db ' file(s)',0Dh,0Ah,'$'
s_bytes_s       db ' bytes',0Dh,0Ah,'$'
s_copy_ok       db '        1 file(s) copied',0Dh,0Ah,'$'
s_dir_mark      db '<DIR>   $'
s_space4        db '    $'
s_crlf2         db 0Dh,0Ah,0Dh,0Ah,'$'
s_curdate       db 'Current date is $'
s_curtime       db 'Current time is $'
s_ver           db 'LPY-DOS Version ', '0'+VER_MAJOR, '.', '0'+VER_MINOR, '.', '0'+VER_PATCH, 0Dh,0Ah
                db 'Copyright (C) 2026 Nexsteaduser',0Dh,0Ah
                db 'GNU GPL v3 or later',0Dh,0Ah,'$'

s_help          db 'LPY-DOS internal commands:',0Dh,0Ah
                db '  DIR     List directory',0Dh,0Ah
                db '  CD/CHDIR  Change directory',0Dh,0Ah
                db '  MD/MKDIR Make directory',0Dh,0Ah
                db '  RD/RMDIR Remove directory',0Dh,0Ah
                db '  DEL/ERASE  Delete file',0Dh,0Ah
                db '  REN/RENAME Rename file',0Dh,0Ah
                db '  TYPE    Display text file',0Dh,0Ah
                db '  COPY    Copy file',0Dh,0Ah
                db '  CLS     Clear screen',0Dh,0Ah
                db '  VER     Show version',0Dh,0Ah
                db '  DATE/TIME  Show date/time',0Dh,0Ah
                db '  ECHO    Toggle prompt',0Dh,0Ah
                db '  EXIT    Terminate shell',0Dh,0Ah
                db 'Other .COM programs can be run directly.',0Dh,0Ah,'$'

