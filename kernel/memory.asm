; ============================================================================
;  memory.asm — MCB 内存管理、PSP 建立、COM 程序加载执行与进程终止
;  对标 MS-DOS 的进程模型：MCB 链、PSP、EXEC 与程序退出
;
;  Copyright (C) 2026 Nexlyh
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
free_mcb_seg    dw 0            ; 空闲块 MCB 段（0=无空闲）

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
        mov [free_mcb_seg], ax
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
;  mc_alloc：从空闲块分配内存（必要时拆分空闲块）
;  入口：BX = 请求段数；出口：AX = 块段（0 表示失败，CF=1）
; ----------------------------------------------------------------------------
mc_alloc:
        push es cx dx si di
        mov ax, [free_mcb_seg]
        test ax, ax
        jz .fail
        mov es, ax
        cmp word [es:MCB_OWNER], 0
        jne .fail
        mov dx, [es:MCB_SIZE]
        cmp dx, bx
        jb .fail                ; 空间不足
        mov si, ax
        inc si                  ; 块段 = MCB 段 + 1
        cmp dx, bx
        je .whole
        ; ---- 拆分：本块分配 bx 段，剩余 dx-bx-1 段成为新空闲块 ----
        mov cx, dx
        sub cx, bx
        dec cx                  ; 剩余段数（含新 MCB 一段）
        mov word [es:MCB_SIZE], bx
        mov ax, [current_psp]
        mov word [es:MCB_OWNER], ax
        mov byte [es:MCB_TYPE], 'M'
        ; 新空闲块 MCB 段 = 本 MCB 段 + bx + 1
        mov di, si
        add di, bx
        mov [free_mcb_seg], di
        mov es, di
        mov byte [es:MCB_TYPE], 'Z'
        mov word [es:MCB_OWNER], 0
        mov word [es:MCB_SIZE], cx
        jmp .ok
.whole:
        ; 恰好整块分配
        mov ax, [current_psp]
        mov word [es:MCB_OWNER], ax
        mov word [free_mcb_seg], 0
.ok:
        mov ax, si
        clc
        jmp .done
.fail:
        xor ax, ax
        stc
.done:
        pop di si dx cx es
        ret

; ----------------------------------------------------------------------------
;  mc_free：释放内存块（与后续空闲块合并）
;  入口：AX = 块段
; ----------------------------------------------------------------------------
mc_free:
        push ax bx cx dx si es
        dec ax
        mov bx, ax              ; bx = 本 MCB 段
        mov si, ax              ; 保存本 MCB 段
        mov es, bx
        mov word [es:MCB_OWNER], 0
.merge_next:
        mov al, [es:MCB_TYPE]
        cmp al, 'Z'
        je .finish
        ; 下一 MCB 段 = 本 MCB 段 + 本块大小 + 1
        mov cx, [es:MCB_SIZE]
        inc cx
        add bx, cx
        mov dx, bx
        mov es, bx
        cmp word [es:MCB_OWNER], 0
        jne .finish
        ; 下一块空闲：合并到本块
        mov al, [es:MCB_TYPE]   ; 下一 MCB 类型（可能 'Z'）
        push ax
        mov cx, dx
        sub cx, si
        dec cx                  ; 中间段数（含下一 MCB）
        mov ax, [es:MCB_SIZE]
        add cx, ax              ; 合并后大小
        mov es, si
        mov word [es:MCB_SIZE], cx
        pop ax
        mov byte [es:MCB_TYPE], al
        jmp .merge_next
.finish:
        ; 若本块空闲则登记为空闲块
        mov es, si
        cmp word [es:MCB_OWNER], 0
        jne .done
        mov [free_mcb_seg], si
.done:
        pop es si dx cx bx ax
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
        ; 默认 DTA = PSP:0x80
        mov word [dta_seg], SYS_PSP_SEG
        mov word [dta_off], 80h
        mov [current_psp], SYS_PSP_SEG
        pop es cx bx ax
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
        ; ---- 分配内存：文件 + PSP(0x100) + 栈(0x200) ----
        mov ax, word [find_size]
        mov cx, 16
        xor dx, dx
        div cx
        add ax, 16              ; + PSP（16 段）
        add ax, 32              ; + 栈（32 段）
        mov bx, ax
        call mc_alloc
        test ax, ax
        jz .err
        mov [prog_seg], ax
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
        ; 子进程 DTA = PSP:0x80
        mov ax, [prog_seg]
        mov [dta_seg], ax
        mov word [dta_off], 80h
        ; ---- 切换当前 PSP 并进入子进程 ----
        mov [current_psp], ax
        mov ds, ax
        mov es, ax
        cli
        mov ss, ax
        mov sp, 0FFFEh
        sti
        push word [prog_seg]
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
;  入口：DS:DX = 路径（调用者段）；出口：程序结束后返回 AX=退出码
; ----------------------------------------------------------------------------
fn_exec:
        cmp al, 0
        jne .err
        push es si di
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
        xor ax, ax
        mov es, ax
        push word [es:22h*4]
        push word [es:22h*4+2]
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
