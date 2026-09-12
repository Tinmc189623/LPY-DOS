; ============================================================================
;  目录枚举
; ============================================================================

; ----------------------------------------------------------------------------
;  fat_iter_dir：枚举目录下一项
;  入口：[dir_state_first] = 目录起始簇（0=根目录），[dir_state_pos] = 项序号（初始 0）
;  出口：CF=0：ES:DI 指向 dir_buf 中的目录项；CF=1：枚举结束
; ----------------------------------------------------------------------------
fat_iter_dir:
        push ax bx cx dx si
        mov ax, [dir_state_pos]
        mov bx, [dir_state_first]
        test bx, bx
        jz .root
        ; ================= 子目录 =================
        mov cx, [bpb_sec_per_clus]
        shl cx, 4                ; cx = 每簇项数
        xor dx, dx
        div cx                   ; ax = 簇步进, dx = 簇内项序号
        ; 从 first 沿链走 ax 步
        mov si, bx
        mov cx, ax
        test cx, cx
        jz .walk_done
.walk:
        push cx
        mov bx, si
        call fat_get_next
        mov si, ax
        pop cx
        test si, si
        jz .end
        cmp si, 0FF8h
        jae .end
        loop .walk
.walk_done:
        ; dx = 簇内项序号 -> 簇内扇区/扇区内项
        mov ax, dx
        mov cx, 16
        xor dx, dx
        div cx                   ; ax = 簇内扇区, dx = 扇区内项
        mov cx, ax               ; 保存簇内扇区号
        push dx
        mov bx, si
        call cluster_to_lba
        add ax, cx               ; 实际 LBA
        ; 读扇区
        mov cx, 1
        mov di, ds
        mov es, di
        lea bx, [dir_buf]
        call read_sector_lba
        pop di                   ; di = 扇区内项号
        shl di, 5                ; di = 扇区内偏移
        ; 目录结束判断
        mov al, [dir_buf+di]
        test al, al
        jz .end
        ; 推进项序号
        mov ax, [dir_state_pos]
        inc ax
        mov [dir_state_pos], ax
        add di, dir_buf          ; ES:DI 指向目录项
        clc
        jmp .out
.root:
        ; ================= 根目录 =================
        cmp ax, [bpb_root_ent_cnt]
        jae .end
        mov cx, 32
        mul cx                   ; ax = pos*32
        mov cx, 512
        xor dx, dx
        div cx                   ; ax = 扇区, dx = 扇区内偏移
        push dx
        add ax, [root_dir_start]
        mov cx, 1
        mov di, ds
        mov es, di
        lea bx, [dir_buf]
        call read_sector_lba
        pop di
        mov al, [dir_buf+di]
        test al, al
        jz .end
        ; 推进
        mov ax, [dir_state_pos]
        inc ax
        mov [dir_state_pos], ax
        add di, dir_buf          ; ES:DI 指向目录项（di 为扇区内偏移）
        clc
        jmp .out
.end:
        stc
.out:
        pop si dx cx bx ax
        ret

