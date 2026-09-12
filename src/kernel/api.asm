; ============================================================================
;  api.asm — INT 21h 系统调用分发与系统服务
;  INT 21h 系统调用接口
; ============================================================================

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
        mov si, ax
        mov ax, [save_ax]       ; 恢复调用者 AX（AH=功能号, AL=子功能）
        call word [int21_table+si]
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
        ; 恢复保留寄存器并传递 CF
        pop bp di si bx
        pop ds
        pop es
        mov bp, sp               ; 指向 [my pushf]
        pushf
        pop ax                   ; 处理后 flags（含 CF）
        and ax, 1
        mov cx, [bp+6]           ; 调用者 flags
        and cx, 0FFFEh
        or cx, ax
        mov [bp+6], cx
        ; CX 刚被用作标志合并暂存；除以 CX 返回值的功能外一律恢复调用者 CX，
        ; 否则调用方 putch 后的 loop 会拿到 FLAGS 值当计数、弹飞整个栈
        mov ax, [save_ax]
        cmp ah, 2Ah             ; 取系统日期：CX=年
        je .keep_cx
        cmp ah, 2Ch             ; 取系统时间：CX=时分
        je .keep_cx
        cmp ah, 30h             ; 取版本号：CX=0
        je .keep_cx
        mov cx, [caller_cx]
.keep_cx:
        pop ax                   ; 丢弃 my pushf
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
        dw fn_unknown           ; 0D
        dw fn_unknown           ; 0E
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
        dw fn_unknown           ; 1B
        dw fn_unknown           ; 1C
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
        dw fn_unknown           ; 2B
        dw fn_get_time          ; 2C 取系统时间
        dw fn_unknown           ; 2D
        dw fn_unknown           ; 2E
        dw fn_unknown           ; 2F
        dw fn_get_version       ; 30 取版本号
        dw fn_unknown           ; 31
        dw fn_unknown           ; 32
        dw fn_unknown           ; 33
        dw fn_unknown           ; 34
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
        dw fn_unknown           ; 4D
        dw fn_findfirst         ; 4E 查找第一个匹配文件
        dw fn_findnext          ; 4F 查找下一个匹配文件
        dw fn_unknown           ; 50
        dw fn_unknown           ; 51
        dw fn_unknown           ; 52
        dw fn_unknown           ; 53
        dw fn_unknown           ; 54
        dw fn_unknown           ; 55
        dw fn_rename            ; 56 重命名文件
        dw fn_filetime          ; 57 取/设文件日期时间
        dw fn_unknown           ; 58
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

; ============================================================================
;  内部工具：字符输出 / 键盘输入 / 字符串输出 / BCD 转换
; ============================================================================

; ----------------------------------------------------------------------------
;  put_char：向屏幕输出一个字符
;  入口：AL = 字符
;  说明：QEMU 的 VGABIOS teletype（AH=0Eh）不遵守 BIOS 约定，实测会破坏
;        CX/SI/DX。调用方（print_dec16 的 loop、print_str 的 lodsb 循环）
;        依赖这些寄存器跨调用存活，故在此统一保存全部现场。
; ----------------------------------------------------------------------------
put_char:
        push ax bx cx dx si di bp
        push ds es
        mov ah, 0Eh
        mov bx, 0007h
        int 10h
        pop es ds
        pop bp di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  kbd_read_char：从键盘读取一个字符（阻塞）
;  出口：AL = 字符；若是扩展键则 AL = 0
; ----------------------------------------------------------------------------
kbd_read_char:
        xor ah, ah
        int 16h
        test al, al
        jnz .done
        ; 扩展键：丢弃第二字节，返回 0
        xor ah, ah
        int 16h
        xor al, al
.done:
        ret

; ----------------------------------------------------------------------------
;  print_str：输出以 0 结尾的字符串（内核段内使用）
;  入口：DS:SI = 字符串
; ----------------------------------------------------------------------------
print_str:
        push ax
        push si
.loop:
        lodsb
        test al, al
        jz .done
        call put_char
        jmp .loop
.done:
        pop si
        pop ax
        ret

; ----------------------------------------------------------------------------
;  read_line：从键盘读入一行到 line_data（line_buf[0] 为最大长度）
;  支持退格、Enter、Ctrl-C；行数据以 0 结尾；line_len 保存实际长度
; ----------------------------------------------------------------------------
read_line:
        push ax bx cx dx si di
        mov byte [line_len], 0
        mov si, line_data
        mov bl, [line_buf]
        xor bh, bh
.loop:
        call kbd_read_char
        cmp al, 0Dh             ; Enter
        je .done
        cmp al, 08h             ; Backspace
        je .bs
        cmp al, 03h             ; Ctrl-C
        je .ctrlc
        cmp al, 1Bh             ; ESC
        je .ctrlc
        cmp al, ' '
        jb .loop                ; 其他控制字符忽略
        mov cl, [line_len]
        cmp cl, [line_buf]
        jae .loop               ; 已满则忽略
        mov [si], al
        inc si
        inc byte [line_len]
        call put_char
        jmp .loop
.bs:
        cmp byte [line_len], 0
        je .loop
        dec si
        dec byte [line_len]
        mov al, 08h
        call put_char
        mov al, ' '
        call put_char
        mov al, 08h
        call put_char
        jmp .loop
.ctrlc:
        mov al, '^'             ; 打印 ^C
        call put_char
        mov al, 'C'
        call put_char
        mov byte [line_len], 0
        mov si, line_data
        jmp .loop
.done:
        mov al, 0Dh
        call put_char
        mov al, 0Ah
        call put_char
        mov byte [si], 0
        pop di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  upper：将 AL 转为大写字母
;  入口：AL = 字符；出口：AL = 大写形式（非字母不变）
; ----------------------------------------------------------------------------
upper:
        cmp al, 'a'
        jb .done
        cmp al, 'z'
        ja .done
        sub al, 20h
.done:
        ret

; ----------------------------------------------------------------------------
;  bcd_to_bin：BCD 码转二进制
;  入口：AL = BCD；出口：AL = 二进制
; ----------------------------------------------------------------------------
bcd_to_bin:
        push bx cx
        mov bl, al
        and bl, 0Fh              ; 低位
        mov cl, al
        shr cl, 4                ; 高位
        mov al, cl
        mov cl, 10
        mul cl                   ; ax = 高位 * 10
        add al, bl
        pop cx bx
        ret

; ============================================================================
;  字符 I/O 服务
; ============================================================================

; AH=01：读一个字符（带回显），返回 AL
fn_read_char:
        call kbd_read_char
        push ax
        call put_char            ; 回显
        pop ax
        ret

; AH=02：写一个字符（DL）
fn_write_char:
        mov al, dl
        call put_char
        ret

; AH=06：直接控制台 I/O
;   DL=0FFh 读（无键时 AL=0）；否则写 DL
fn_con_io:
        cmp dl, 0FFh
        je .read
        mov al, dl
        call put_char
        ret
.read:
        mov ah, 01h
        int 16h
        jz .none
        xor ah, ah
        int 16h
        ret
.none:
        xor al, al
        ret

; AH=09：输出 $ 结尾字符串（DS:DX，调用者段）
fn_write_string:
        mov es, [caller_ds]
        mov si, dx
.loop:
        mov al, [es:si]
        cmp al, '$'
        je .done
        push si
        call put_char
        pop si
        inc si
        jmp .loop
.done:
        ret

; AH=0A：缓冲输入
;   入口：DS:DX = 缓冲（[0]=最大长度, [1]=实际, [2..]=数据）
fn_buffered_input:
        mov es, [caller_ds]
        mov di, dx
        mov al, [es:di]          ; 调用者最大长度
        mov [line_buf], al
        call read_line
        mov cl, [line_len]
        mov [es:di+1], cl
        mov si, line_data
        xor ch, ch
        add di, 2
        rep movsb
        ret

; AH=0B：检查输入状态，有键 AL=0FFh，无键 AL=0
fn_check_input:
        mov ah, 01h
        int 16h
        jz .none
        mov al, 0FFh
        ret
.none:
        xor al, al
        ret

; AH=0C：清键盘缓冲后按 AL 指定读方式读取
fn_clear_read:
        push ax
.flush:
        mov ah, 01h
        int 16h
        jz .done_flush
        xor ah, ah
        int 16h
        jmp .flush
.done_flush:
        pop ax
        cmp al, 0Ah
        je fn_buffered_input
        jmp fn_read_char

; ============================================================================
;  系统服务
; ============================================================================

; AH=00：终止程序（等同 INT 20h）
fn_terminate:
        mov byte [term_request], 1
        ret

; AH=19：取默认驱动器号
fn_get_drive:
        mov al, [current_drive]
        ret

; AH=1A：设置磁盘传输区（DTA）地址
;  入口：DS:DX = 新 DTA；此后 findfirst/findnext 结果写入该处
fn_set_dta:
        mov ax, [caller_ds]
        mov [dta_seg], ax
        mov [dta_off], dx
        ret

; AH=25：设置中断向量（AL=中断号, DS:DX=处理函数）
fn_set_vector:
        mov cx, dx               ; 保存偏移
        xor ax, ax
        mov es, ax
        mov bl, al
        xor bh, bh
        shl bx, 2                ; IVT 偏移 = 中断号 * 4
        mov ax, [caller_ds]      ; 段
        mov [es:bx], cx
        mov [es:bx+2], ax
        ret

; AH=35：取中断向量（AL=中断号, 返回 ES:BX）
fn_get_vector:
        xor ax, ax
        mov es, ax
        mov bl, al
        xor bh, bh
        shl bx, 2
        mov ax, [es:bx+2]
        mov bx, [es:bx]
        mov es, ax
        ret

; AH=30：取版本号（返回 AX=0100h 表示 v1.00）
fn_get_version:
        mov ax, 0100h
        xor bx, bx
        xor cx, cx
        ret

; AH=2A：取系统日期（CX=年, DH=月, DL=日, AL=星期）
fn_get_date:
        mov ah, 04h
        int 1Ah
        ; CH=世纪(BCD), CL=年(BCD), DH=月(BCD), DL=日(BCD), AL=星期
        push ax                  ; 暂存星期
        mov al, ch
        call bcd_to_bin          ; AL = 世纪
        mov bl, 100
        mul bl                   ; AX = 世纪 * 100（8 位乘法不破坏 DX，月/日尚在 DH/DL）
        mov si, ax
        mov al, cl
        call bcd_to_bin          ; AL = 年
        xor ah, ah
        add ax, si               ; AX = 世纪*100 + 年
        mov cx, ax               ; CX = 完整年份
        mov al, dh
        call bcd_to_bin
        mov dh, al               ; 月
        mov al, dl
        call bcd_to_bin
        mov dl, al               ; 日
        pop ax                   ; AL = 星期
        ret

; AH=2C：取系统时间（CH=时, CL=分, DH=秒, DL=百分秒）
fn_get_time:
        mov ah, 02h
        int 1Ah
        mov al, ch
        call bcd_to_bin
        mov ch, al
        mov al, cl
        call bcd_to_bin
        mov cl, al
        mov al, dh
        call bcd_to_bin
        mov dh, al
        mov al, dl
        call bcd_to_bin
        mov dl, al
        ret

; AH=44：设备 IOCTL（简化：标准句柄 0/1/2 返回字符设备标志）
fn_ioctl:
        mov ax, 0
        cmp bx, 2
        ja .error
        ; 返回 AL=设备信息：bit7=1 表示字符设备
        mov al, 80h
        clc
        ret
.error:
        mov ax, 6
        stc
        ret

; AH=4C：退出进程（AL=退出码）
fn_exit:
        mov [term_code], al
        mov byte [term_request], 1
        ret

; AH=62：取 PSP 段
fn_get_psp:
        mov bx, [current_psp]
        ret
