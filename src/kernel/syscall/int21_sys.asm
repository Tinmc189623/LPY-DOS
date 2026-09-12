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

; AH=30：取版本号（返回 AX=major.minor，如 v1.00 -> AX=0100h）
fn_get_version:
        mov al, VER_MAJOR
        mov ah, VER_MINOR
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

