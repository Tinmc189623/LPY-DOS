; ============================================================================
;  路径解析与文件查找
; ============================================================================

; ----------------------------------------------------------------------------
;  get_component：从路径中提取一个分量到 name_buf
;  入口：DS:SI = 路径指针；出口：DS:DI=name_buf（0 结尾），AL = 分隔符
;        （0 表示结束，'\' 表示还有后续），SI 更新到下一个分量之后
; ----------------------------------------------------------------------------
get_component:
        push bx
        lea di, [name_buf]
.loop:
        mov al, [si]
        cmp al, '\'
        je .done
        cmp al, 0
        je .done
        mov [di], al
        inc di
        inc si
        jmp .loop
.done:
        mov byte [di], 0
        inc si                  ; 越过分隔符/结束符，供调用者继续解析
        pop bx
        ret

; ----------------------------------------------------------------------------
;  fat_find_file：按路径查找文件/目录
;  入口：DS:DX（调用者段）= 路径
;  出口：CF=0：填充 find_* 变量；CF=1：未找到
; ----------------------------------------------------------------------------
fat_find_file:
        push ax bx cx dx si di bp es
        ; 拷贝路径到 path_buf
        mov es, [caller_ds]
        mov si, dx
        lea di, [path_buf]
.copy:
        mov al, [es:si]
        mov [di], al
        inc si
        inc di
        test al, al
        jnz .copy
        ; 解析
        lea si, [path_buf]
        ; 跳过盘符 "X:"
        cmp byte [si+1], ':'
        jne .no_drive
        add si, 2
.no_drive:
        ; 起始目录
        cmp byte [si], '\'
        jne .rel
        inc si
        xor bx, bx               ; 从根目录开始
        jmp .parse
.rel:
        mov bx, [cur_dir_first]
.parse:
        ; 空路径：目标是根/当前目录本身
        cmp byte [si], 0
        je .found_root
        ; 循环解析分量
.parse_loop:
        call get_component       ; name_buf, AL = 分隔符
        ; 在 bx 目录中查找该分量
        mov [dir_state_first], bx
        mov word [dir_state_pos], 0
.enum:
        call fat_iter_dir
        jc .notfound
        ; 保存目录项指针到 BP（repe cmpsb 会推进 DI）
        mov bp, di
        ; 规范化分量名
        lea si, [name_buf]
        lea di, [norm_buf]
        call fat_normalize_name
        ; 与目录项 11 字节名比较（ES 保持 dir_buf 段）
        mov di, bp
        lea si, [norm_buf]
        mov cx, 11
        repe cmpsb
        je .found_comp
        jmp .enum
.found_comp:
        ; 恢复目录项指针（ES:DI）
        mov di, bp
        ; 记录目录项信息（ES:DI 指向 dir_buf 内目录项）
        mov ax, [es:di+1Ah]
        mov [find_firstclu], ax
        mov ax, [es:di+1Ch]
        mov word [find_size], ax
        mov ax, [es:di+1Eh]
        mov word [find_size+2], ax
        mov al, [es:di+0Bh]
        mov [find_attr], al
        push si                  ; 保存分隔符标记
        ; 记录目录项位置（用于写回）：需要 LBA 和偏移
        ; dir_state_pos 已推进（指向当前项之后），用 pos-1 反推
        mov ax, [dir_state_pos]
        dec ax
        push ax
        ; 计算目录项所在扇区与偏移（复用 fat_iter_dir 逻辑简化版）
        ; 保存 es:di 指向的 dir_buf 偏移 = di - dir_buf
        push di
        ; 计算 LBA：用 pos-1 定位
        call find_entry_location
        ; 结果在 temp_fatsec/temp_fatoff? 用专用变量
        ; find_entry_location 设置 find_dirsector/find_diroff
        pop di
        pop ax
        pop si
        ; 拷贝文件名
        push si
        mov si, di               ; 源 = 目录项名（ES=DS=KERNEL_SEG，故基址即 di）
        lea di, [find_name]
        mov cx, 11
        rep movsb
        pop si
        ; 判断分隔符
        cmp al, '\'
        jne .final
        ; 中间分量必须是目录
        test byte [find_attr], ATTR_DIR
        jz .notfound
        mov bx, [find_firstclu]
        jmp .parse_loop
.final:
        clc
        jmp .done
.found_root:
        ; 目标是根目录：构造一个"根目录目录项"信息
        mov word [find_firstclu], 0
        mov dword [find_size], 0
        mov byte [find_attr], ATTR_DIR
        clc
        jmp .done
.notfound:
        stc
.done:
        pop es bp di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  find_entry_location：计算目录项所在扇区与扇区内偏移
;  入口：AX = 目录项序号，BX = 目录起始簇（0=根）
;  出口：find_dirsector = LBA，find_diroff = 扇区内偏移
; ----------------------------------------------------------------------------
find_entry_location:
        push ax bx cx dx si di es
        ; 简化：仅处理每簇 1 扇区（sec_per_clus 可变但此处按通用计算）
        ; 目录项字节偏移 = ax * 32
        mov cx, 32
        mul cx                   ; dx:ax = ax*32（假设不超 16 位）
        ; 扇区号 = 偏移/512, 扇区内偏移 = 偏移%512
        mov cx, 512
        xor dx, dx
        div cx                   ; ax = 扇区号, dx = 扇区内偏移
        mov [temp_sector], ax
        mov [find_diroff], dx
        ; 判断根/子目录
        test bx, bx
        jnz .sub
        ; 根目录
        mov ax, [temp_sector]
        add ax, [root_dir_start]
        mov [find_dirsector], ax
        jmp .done
.sub:
        ; 子目录：扇区号 -> 簇步进
        mov cx, [bpb_sec_per_clus]
        xor dx, dx
        mov ax, [temp_sector]
        div cx                   ; ax = 簇步进, dx = 簇内扇区
        ; 从 first 走 ax 步
        mov si, bx
        mov cx, ax
        test cx, cx
        jz .sub_walk_done
.sub_walk:
        push cx
        mov bx, si
        call fat_get_next
        mov si, ax
        pop cx
        cmp si, 0FF8h
        jae .sub_walk_done
        loop .sub_walk
.sub_walk_done:
        mov bx, si
        call cluster_to_lba
        add ax, dx               ; + 簇内扇区
        mov [find_dirsector], ax
.done:
        pop es di si dx cx bx ax
        ret

