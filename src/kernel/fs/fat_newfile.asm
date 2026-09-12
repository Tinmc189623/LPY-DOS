; ============================================================================
;  路径分解（创建文件/目录用）
; ============================================================================

; ----------------------------------------------------------------------------
;  split_parent_name：把 path_buf 分解为父目录簇 + 最后分量名
;  入口：path_buf = 路径；出口：BX = 父目录簇（0=根），norm_buf = 11 字节名，
;        parent_cluster = 父目录簇；CF=1 失败
; ----------------------------------------------------------------------------
split_parent_name:
        push ax cx dx si di es
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
        xor bx, bx              ; 根目录
        jmp .parse
.rel:
        mov bx, [cur_dir_first]
.parse:
        ; 空路径 → 失败
        cmp byte [si], 0
        je .fail
.parse_loop:
        call get_component      ; name_buf，AL = 分隔符
        mov [temp_sep], al
        cmp al, '\'
        jne .last
        ; 中间分量：在 bx 目录中查找
        mov [dir_state_first], bx
        mov word [dir_state_pos], 0
.lookup:
        call fat_iter_dir
        jc .fail
        ; 规范化分量并比较
        lea si, [name_buf]
        lea di, [norm_buf]
        call fat_normalize_name
        push di
        lea si, [norm_buf]
        mov cx, 11
        repe cmpsb
        pop di
        jne .lookup
        ; 必须是目录
        mov al, [es:di+0Bh]
        test al, ATTR_DIR
        jz .fail
        mov bx, [es:di+1Ah]     ; 进入子目录
        jmp .parse_loop
.last:
        ; 最后分量：规范化
        lea si, [name_buf]
        lea di, [norm_buf]
        call fat_normalize_name
        mov [parent_cluster], bx
        clc
        jmp .done
.fail:
        stc
.done:
        pop es di si dx cx ax
        ret

; ============================================================================
;  目录项空闲位置查找与写入
; ============================================================================

; ----------------------------------------------------------------------------
;  find_free_dir_entry：在目录中查找空闲目录项（0x00 或 0xE5）
;  入口：BX = 目录起始簇（0=根）；出口：CF=0 → find_dirsector/find_diroff；CF=1 → 满
; ----------------------------------------------------------------------------
find_free_dir_entry:
        push ax bx cx dx si di es
        mov [temp_first], bx
        test bx, bx
        jz .root
        jmp .sub
.root:
        ; 根目录：逐扇区枚举
        mov dx, [root_dir_sects]
        xor cx, cx              ; 扇区偏移
.root_sec:
        cmp cx, dx
        jae .full
        mov ax, [root_dir_start]
        add ax, cx
        mov si, 1
        mov di, ds
        mov es, di
        lea bx, [dir_buf]
        call read_sector_lba
        jc .err
        xor bx, bx              ; 扇区内偏移
.rt_ent:
        cmp bx, 512
        jae .rt_next
        mov al, [dir_buf+bx]
        cmp al, 0
        je .found_root
        cmp al, 0E5h
        je .found_root
        add bx, 32
        jmp .rt_ent
.rt_next:
        inc cx
        jmp .root_sec
.found_root:
        mov ax, [root_dir_start]
        add ax, cx
        mov [find_dirsector], ax
        mov [find_diroff], bx
        clc
        jmp .done
.sub:
        ; 子目录：沿簇链枚举
        mov si, bx              ; 当前簇
.sl:
        ; 读整个簇到 dir_buf
        push si
        mov bx, si
        call cluster_to_lba
        mov cx, [bpb_sec_per_clus]
        lea bx, [dir_buf]
        call read_sectors_lba
        pop si
        jc .err
        mov dx, [bpb_sec_per_clus]
        shl dx, 9               ; 簇字节数
        xor bx, bx
.sl_ent:
        cmp bx, dx
        jae .sl_next
        mov al, [dir_buf+bx]
        cmp al, 0
        je .found_sub
        cmp al, 0E5h
        je .found_sub
        add bx, 32
        jmp .sl_ent
.sl_next:
        ; 下一簇
        push si
        mov bx, si
        call fat_get_next
        pop si
        cmp ax, 0FF8h
        jae .try_extend
        mov si, ax
        jmp .sl
.found_sub:
        ; bx = 簇内偏移 → 扇区与扇区内偏移
        mov ax, bx
        mov cx, 512
        xor dx, dx
        div cx                  ; ax = 簇内扇区, dx = 扇区内偏移
        push ax dx
        mov bx, si
        call cluster_to_lba
        pop dx
        pop cx
        add ax, cx
        mov [find_dirsector], ax
        mov [find_diroff], dx
        clc
        jmp .done
.try_extend:
        ; 目录已满：分配新簇扩展
        call fat_alloc
        test ax, ax
        jz .full
        mov [temp_newclu], ax
        ; 旧链尾 -> 新簇
        mov bx, si
        mov ax, [temp_newclu]
        call fat_set_next
        jc .full
        ; 清零新簇
        mov bx, [temp_newclu]
        call cluster_to_lba
        mov [temp_lba], ax
        lea di, [dir_buf]
        mov cx, 512
        xor al, al
        push di cx
        rep stosb
        pop cx di
        mov ax, [temp_lba]
        mov cx, [bpb_sec_per_clus]
        lea bx, [dir_buf]
        call write_sectors_lba
        jc .full
        ; 新簇首项即空闲项
        mov ax, [temp_lba]
        mov [find_dirsector], ax
        mov word [find_diroff], 0
        clc
        jmp .done
.full:
        stc
        jmp .done
.err:
        stc
.done:
        pop es di si dx cx bx ax
        ret

temp_first      dw 0

; ----------------------------------------------------------------------------
;  write_new_entry：在 find_dirsector/find_diroff 处写一个新目录项
;  入口：norm_buf = 11 字节名，create_attr = 属性，create_cluster = 起始簇
; ----------------------------------------------------------------------------
write_new_entry:
        push ax bx cx dx si di es
        mov ax, [find_dirsector]
        test ax, ax
        jz .err
        mov cx, 1
        mov di, ds
        mov es, di
        lea bx, [dir_buf]
        call read_sector_lba
        jc .err
        mov ax, [find_diroff]
        mov [temp_dirent_off], ax
        ; 拷贝名称
        add ax, dir_buf         ; AX = dir_buf 内地址
        mov di, ax
        lea si, [norm_buf]
        mov cx, 11
        rep movsb
        ; 属性
        mov si, [temp_dirent_off]
        mov al, [create_attr]
        mov [dir_buf+si+0Bh], al
        ; 保留区清零
        mov byte [dir_buf+si+0Ch], 0
        mov byte [dir_buf+si+0Dh], 0
        ; 时间/日期
        mov word [dir_buf+si+16h], 0
        mov word [dir_buf+si+18h], 0
        ; 起始簇
        mov ax, [create_cluster]
        mov word [dir_buf+si+1Ah], ax
        ; 大小
        mov word [dir_buf+si+1Ch], 0
        mov word [dir_buf+si+1Eh], 0
        ; 写回
        mov ax, [find_dirsector]
        mov cx, 1
        lea bx, [dir_buf]
        call write_sector_lba
        jc .err
        clc
        jmp .done
.err:
        stc
.done:
        pop es di si dx cx bx ax
        ret

; ============================================================================
;  文件打开/创建/关闭
; ============================================================================

; 通用打开：按 find_* 信息填充并登记 fd
; 入口：无（find_* 已就绪）；出口：AX = 句柄，CF=0；CF=1 失败
open_found_file:
        push bx cx dx si di
        call fd_alloc
        jc .nofds
        mov [temp_handle], bx   ; 保存 fd 偏移
        call handle_alloc
        jc .nohandles
        ; 填充 fd
        mov bx, [temp_handle]
        mov word [bx+FD_FLAGS], 1
        mov ax, [find_firstclu]
        mov [bx+FD_CLUSTER], ax
        mov [bx+FD_CURCLU], ax
        mov word [bx+FD_CURPOS], 0
        mov word [bx+FD_CURPOS+2], 0
        mov ax, word [find_size]
        mov [bx+FD_SIZE], ax
        mov ax, word [find_size+2]
        mov [bx+FD_SIZE+2], ax
        mov word [bx+FD_POS], 0
        mov word [bx+FD_POS+2], 0
        mov ax, [find_dirsector]
        mov [bx+FD_DIRSEC], ax
        mov ax, [find_diroff]
        mov [bx+FD_DIROFF], ax
        mov al, [find_attr]
        mov [bx+FD_ATTR], al
        lea si, [find_name]
        lea di, [bx+FD_NAME]
        mov cx, 11
        rep movsb
        ; 登记句柄：handles[句柄号] = fd 偏移
        mov si, [temp_handle]
        shl si, 1
        ; temp_handle 存的是 fd 偏移；需要句柄号
        ; 重新取句柄号
        push bx
        lea bx, [handles]
        xor cx, cx
.lookup:
        cmp word [bx], 0FFFFh
        je .found_h
        add bx, 2
        inc cx
        cmp cx, NUM_HANDLES
        jae .internal_err
        jmp .lookup
.found_h:
        pop bx
        ; cx = 句柄号；登记
        lea si, [handles]
        shl cx, 1
        add si, cx
        shr cx, 1
        mov [si], bx            ; handles[句柄号] = fd 偏移
        mov ax, cx
        clc
        jmp .done
.internal_err:
        pop bx
        stc
        jmp .done
.nohandles:
        mov word [fd_table+bx], 0
        mov ax, 4
        stc
        jmp .done
.nofds:
        mov ax, 4
        stc
.done:
        pop di si dx cx bx ax
        ret

; AH=3C：创建文件（存在则截断）
fn_create:
        mov [create_attr], cl
        mov word [create_cluster], 0
        mov es, [caller_ds]
        call fat_find_file
        jc .make_new
        ; 已存在：目录拒绝，否则截断
        test byte [find_attr], ATTR_DIR
        jnz .acc
        mov bx, [find_firstclu]
        test bx, bx
        jz .open
.trunc:
        push bx
        call fat_get_next
        pop bx
        test ax, ax
        jz .trunc_done
        cmp ax, 0FF8h
        jae .trunc_last
        push ax
        mov ax, 0
        call fat_set_next
        pop ax
        mov bx, ax
        jmp .trunc
.trunc_last:
        mov ax, 0
        call fat_set_next
.trunc_done:
        ; 清空大小
        mov dword [find_size], 0
        jmp .open
.make_new:
        ; 分解父目录与文件名
        call split_parent_name
        jc .notfound
        mov bx, [parent_cluster]
        call find_free_dir_entry
        jc .diskfull
        call write_new_entry
        jc .diskfull
        ; 设置 find_* 对应新文件
        mov word [find_firstclu], 0
        mov dword [find_size], 0
        mov al, [create_attr]
        mov [find_attr], al
        lea si, [norm_buf]
        lea di, [find_name]
        mov cx, 11
        rep movsb
        jmp .open
.open:
        call open_found_file
        ret
.acc:
        mov ax, 5
        stc
        ret
.notfound:
        mov ax, 3
        stc
        ret
.diskfull:
        mov ax, 19h             ; 磁盘写保护/满
        stc
        ret

; AH=3D：打开文件
fn_open:
        mov es, [caller_ds]
        call fat_find_file
        jc .notfound
        test byte [find_attr], ATTR_DIR
        jnz .acc
        jmp open_found_file
.notfound:
        mov ax, 2
        stc
        ret
.acc:
        mov ax, 5
        stc
        ret

; AH=3E：关闭文件
fn_close:
        mov cx, bx              ; 句柄号
        cmp bx, NUM_HANDLES
        jae .err
        shl bx, 1
        mov ax, [handles+bx]
        cmp ax, 0FFFFh
        je .err
        test ax, 8000h
        jnz .free_handle        ; 设备句柄
        ; 释放 fd
        mov si, ax
        mov word [fd_table+si], 0
.free_handle:
        shr bx, 1
        mov word [handles+bx], 0FFFFh
        xor ax, ax
        ret
.err:
        mov ax, 6
        stc
        ret

