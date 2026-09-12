; ============================================================================
;  COM 程序加载与执行
; ============================================================================

; ----------------------------------------------------------------------------
;  exec_com：加载并执行 COM 程序（供内核内部使用）
;  入口：DS:SI = 0 结尾路径（DS=KERNEL_SEG）
;  出口：程序结束后返回（AX = 退出码）
; ----------------------------------------------------------------------------
exec_com:
        push ax si di
        lea di, [path_buf]
.copy:
        mov al, [si]
        mov [di], al
        inc si
        inc di
        test al, al
        jnz .copy
        pop di si ax
        mov byte [exec_cmdline], 0   ; 内部执行无命令行
        ; 落入 exec_buf

; ----------------------------------------------------------------------------
;  exec_buf：按 path_buf 中的路径加载并执行 COM 程序
;  入口：path_buf = 路径；出口：程序结束后返回（AX = 退出码）
; ----------------------------------------------------------------------------
exec_buf:
        push ax bx cx dx si di bp
        ; ---- 保存父进程上下文 ----
        mov ax, [current_psp]
        mov [saved_psp], ax
        mov ax, ss
        mov [saved_ss], ax
        mov [saved_sp], sp
        ; 保存旧 INT 22h
        xor ax, ax
        mov es, ax
        mov ax, [es:22h*4]
        mov word [saved_int22], ax
        mov ax, [es:22h*4+2]
        mov word [saved_int22+2], ax
        ; 设置 INT 22h = 返回点
        mov ax, .ret
        mov [es:22h*4], ax
        mov ax, KERNEL_SEG
        mov [es:22h*4+2], ax
        ; ---- 查找文件，取大小 ----
        mov [caller_ds], KERNEL_SEG
        mov [caller_es], KERNEL_SEG
        mov dx, path_buf
        call fat_find_file
        jc .err
        ; ---- 分配内存：文件 + PSP(0x100) + 栈(1KB) ----
        mov ax, word [find_size]
        mov cx, 16
        xor dx, dx
        div cx
        add ax, 16              ; + PSP（16 段）
        add ax, 64              ; + 栈（64 段 = 1KB）
        mov bx, ax
        call mc_alloc
        test ax, ax
        jz .err
        mov [prog_seg], ax
        mov ax, [temp_alloc_req] ; mc_alloc 入口保存了请求段数
        mov [prog_size], ax
        ; ---- 加载文件到 prog_seg:0x100 ----
        mov ax, [prog_seg]
        mov es, ax
        mov di, 100h
        call load_file_clusters
        jc .err_free
        ; ---- 建立子进程 PSP ----
        mov ax, [prog_seg]
        mov es, ax
        mov byte [es:0], 0CDh
        mov byte [es:1], 20h
        mov word [es:0Ah], .ret
        mov word [es:0Ch], KERNEL_SEG
        xor ax, ax
        mov bx, ax
        mov ds, bx
        mov ax, [23h*4]
        mov [es:0Eh], ax
        mov ax, [23h*4+2]
        mov [es:10h], ax
        mov ax, [24h*4]
        mov [es:12h], ax
        mov ax, [24h*4+2]
        mov [es:14h], ax
        mov ax, KERNEL_SEG
        mov ds, ax
        mov ax, [saved_psp]
        mov [es:16h], ax        ; 父 PSP
        mov word [es:2Ch], 0    ; 环境段
        mov cx, 20
        mov bx, 18h
.fill_h:
        mov byte [es:bx], 0FFh
        inc bx
        loop .fill_h
        ; FCB 区与命令行尾部
        call fill_psp_fields
        ; 子进程 DTA = PSP:0x80
        mov ax, [prog_seg]
        mov [dta_seg], ax
        mov word [dta_off], 80h
        ; ---- 计算块内栈顶（SP = 块段数*16 - 2），避免越过分配块 ----
        mov ax, [prog_size]
        shl ax, 4
        sub ax, 2
        mov bx, [prog_seg]
        ; ---- 切换当前 PSP 并进入子进程 ----
        mov [current_psp], bx
        mov ds, bx
        mov es, bx
        cli
        mov ss, bx
        mov sp, ax
        sti
        ; BX 此刻仍持有 prog_seg，直接用 push bx 压入正确段值
        push bx
        push 100h
        retf
.ret:
        ; ---- 程序终止返回点 ----
        mov ax, KERNEL_SEG
        mov ds, ax
        mov es, ax
        cli
        mov ax, [saved_ss]
        mov ss, ax
        mov sp, [saved_sp]
        sti
        mov ax, [saved_psp]
        mov [current_psp], ax
        ; 子进程可能已置 term_request（如 AH=4C），父进程 EXEC 调用应正常返回，
        ; 必须重置，否则父进程的 INT 21h handler 会误走终止路径
        mov byte [term_request], 0
        ; 恢复 INT 22h
        xor ax, ax
        mov es, ax
        mov ax, word [saved_int22]
        mov [es:22h*4], ax
        mov ax, word [saved_int22+2]
        mov [es:22h*4+2], ax
        ; 释放程序内存
        mov ax, [prog_seg]
        call mc_free
        ; 返回退出码
        mov al, [term_code]
        xor ah, ah
        pop bp di si dx cx bx ax
        ret
.err_free:
        mov ax, [prog_seg]
        call mc_free
.err:
        mov ax, 2
        stc
        pop bp di si dx cx bx ax
        ret

; ============================================================================
;  AH=4B 执行程序
; ============================================================================

; ----------------------------------------------------------------------------
;  fn_exec：INT 21h AH=4B 执行程序（仅支持 AL=0，COM 文件）
;  入口：DS:DX = 路径（调用者段），ES:BX = EXEC 参数块
;  参数块：[+0]环境段 [+2]命令偏移 [+4]命令段 [+6..]FCB1/FCB2
;  命令字符串：首字节长度，随后字符，以 0Dh 结尾
; ----------------------------------------------------------------------------
fn_exec:
        cmp al, 0
        jne .err
        push es si di
        ; ---- 拷贝路径 ----
        mov ax, [caller_ds]
        mov es, ax
        mov si, dx
        lea di, [path_buf]
.copy:
        mov al, [es:si]
        mov [di], al
        inc si
        inc di
        test al, al
        jnz .copy
        ; ---- 从参数块拷贝命令行到 exec_cmdline ----
        mov ax, [caller_es]
        mov es, ax
        mov si, bx               ; 参数块偏移
        mov bx, [es:si+4]        ; 命令段
        mov si, [es:si+2]        ; 命令偏移
        mov es, bx
        lea di, [exec_cmdline]
        mov al, [es:si]          ; 长度
        cmp al, 126              ; 钳制上限，防越界
        jbe .len_ok
        mov al, 126
.len_ok:
        mov [di], al
        xor cx, cx
        mov cl, al
        inc si
        inc di
.tail:
        mov al, [es:si]
        mov [di], al
        inc si
        inc di
        loop .tail
        mov byte [di], 0Dh       ; 末尾回车
        pop di si es
        call exec_buf
        ret
.err:
        mov ax, 1
        stc
        ret

