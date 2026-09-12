; ============================================================================
;  新增系统服务（与 SDK 同步）
; ============================================================================

; AH=0D：磁盘复位（LPY-DOS 缓存策略简单，空操作即成功）
fn_disk_reset:
        clc
        ret

; AH=0E：选择默认驱动器（DL=0=A,1=B...）
fn_select_drive:
        mov al, dl
        and al, 07Fh
        mov [current_drive], al
        mov al, 2               ; 返回逻辑驱动器数（占位）
        ret

; AH=1B/1C：取驱动器参数（简化：返回介质字节，不实现完整 FAT 指针）
fn_drive_info:
        mov dl, 0F0h            ; 固定介质描述
        mov al, 0FFh
        ret

;  bin_to_bcd：AL = 二进制 -> AL = BCD
bin_to_bcd:
        push cx
        mov cl, 10
        xor ah, ah
        div cl                  ; AL=商(十位), AH=余(个位)
        mov cl, 4
        shl al, cl
        or al, ah
        pop cx
        ret

; AH=2B：设系统日期（CX=年, DH=月, DL=日）
fn_set_date:
        push cx dx
        ; 年 -> BCD：世纪高位放 CH(BCD), 年低位放 CL(BCD)
        mov ax, cx
        mov bl, 100
        div bl                  ; AL=世纪, AH=年内
        call bin_to_bcd
        mov ch, al              ; 世纪(BCD)
        mov al, ah
        call bin_to_bcd
        mov cl, al              ; 年(BCD)
        mov al, dh
        call bin_to_bcd
        mov dh, al
        mov al, dl
        call bin_to_bcd
        mov dl, al
        mov ah, 0Bh
        int 1Ah                 ; CF=0 成功
        pop dx cx
        jc .err
        xor al, al
        clc
        ret
.err:
        mov al, 0FFh
        stc
        ret

; AH=2D：设系统时间（CH=时, CL=分, DH=秒）
fn_set_time:
        push cx dx
        mov al, ch
        call bin_to_bcd
        mov ch, al
        mov al, cl
        call bin_to_bcd
        mov cl, al
        mov al, dh
        call bin_to_bcd
        mov dh, al
        mov dl, 0
        mov ah, 0Dh
        int 1Ah
        pop dx cx
        jc .err
        xor al, al
        clc
        ret
.err:
        mov al, 0FFh
        stc
        ret

; AH=2E：写后校验开关（AL=0 关 / 1 开，DL 必须为 0）
fn_set_verify:
        cmp dl, 0
        jne .done
        mov [verify_flag], al
.done:
        clc
        ret

; AH=54：取校验开关（AL=0 关 / 1 开）
fn_get_verify:
        mov al, [verify_flag]
        ret

; AH=2F：取 DTA 地址（ES:BX = 当前 DTA）
fn_get_dta:
        mov bx, [dta_off]
        mov es, [dta_seg]
        ret

; AH=33：取/设 Ctrl-C 开关（AL=0 读 -> DL; AL=1 写 <- DL）
fn_ctrlc:
        cmp al, 1
        je .set
        mov dl, [ctrlc_flag]
        clc
        ret
.set:
        mov [ctrlc_flag], dl
        clc
        ret

; AH=34：取 InDOS 标志指针（LPY-DOS 无 InDOS 计数，返回 ES:BX=0）
fn_indos:
        xor bx, bx
        mov es, bx
        ret

; AH=4D：取子进程返回码（AH=退出码, AL=0=正常结束）
fn_get_return_code:
        mov al, [term_code]
        mov ah, 0
        clc
        ret

; AH=58：取/设内存分配策略（AL=0 读 -> AX=0=首次适配; AL=1 写忽略）
fn_alloc_strategy:
        cmp al, 1
        je .set
        xor ax, ax
        clc
        ret
.set:
        xor ax, ax
        clc
        ret
