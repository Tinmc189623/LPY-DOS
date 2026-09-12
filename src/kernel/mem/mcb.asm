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

