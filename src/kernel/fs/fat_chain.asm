; ============================================================================
;  簇链基础操作
; ============================================================================

; ----------------------------------------------------------------------------
;  fat_get_next：读取 FAT 项（簇链下一项）
;  入口：BX = 簇号；出口：AX = FAT 项值（0=空闲, >=0xFF8=结束）
;  自动识别 FAT12/FAT16（依据每 FAT 扇区数）
; ----------------------------------------------------------------------------
fat_get_next:
        push bx cx dx si di es
        ; 计算 FAT 内字节偏移
        mov ax, [bpb_fat_sz16]
        cmp ax, 12
        jg .fat16
        ; ---- FAT12：偏移 = 簇 + 簇/2 ----
        mov si, bx
        shr si, 1
        add si, bx
        jmp .load
.fat16:
        ; ---- FAT16：偏移 = 簇 * 2 ----
        mov si, bx
        shl si, 1
.load:
        ; 保存簇号（FAT12 奇偶判断用），因为 bx 随后会被读扇区覆盖
        mov [temp_clupar], bx
        ; 读对应 FAT 扇区
        mov ax, si
        xor dx, dx
        mov cx, 512
        div cx                   ; ax=扇区号, dx=扇区内偏移
        push dx
        add ax, [fat_start]
        mov cx, 1
        mov di, ds
        mov es, di
        lea bx, [fat_buf]
        call read_sector_lba
        pop di
        mov ax, word [fat_buf+di]     ; 16 位 FAT 项
        ; 按 FAT12/16 裁剪
        mov dx, [bpb_fat_sz16]
        cmp dx, 12
        jg .f16_val
        ; FAT12：按奇偶取 12 位
        test word [temp_clupar], 1
        jnz .odd12
        and ax, 0FFFh
        jmp .done
.odd12:
        shr ax, 4
        jmp .done
.f16_val:
        ; FAT16 直接返回
.done:
        ; 入口只压入 6 个寄存器（bx cx dx si di es），此处只弹 6 个
        pop es di si dx cx bx
        ret

temp_clupar     dw 0

; ----------------------------------------------------------------------------
;  fat_set_next：写入 FAT 项
;  入口：BX = 簇号，AX = 新值；两份 FAT 均更新
;  出口：失败时 CF=1
; ----------------------------------------------------------------------------
fat_set_next:
        push ax bx cx dx si di es
        mov [temp_fatval], ax
        ; 计算偏移（同 fat_get_next）
        mov ax, [bpb_fat_sz16]
        cmp ax, 12
        jg .fat16
        mov si, bx
        shr si, 1
        add si, bx
        jmp .calc
.fat16:
        mov si, bx
        shl si, 1
.calc:
        mov ax, si
        xor dx, dx
        mov cx, 512
        div cx                   ; ax=扇区号, dx=扇区内偏移
        mov [temp_fatsec], ax
        mov [temp_fatoff], dx
        ; 是否为 FAT12 奇簇
        mov ax, [bpb_fat_sz16]
        cmp ax, 12
        jg .w16
        ; FAT12：读该扇区，修改 12 位，写回
        mov [temp_clupar], bx    ; 保存簇号（bx 随后被读扇区覆盖）
        mov ax, [temp_fatsec]
        add ax, [fat_start]
        mov cx, 1
        mov di, ds
        mov es, di
        lea bx, [fat_buf]
        call read_sector_lba
        jc .err
        mov di, [temp_fatoff]
        mov ax, word [fat_buf+di]
        test word [temp_clupar], 1
        jnz .odd12w
        ; 偶簇：保留高 4 位，替换低 12 位
        mov cx, [temp_fatval]
        and cx, 0FFFh
        and ax, 0F000h
        or ax, cx
        jmp .writew
.odd12w:
        ; 奇簇：保留低 4 位，替换高 12 位
        mov cx, [temp_fatval]
        and cx, 0FFFh
        shl cx, 4
        and ax, 0Fh
        or ax, cx
        jmp .writew
.w16:
        ; FAT16：读扇区，改 16 位，写回
        mov ax, [temp_fatsec]
        add ax, [fat_start]
        mov cx, 1
        mov di, ds
        mov es, di
        lea bx, [fat_buf]
        call read_sector_lba
        jc .err
        mov di, [temp_fatoff]
        mov ax, [temp_fatval]
        mov word [fat_buf+di], ax
.writew:
        mov word [fat_buf+di], ax
        ; 写回 FAT1
        mov ax, [temp_fatsec]
        add ax, [fat_start]
        mov cx, 1
        lea bx, [fat_buf]
        call write_sector_lba
        jc .err
        ; 写回 FAT2
        mov ax, [temp_fatsec]
        add ax, [fat_start]
        add ax, [bpb_fat_sz16]
        mov cx, 1
        lea bx, [fat_buf]
        call write_sector_lba
        jc .err
        clc
        jmp .done
.err:
        stc
.done:
        pop es di si dx cx bx ax
        ret

temp_fatval     dw 0
temp_fatsec     dw 0
temp_fatoff     dw 0

; ----------------------------------------------------------------------------
;  cluster_to_lba：簇号转数据区扇区号
;  入口：BX = 簇号；出口：AX = LBA
; ----------------------------------------------------------------------------
cluster_to_lba:
        push bx cx
        mov ax, bx
        sub ax, 2
        mov cx, [bpb_sec_per_clus]
        mul cx
        add ax, [data_start]
        pop cx bx
        ret

; ----------------------------------------------------------------------------
;  fat_alloc：分配一个空闲簇（标记为链尾）
;  出口：AX = 新簇号（0 表示失败）
; ----------------------------------------------------------------------------
fat_alloc:
        push bx cx dx
        ; 总簇数上限
        mov ax, [bpb_totsec16]
        sub ax, [data_start]
        mov cx, [bpb_sec_per_clus]
        div cx
        add ax, 2
        mov [temp_maxclus], ax
        mov bx, 2
.loop:
        push bx
        call fat_get_next
        pop bx
        test ax, ax
        jz .found
        inc bx
        cmp bx, [temp_maxclus]
        jb .loop
        ; 无空闲簇
        xor ax, ax
        jmp .done
.found:
        ; 标记该簇为链尾（FAT12: 0xFFF, FAT16: 0xFFFF）
        mov ax, [bpb_fat_sz16]
        cmp ax, 12
        jg .f16
        mov ax, 0FFFh
        jmp .set
.f16:
        mov ax, 0FFFFh
.set:
        push bx
        call fat_set_next
        pop bx
        jc .fail
        mov ax, bx               ; 返回新簇号
        jmp .done
.fail:
        xor ax, ax
.done:
        pop dx cx bx
        ret

temp_maxclus    dw 0
bpb_totsec16    dw 2880          ; 补充：总扇区数（BPB 字段，放在此处便于使用）

