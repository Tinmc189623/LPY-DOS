; ============================================================================
;  disk.asm — 磁盘底层驱动（INT 13h 封装）
;  提供 LBA 读写扇区与 INT 25h/26h 绝对磁盘读写
; ============================================================================

; ----------------------------------------------------------------------------
;  lba_to_chs：LBA 转 CHS
;  入口：AX = LBA
;  出口：CH=磁道, CL=扇区号, DH=磁头
; ----------------------------------------------------------------------------
lba_to_chs:
        push ax bx dx
        xor dx, dx
        mov bx, [bpb_sec_per_trk]
        div bx                   ; ax = LBA/每磁道扇区数, dx = LBA%每磁道扇区数
        inc dx                   ; 扇区号 (1..每磁道扇区数)
        mov bx, dx               ; 暂存扇区号
        xor dx, dx
        mov cx, [bpb_num_heads]
        div cx                   ; ax = 磁道, dx = 磁头
        mov ch, al
        mov cl, bl
        mov dh, dl
        pop dx bx ax
        ret

; ----------------------------------------------------------------------------
;  read_sector_lba：读取一个扇区
;  入口：AX = LBA，ES:BX = 目标缓冲
;  出口：失败时 CF=1
; ----------------------------------------------------------------------------
read_sector_lba:
        push ax cx dx
        call lba_to_chs
        mov dl, [boot_drive]
        mov al, 1
        mov ah, 02h
        int 13h
        jc .err
        pop dx cx ax
        clc
        ret
.err:
        pop dx cx ax
        stc
        ret

; ----------------------------------------------------------------------------
;  write_sector_lba：写入一个扇区
;  入口：AX = LBA，ES:BX = 数据缓冲
;  出口：失败时 CF=1
; ----------------------------------------------------------------------------
write_sector_lba:
        push ax cx dx
        call lba_to_chs
        mov dl, [boot_drive]
        mov al, 1
        mov ah, 03h
        int 13h
        jc .err
        pop dx cx ax
        clc
        ret
.err:
        pop dx cx ax
        stc
        ret

; ----------------------------------------------------------------------------
;  read_sectors_lba：读取连续多个扇区
;  入口：AX = 起始 LBA，CX = 扇区数，ES:BX = 目标缓冲
;  出口：失败时 CF=1；缓冲区随读入递增
; ----------------------------------------------------------------------------
read_sectors_lba:
        pusha
.loop:
        push ax cx
        push bx
        call read_sector_lba
        pop bx
        pop cx ax
        jc .err
        inc ax
        add bx, 512
        loop .loop
        popa
        clc
        ret
.err:
        popa
        stc
        ret

; ----------------------------------------------------------------------------
;  write_sectors_lba：写入连续多个扇区
;  入口：AX = 起始 LBA，CX = 扇区数，ES:BX = 数据缓冲
;  出口：失败时 CF=1；缓冲区随写入递增
; ----------------------------------------------------------------------------
write_sectors_lba:
        pusha
.loop:
        push ax cx
        push bx
        call write_sector_lba
        pop bx
        pop cx ax
        jc .err
        inc ax
        add bx, 512
        loop .loop
        popa
        clc
        ret
.err:
        popa
        stc
        ret

; ----------------------------------------------------------------------------
;  int25_handler：绝对磁盘读（对标 MS-DOS INT 25h）
;  入口：AL=驱动器号, CX=扇区数, DX=起始 LBA, DS:BX=缓冲
;  出口：CF 表示状态；返回后栈上残留 FLAGS，调用者需 popf 弹出
; ----------------------------------------------------------------------------
int25_handler:
        pushf
        cli
        push es
        push ds
        pusha
        mov [i25_lba], dx        ; 起始扇区
        mov [i25_cnt], cx        ; 扇区数
        mov ax, ds
        mov es, ax               ; 缓冲段
        mov ax, [i25_lba]
        mov cx, [i25_cnt]
        call read_sectors_lba
        pushf
        pop ax
        and ax, 1
        mov [i25_cf], al
        popa
        pop ds
        pop es
        ; 栈: [my_pushf][IP][CS][FLAGS]
        add sp, 2                ; 丢弃 my_pushf
        popf                     ; 恢复旧 FLAGS，栈: [IP][CS]
        cmp byte [i25_cf], 0     ; 设置返回 CF
        je .ok
        stc
        jmp .set
.ok:
        clc
.set:
        pushf                    ; 压入含 CF 的返回标志
        retf                     ; 弹 IP/CS；返回后 SP 指向残留 FLAGS（调用者 popf）

; ----------------------------------------------------------------------------
;  int26_handler：绝对磁盘写（对标 MS-DOS INT 26h）
;  入口：AL=驱动器号, CX=扇区数, DX=起始 LBA, DS:BX=数据
;  出口：CF 表示状态；返回后栈上残留 FLAGS，调用者需 popf 弹出
; ----------------------------------------------------------------------------
int26_handler:
        pushf
        cli
        push es
        push ds
        pusha
        mov [i25_lba], dx
        mov [i25_cnt], cx
        mov ax, ds
        mov es, ax
        mov ax, [i25_lba]
        mov cx, [i25_cnt]
        call write_sectors_lba
        pushf
        pop ax
        and ax, 1
        mov [i25_cf], al
        popa
        pop ds
        pop es
        ; 栈: [my_pushf][IP][CS][FLAGS]
        add sp, 2                ; 丢弃 my_pushf
        popf                     ; 恢复旧 FLAGS，栈: [IP][CS]
        cmp byte [i25_cf], 0     ; 设置返回 CF
        je .ok
        stc
        jmp .set
.ok:
        clc
.set:
        pushf                    ; 压入含 CF 的返回标志
        retf                     ; 弹 IP/CS；返回后 SP 指向残留 FLAGS（调用者 popf）

; ----------------------------------------------------------------------------
;  INT 25h/26h 临时变量
; ----------------------------------------------------------------------------
i25_lba         dw 0
i25_cnt         dw 0
i25_cf          db 0
