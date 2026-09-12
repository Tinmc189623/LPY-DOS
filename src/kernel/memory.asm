; ============================================================================
;  memory.asm — MCB 内存管理、PSP 建立、COM 程序加载执行与进程终止
;  进程模型：MCB 链、PSP、EXEC 与程序退出
;
;  Copyright (C) 2026 Nexsteaduser
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
; ============================================================================

; 内存控制块（MCB）字段偏移
MCB_TYPE        equ 0           ; 'M'=中间块, 'Z'=最后块
MCB_OWNER       equ 1           ; 拥有者 PSP 段（0=空闲）
MCB_SIZE        equ 3           ; 块大小（单位：段，即 16 字节）
MCB_NAME        equ 8           ; 8 字节程序名

; ----------------------------------------------------------------------------
;  进程上下文变量
; ----------------------------------------------------------------------------
saved_int22     dd 0            ; 旧的 INT 22h（父进程终止地址）
saved_psp       dw 0            ; 父 PSP 段
saved_ss        dw 0            ; 父进程栈段
saved_sp        dw 0            ; 父进程栈指针
prog_seg        dw 0            ; 当前程序加载段（块段）
prog_size       dw 0            ; 当前程序块段数（用于块内栈顶计算）
mcb_first_seg   dw 0            ; MCB 链首段（内核末尾空闲块的 MCB）
temp_alloc_req  dw 0            ; mc_alloc 请求段数暂存

; ============================================================================
;  内存初始化
; ============================================================================

; ----------------------------------------------------------------------------
;  init_memory：建立 MCB 链
;  布局：内核块（0x1000 起）之后为一个空闲块，直至 640KB 顶端
;  入口：无，出口：无
; ----------------------------------------------------------------------------
init_memory:
        push ax bx es
        ; 内核占用段数 = (end_of_kernel + 15) / 16
        mov ax, end_of_kernel
        add ax, 15
        shr ax, 4
        add ax, KERNEL_SEG       ; ax = 内核末尾段 = 空闲块 MCB 段
        mov [mcb_first_seg], ax
        mov es, ax
        mov byte [es:MCB_TYPE], 'Z'
        mov word [es:MCB_OWNER], 0
        mov bx, MEM_TOP_SEG
        sub bx, ax
        dec bx                  ; 减去 MCB 本身一段
        mov word [es:MCB_SIZE], bx
        pop es bx ax
        ret

; ----------------------------------------------------------------------------
;  mc_alloc：按 first-fit 遍历 MCB 链分配内存（必要时拆分空闲块）
;  入口：BX = 请求段数；出口：AX = 块段（0 表示失败，CF=1）
; ----------------------------------------------------------------------------
mc_alloc:
        push ax cx dx si di es
        mov [temp_alloc_req], bx
        mov ax, [mcb_first_seg]
        test ax, ax
        jz .fail
.scan:
        mov es, ax
        cmp word [es:MCB_OWNER], 0
        jne .next
        ; 空闲块：检查大小是否足够
        mov dx, [es:MCB_SIZE]
        cmp dx, [temp_alloc_req]
        jb .next
        ; ---- 找到空闲块（ES=MCB 段, DX=size）----
        mov si, ax
        inc si                      ; 块段 = MCB 段 + 1
        mov al, [es:MCB_TYPE]
        push ax                     ; 保存原类型（拆分时新空闲块继承）
        mov cx, dx
        sub cx, [temp_alloc_req]
        jz .whole                   ; 恰好整块
        ; ---- 拆分：本块分配请求段数，剩余成为新空闲块 ----
        dec cx                      ; 剩余段数（含新 MCB 一段）
        mov bx, [temp_alloc_req]
        mov word [es:MCB_SIZE], bx
        mov ax, [current_psp]
        mov word [es:MCB_OWNER], ax
        mov byte [es:MCB_TYPE], 'M'
        mov di, si
        add di, bx                  ; 新空闲块 MCB 段 = 块段 + 请求段数
        mov es, di
        pop ax                      ; 原类型（'M'/'Z'）
        mov byte [es:MCB_TYPE], al
        mov word [es:MCB_OWNER], 0
        mov word [es:MCB_SIZE], cx
        jmp .ok
.whole:
        ; ---- 整块分配：占用全部，owner 设为当前 PSP，类型保持 ----
        mov ax, [current_psp]
        mov word [es:MCB_OWNER], ax
        pop ax                      ; 丢弃原类型（占用后保持 M/Z）
.ok:
        mov ax, si
        clc
        jmp .done
.next:
        ; 移动到下一 MCB：当前 MCB 段 + size + 1
        cmp byte [es:MCB_TYPE], 'Z'
        je .fail                    ; 链尾且未找到足够空闲块
        mov bx, [es:MCB_SIZE]
        inc bx
        add ax, bx
        jmp .scan
.fail:
        xor ax, ax
        stc
.done:
        ; AX 是本函数返回值（块段 / 0），不能恢复调用者 AX，否则返回值被覆盖、
        ; 调用方会把“请求段数”当成加载段（曾导致 shell 加载到幽灵段 0x17B）。
        ; 栈中还压着入口保存的 caller AX，用 add sp,2 丢弃它。
        pop es di si dx cx
        add sp, 2
        ret

; ----------------------------------------------------------------------------
;  mc_free：释放内存块，并与前/后相邻空闲块合并
;  入口：AX = 块段；出口：无
; ----------------------------------------------------------------------------
mc_free:
        push ax bx cx dx si es
        dec ax
        mov si, ax              ; 本 MCB 段
        mov es, ax
        mov word [es:MCB_OWNER], 0
        ; ---- 与后续相邻空闲块合并 ----
.merge_next:
        mov al, [es:MCB_TYPE]
        cmp al, 'Z'
        je .find_prev
        mov cx, [es:MCB_SIZE]
        inc cx
        mov di, si
        add di, cx              ; 下一 MCB 段
        mov es, di
        cmp word [es:MCB_OWNER], 0
        jne .find_prev
        ; 下一块空闲：并入本块
        mov al, [es:MCB_TYPE]   ; 下一类型（可能 'Z'）
        mov bl, al
        mov ax, [es:MCB_SIZE]
        add cx, ax              ; cx = 本块size+1 + 下一块size
        mov es, si
        mov word [es:MCB_SIZE], cx
        mov byte [es:MCB_TYPE], bl
        jmp .merge_next
.find_prev:
        ; 从链首遍历找本块的前一 MCB（无则本块即链首）
        mov ax, [mcb_first_seg]
        cmp ax, si
        je .done
.prev_scan:
        mov es, ax
        mov cx, [es:MCB_SIZE]
        inc cx
        add ax, cx              ; 下一 MCB 段
        cmp ax, si
        je .found_prev          ; ES 此时指向前一 MCB
        cmp byte [es:MCB_TYPE], 'Z'
        je .done                ; 链尾未找到（异常，直接返回）
        jmp .prev_scan
.found_prev:
        ; ES 指向前一 MCB，AX 已被覆盖为 si，用 ES 取前一块段
        mov dx, es              ; 保存前一 MCB 段
        cmp word [es:MCB_OWNER], 0
        jne .done               ; 前一块不空闲，不合并
        ; 合并：前一块 size 扩展为包含本块
        mov cx, si
        sub cx, dx              ; cx = 本MCB段 - 前MCB段 = 前块size+1
        mov ax, si
        mov es, ax
        mov bx, [es:MCB_SIZE]   ; 本块 size
        add cx, bx              ; cx = 合并后 size
        mov bl, [es:MCB_TYPE]   ; 本块类型（吸收链尾后为 'Z'，标记不能丢）
        mov es, dx
        mov word [es:MCB_SIZE], cx
        mov byte [es:MCB_TYPE], bl
.done:
        pop es si dx cx bx ax
        ret

; ============================================================================
;  INT 21h 内存管理 API（AH=48/49/4A）
; ============================================================================

; 调整大小用的临时变量
temp_resize_mcb  dw 0           ; 本 MCB 段
temp_resize_new  dw 0           ; 新大小
temp_resize_type db 0           ; 原块类型

; ----------------------------------------------------------------------------
;  fn_alloc：INT 21h AH=48 分配内存块
;  入口：BX = 请求段数；出口：AX = 块段（CF=0）；失败 CF=1 且 AX=8（内存不足）
; ----------------------------------------------------------------------------
fn_alloc:
        test bx, bx
        jz .err
        call mc_alloc
        jnc .done
.err:
        mov ax, 8
        stc
.done:
        ret

; ----------------------------------------------------------------------------
;  fn_free：INT 21h AH=49 释放内存块
;  入口：ES = 块段；出口：CF=0 成功；CF=1 且 AX=9（无效块）
; ----------------------------------------------------------------------------
fn_free:
        mov ax, es
        test ax, ax
        jz .err
        call mc_free
        clc
        ret
.err:
        mov ax, 9
        stc
        ret

; ----------------------------------------------------------------------------
;  fn_resize：INT 21h AH=4A 调整内存块大小
;  入口：ES = 块段, BX = 新段数；出口：CF=0 成功；CF=1 且 AX=7/9 失败
; ----------------------------------------------------------------------------
fn_resize:
        mov ax, es
        test ax, ax
        jz .err9
        dec ax
        mov [temp_resize_mcb], ax   ; 本 MCB 段
        mov es, ax
        mov al, [es:MCB_TYPE]
        mov [temp_resize_type], al  ; 保存原类型
        mov cx, [es:MCB_SIZE]       ; 当前大小
        cmp bx, cx
        jbe .shrink
        ; ---- 增大：需下一块空闲且合并后足够 ----
        cmp al, 'Z'
        je .err7                    ; 链尾无法增大
        mov [temp_resize_new], bx
        mov ax, es
        add ax, cx
        inc ax                      ; 下一 MCB 段
        mov es, ax
        cmp word [es:MCB_OWNER], 0
        jne .err7                   ; 下一块不空闲
        mov al, [es:MCB_TYPE]
        mov [temp_resize_type], al  ; 合并后继承下一块类型
        mov dx, [es:MCB_SIZE]
        add cx, dx
        inc cx                      ; cx = 合并后总大小
        cmp cx, [temp_resize_new]
        jb .err7                    ; 合并后仍不够
        ; 合并下一块到本块
        mov es, [temp_resize_mcb]
        mov word [es:MCB_SIZE], cx
        mov bx, [temp_resize_new]
        cmp bx, cx
        je .absorbed            ; 恰好整并：需继承下一块类型
.shrink:
        ; ES = 本 MCB, CX = 当前大小, BX = 新大小
        cmp bx, cx
        jae .done                   ; 无剩余（保持原类型）
        ; 有剩余：本块缩到 BX，剩余段拆为新空闲块
        mov dx, cx
        sub dx, bx
        dec dx                      ; 剩余段数
        mov word [es:MCB_SIZE], bx
        mov byte [es:MCB_TYPE], 'M' ; 本块变为中间块
        ; 新空闲块 MCB 段 = 本 MCB 段 + bx + 1
        mov ax, [temp_resize_mcb]
        add ax, bx
        inc ax
        mov di, ax
        mov es, ax
        mov al, [temp_resize_type]  ; 新空闲块继承原类型（M/Z）
        mov byte [es:MCB_TYPE], al
        mov word [es:MCB_OWNER], 0
        mov word [es:MCB_SIZE], dx
.absorbed:
        ; 恰好吞并整个下一块：本块继承其类型（'Z' 链尾标记不能丢）
        mov al, [temp_resize_type]
        mov byte [es:MCB_TYPE], al
        jmp .done
.done:
        clc
        ret
.err7:
        mov ax, 7
        stc
        ret
.err9:
        mov ax, 9
        stc
        ret

; ============================================================================
;  PSP 建立
; ============================================================================

; ----------------------------------------------------------------------------
;  setup_sys_psp：建立内核自身 PSP（SYS_PSP_SEG）并登记为当前 PSP
;  入口：无，出口：无
; ----------------------------------------------------------------------------
setup_sys_psp:
        push ax bx cx es
        mov ax, SYS_PSP_SEG
        mov es, ax
        ; PSP+0：INT 20h 指令（程序终止）
        mov byte [es:0], 0CDh
        mov byte [es:1], 20h
        ; PSP+2：内存顶端段
        mov word [es:2], MEM_TOP_SEG
        ; PSP+0A~0x14：从 IVT 拷贝 INT 22h/23h/24h 地址
        xor ax, ax
        mov bx, ax
        mov ds, bx
        mov ax, [22h*4]
        mov [es:0Ah], ax
        mov ax, [22h*4+2]
        mov [es:0Ch], ax
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
        ; PSP+16：父 PSP = 自身
        mov word [es:16h], SYS_PSP_SEG
        ; PSP+2C：环境段 = 0（无环境）
        mov word [es:2Ch], 0
        ; PSP+18：句柄表 20 字节全 0xFF
        mov cx, 20
        mov bx, 18h
.fill:
        mov byte [es:bx], 0FFh
        inc bx
        loop .fill
        ; FCB 区与命令行尾部
        call fill_psp_fields
        ; 默认 DTA = PSP:0x80
        mov word [dta_seg], SYS_PSP_SEG
        mov word [dta_off], 80h
        mov [current_psp], SYS_PSP_SEG
        pop es cx bx ax
        ret

; ----------------------------------------------------------------------------
;  fill_psp_fields：填充 PSP 的 FCB 区与命令行尾部
;  入口：ES = PSP 段（KERNEL_SEG）；命令行取自 exec_cmdline[0]=长度
; ----------------------------------------------------------------------------
fill_psp_fields:
        push ax bx cx si di
        ; PSP+5C/6C：默认 FCB 区填充空格（各 16 字节）
        mov cx, 32
        mov bx, 5Ch
.fill_fcb:
        mov byte [es:bx], 20h
        inc bx
        loop .fill_fcb
        ; PSP+80：命令行尾部长度 + 字符 + 0Dh
        lea si, [exec_cmdline]  ; si = 长度字节
        lea di, [es:80h]
        mov cl, [si]
        xor ch, ch
        mov [di], cl            ; 长度
        inc si
        inc di
        rep movsb               ; 复制字符
        mov byte [es:di], 0Dh   ; 回车
        pop di si cx bx ax
        ret

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

; ============================================================================
;  进程终止
; ============================================================================

; ----------------------------------------------------------------------------
;  do_terminate：程序终止处理
;  跳转到当前 INT 22h（由 exec_buf 设置为返回点）
;  入口：AL = 退出码
; ----------------------------------------------------------------------------
do_terminate:
        mov [term_code], al
        ; 若处于图形模式，先恢复文本模式再返回
        call gfx_terminate
        xor ax, ax
        mov es, ax
        ; retf 弹出顺序是先 IP 后 CS，须先压段、后压偏移
        push word [es:22h*4+2]  ; CS（先压，栈底）
        push word [es:22h*4]    ; IP（后压，栈顶）
        retf

; ----------------------------------------------------------------------------
;  int20_handler：INT 20h 程序终止
; ----------------------------------------------------------------------------
int20_handler:
        mov byte [term_code], 0
        jmp do_terminate

; ----------------------------------------------------------------------------
;  int23_handler：Ctrl-C 处理（默认忽略，直接返回）
; ----------------------------------------------------------------------------
int23_handler:
        iret

; ----------------------------------------------------------------------------
;  int24_handler：严重错误处理（默认忽略，返回 AL=0）
; ----------------------------------------------------------------------------
int24_handler:
        mov al, 0
        iret

; ----------------------------------------------------------------------------
;  int28_handler：DOS 空闲（默认返回）
; ----------------------------------------------------------------------------
int28_handler:
        iret
