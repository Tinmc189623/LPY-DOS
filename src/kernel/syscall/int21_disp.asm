; 最大支持的功能号（AH=7F，其中 70h..7Ah 为图形服务）
INT21_MAX       equ 7Fh

; ----------------------------------------------------------------------------
;  save_ax：INT 21h 调用者完整 AX（AH=功能号, AL=子功能）暂存
;  caller_cx：调用者 CX 暂存（.exit 用 CX 合并 CF 标志后按需恢复）
;  调试环形日志：int21_dbg 记录最近 512 次调用的 AH 值（仅诊断用）
; ----------------------------------------------------------------------------
save_ax         dw 0
caller_cx       dw 0
int21_dbg_pos   dw 0
int21_dbg       rb 512

; ----------------------------------------------------------------------------
;  int21_handler：INT 21h 分发入口
;  进入时：DS=调用者数据段，其余寄存器为调用参数
;  出口：按 API 约定返回，CF=1 表示错误（AX 为错误码）
;  说明：入口先把调用者 AX/DS/ES 压栈，设 DS=KERNEL_SEG 后再写内核变量，
;        避免在调用者段下把变量写错位置。
; ----------------------------------------------------------------------------
int21_handler:
        pushf
        cli
        push es                 ; 保存调用者 ES
        push ds                 ; 保存调用者 DS
        push ax                 ; 保存调用者 AX（功能号在 AH，置于栈顶便于弹出）
        mov ax, KERNEL_SEG
        mov ds, ax
        mov es, ax
        ; 栈（bp=sp）：[bp]=bp,[bp+2]=调用者AX,[bp+4]=调用者DS,[bp+6]=调用者ES...
        push bp
        mov bp, sp
        mov ax, [bp+2]          ; 调用者 AX
        mov [save_ax], ax       ; 保存完整 AX（AH=功能号, AL=子功能）
        mov ax, [bp+4]          ; 调用者 DS
        mov [caller_ds], ax
        mov ax, [bp+6]          ; 调用者 ES
        mov [caller_es], ax
        mov ax, cx              ; 暂存调用者 CX（此刻 CX 尚未被改动）
        mov [caller_cx], ax
        pop bp
        pop ax                  ; 弹出调用者 AX（栈顶）
        ; 栈：[ds][es][my_pushf][IP][CS][FLAGS]
        ; 仅保留 bx,si,di,bp，ax/cx/dx 供返回
        push bx si di bp
        ; 调试：把本次功能号记入环形日志（bx/ax 已保存，可自由使用）
        mov bx, [int21_dbg_pos]
        mov ax, [save_ax]
        mov [int21_dbg+bx], ah
        inc bx
        and bx, 01FFh
        mov [int21_dbg_pos], bx
        ; 分发：用 AH 计算表索引，被调函数仍收到完整调用者 AX
        mov ax, [save_ax]
        mov al, ah              ; 功能号
        xor ah, ah
        cmp ax, INT21_MAX
        ja .unsupported
        shl ax, 1
        mov si, ax              ; si = 2*功能号（临时占用：CX 例外判定用，出口统一弹栈恢复）
        mov ax, [save_ax]       ; 恢复调用者 AX（AH=功能号, AL=子功能）
        call word [int21_table+si]
        ; 恢复调用者 CX：2Ah/2Ch/30h 的 CX 是返回值，保持功能 CX 不动。
        ; 必须赶在 pop ds 之前读 [caller_cx]（caller DS 已是调用者段），
        ; 且不得占用 AX/DX——它们是 19h/2Ah/2Ch 等功能的返回值
        cmp si, 2Ah*2
        je .cx_done
        cmp si, 2Ch*2
        je .cx_done
        cmp si, 30h*2
        je .cx_done
        mov cx, [caller_cx]
.cx_done:
        ; 检查终止请求
        cmp byte [term_request], 0
        jne .terminate_path
        jmp .exit

.unsupported:
        ; 未实现功能：AX=0, CF=1
        xor ax, ax
        stc
        jmp .exit

.exit:
        ; 恢复保留寄存器并传递 CF；AX/CX/DX 保留功能返回值，不再破坏
        pop bp di si bx
        pop ds
        pop es
        mov bp, sp               ; bp → [my pushf]
        jnc .nocf                ; 处理后的 CF 写回调用者 FLAGS
        or word [bp+6], 1
        jmp .cfdone
.nocf:
        and word [bp+6], 0FFFEh
.cfdone:
        add sp, 2                ; 丢弃 my pushf
        iret

.terminate_path:
        ; 程序请求终止：清理 INT 21h 栈帧后进入 do_terminate
        pop bp di si bx
        pop ds
        pop es
        add sp, 2                ; 丢弃 my pushf
        add sp, 6                ; 丢弃调用者 IP/CS/FLAGS
        mov ax, KERNEL_SEG
        mov ds, ax
        jmp do_terminate

; ----------------------------------------------------------------------------
;  INT 21h 功能跳转表（0x00 ~ 0x7F）
; ----------------------------------------------------------------------------
int21_table:
        dw fn_terminate         ; 00 终止程序
        dw fn_read_char         ; 01 读字符带回显
        dw fn_write_char        ; 02 写字符
        dw fn_unknown           ; 03
        dw fn_unknown           ; 04
        dw fn_unknown           ; 05
        dw fn_con_io            ; 06 直接控制台 I/O
        dw fn_unknown           ; 07
        dw fn_unknown           ; 08
        dw fn_write_string      ; 09 写 $ 结尾字符串
        dw fn_buffered_input    ; 0A 缓冲输入
        dw fn_check_input       ; 0B 检查输入状态
        dw fn_clear_read        ; 0C 清缓冲后读
        dw fn_disk_reset        ; 0D 磁盘复位
        dw fn_select_drive      ; 0E 选择默认驱动器
        dw fn_unknown           ; 0F
        dw fn_unknown           ; 10
        dw fn_unknown           ; 11
        dw fn_unknown           ; 12
        dw fn_unknown           ; 13
        dw fn_unknown           ; 14
        dw fn_unknown           ; 15
        dw fn_unknown           ; 16
        dw fn_unknown           ; 17
        dw fn_unknown           ; 18
        dw fn_get_drive         ; 19 取默认驱动器
        dw fn_set_dta           ; 1A 设置 DTA 地址
        dw fn_drive_info        ; 1B 取驱动器数据
        dw fn_drive_info        ; 1C 取驱动器数据（默认盘）
        dw fn_unknown           ; 1D
        dw fn_unknown           ; 1E
        dw fn_unknown           ; 1F
        dw fn_unknown           ; 20
        dw fn_unknown           ; 21
        dw fn_unknown           ; 22
        dw fn_unknown           ; 23
        dw fn_set_vector        ; 24
        dw fn_set_vector        ; 25 设置中断向量
        dw fn_unknown           ; 26
        dw fn_unknown           ; 27
        dw fn_unknown           ; 28
        dw fn_unknown           ; 29
        dw fn_get_date          ; 2A 取系统日期
        dw fn_set_date          ; 2B 设系统日期
        dw fn_get_time          ; 2C 取系统时间
        dw fn_set_time          ; 2D 设系统时间
        dw fn_set_verify        ; 2E 写后校验开关
        dw fn_get_dta           ; 2F 取 DTA 地址
        dw fn_get_version       ; 30 取版本号
        dw fn_unknown           ; 31
        dw fn_unknown           ; 32
        dw fn_ctrlc             ; 33 取/设 Ctrl-C 开关
        dw fn_indos             ; 34 取 InDOS 标志指针
        dw fn_get_vector        ; 35 取中断向量
        dw fn_unknown           ; 36
        dw fn_unknown           ; 37
        dw fn_unknown           ; 38
        dw fn_mkdir             ; 39 创建目录
        dw fn_rmdir             ; 3A 删除目录
        dw fn_chdir             ; 3B 改变当前目录
        dw fn_create            ; 3C 创建文件
        dw fn_open              ; 3D 打开文件
        dw fn_close             ; 3E 关闭文件
        dw fn_read              ; 3F 读文件
        dw fn_write             ; 40 写文件
        dw fn_delete            ; 41 删除文件
        dw fn_lseek             ; 42 移动文件指针
        dw fn_getattr           ; 43 取/设文件属性
        dw fn_ioctl             ; 44 设备 IOCTL
        dw fn_unknown           ; 45
        dw fn_unknown           ; 46
        dw fn_get_cwd           ; 47 取当前目录
        dw fn_alloc             ; 48 分配内存块
        dw fn_free              ; 49 释放内存块
        dw fn_resize            ; 4A 调整内存块大小
        dw fn_exec              ; 4B 执行程序
        dw fn_exit              ; 4C 退出进程
        dw fn_get_return_code   ; 4D 取子进程返回码
        dw fn_findfirst         ; 4E 查找第一个匹配文件
        dw fn_findnext          ; 4F 查找下一个匹配文件
        dw fn_unknown           ; 50
        dw fn_unknown           ; 51
        dw fn_unknown           ; 52
        dw fn_unknown           ; 53
        dw fn_get_verify        ; 54 取校验开关
        dw fn_unknown           ; 55
        dw fn_rename            ; 56 重命名文件
        dw fn_filetime          ; 57 取/设文件日期时间
        dw fn_alloc_strategy    ; 58 取/设内存分配策略
        dw fn_unknown           ; 59
        dw fn_unknown           ; 5A
        dw fn_unknown           ; 5B
        dw fn_unknown           ; 5C
        dw fn_unknown           ; 5D
        dw fn_unknown           ; 5E
        dw fn_unknown           ; 5F
        dw fn_unknown           ; 60
        dw fn_unknown           ; 61
        dw fn_get_psp           ; 62 取 PSP 段
        dw fn_unknown           ; 63
        dw fn_unknown           ; 64
        dw fn_unknown           ; 65
        dw fn_unknown           ; 66
        dw fn_unknown           ; 67
        dw fn_unknown           ; 68
        dw fn_unknown           ; 69
        dw fn_unknown           ; 6A
        dw fn_unknown           ; 6B
        dw fn_unknown           ; 6C
        dw fn_unknown           ; 6D
        dw fn_unknown           ; 6E
        dw fn_unknown           ; 6F
        dw fn_gfx_init          ; 70 进入图形模式
        dw fn_gfx_exit          ; 71 恢复文本模式
        dw fn_gfx_pixel         ; 72 画点
        dw fn_gfx_hline         ; 73 水平线
        dw fn_gfx_vline         ; 74 垂直线
        dw fn_gfx_fillrect      ; 75 填充矩形
        dw fn_gfx_frame         ; 76 矩形边框
        dw fn_gfx_circle        ; 77 画圆
        dw fn_gfx_fillcircle    ; 78 填充圆
        dw fn_gfx_pal           ; 79 设置调色板
        dw fn_gfx_text          ; 7A 图形文本
        dw fn_unknown           ; 7B
        dw fn_unknown           ; 7C
        dw fn_unknown           ; 7D
        dw fn_unknown           ; 7E
        dw fn_unknown           ; 7F

; ============================================================================
;  未实现功能处理
; ============================================================================
fn_unknown:
        xor ax, ax
        stc
        ret

