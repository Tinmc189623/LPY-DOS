; ============================================================================
;  目录操作（mkdir/rmdir/chdir）
; ============================================================================

; AH=39：创建目录
fn_mkdir:
        mov byte [create_attr], ATTR_DIR
        mov es, [caller_ds]
        call fat_find_file
        jnc .exists
        ; 创建
        call split_parent_name
        jc .notfound
        mov bx, [parent_cluster]
        call find_free_dir_entry
        jc .diskfull
        ; 分配新簇作为目录内容
        call fat_alloc
        test ax, ax
        jz .diskfull
        mov [newdir_clu], ax
        mov [create_cluster], ax
        ; 写目录项
        call write_new_entry
        jc .diskfull
        ; 初始化新簇：'.' 与 '..'
        mov bx, [newdir_clu]
        call cluster_to_lba
        mov [temp_lba], ax
        ; 清零 dir_buf
        lea di, [dir_buf]
        mov cx, 512
        xor al, al
        push di cx
        rep stosb
        pop cx di
        ; 写 '.' 项
        lea si, [dot_name]
        lea di, [dir_buf]
        mov cx, 11
        rep movsb
        mov ax, [newdir_clu]
        mov word [dir_buf+1Ah], ax
        ; 写 '..' 项
        lea si, [dotdot_name]
        lea di, [dir_buf+20h]
        mov cx, 11
        rep movsb
        mov ax, [parent_cluster]
        mov word [dir_buf+20h+1Ah], ax
        ; 写回整个簇
        mov ax, [temp_lba]
        mov cx, [bpb_sec_per_clus]
        lea bx, [dir_buf]
        call write_sectors_lba
        jc .diskfull
        xor ax, ax
        clc
        ret
.exists:
        mov ax, 5
        stc
        ret
.notfound:
        mov ax, 3
        stc
        ret
.diskfull:
        mov ax, 19h
        stc
        ret

dot_name        db '.          '
dotdot_name     db '..         '

; AH=3A：删除目录（必须为空）
fn_rmdir:
        mov es, [caller_ds]
        call fat_find_file
        jc .notfound
        test byte [find_attr], ATTR_DIR
        jz .notdir
        ; 检查是否为空
        mov bx, [find_firstclu]
        test bx, bx
        jz .notdir              ; 根目录不可删
        mov [dir_state_first], bx
        mov word [dir_state_pos], 0
.check:
        call fat_iter_dir
        jc .empty_ok
        mov al, [es:di]
        cmp al, 0E5h
        je .check
        cmp byte [es:di], '.'
        je .check
        mov ax, 5               ; 非空
        stc
        ret
.empty_ok:
        ; 释放目录簇链
        mov bx, [find_firstclu]
.free_chain:
        push bx
        call fat_get_next
        pop bx
        test ax, ax
        jz .clr
        cmp ax, 0FF8h
        jae .last
        push ax
        mov ax, 0
        call fat_set_next
        pop ax
        mov bx, ax
        jmp .free_chain
.last:
        mov ax, 0
        call fat_set_next
.clr:
        ; 删除目录项
        mov ax, [find_dirsector]
        mov cx, 1
        mov di, ds
        mov es, di
        lea bx, [dir_buf]
        call read_sector_lba
        jc .err
        mov di, [find_diroff]
        mov byte [dir_buf+di], 0E5h
        mov ax, [find_dirsector]
        mov cx, 1
        lea bx, [dir_buf]
        call write_sector_lba
        jc .err
        xor ax, ax
        ret
.notfound:
        mov ax, 3
        stc
        ret
.notdir:
        mov ax, 5
        stc
        ret
.err:
        mov ax, 2
        stc
        ret

; AH=3B：改变当前目录
fn_chdir:
        mov es, [caller_ds]
        call fat_find_file
        jc .notfound
        test byte [find_attr], ATTR_DIR
        jz .notdir
        mov ax, [find_firstclu]
        mov [cur_dir_first], ax
        ; 更新 current_dir 字符串
        call update_curdir_path
        clc
        ret
.notfound:
        mov ax, 3
        stc
        ret
.notdir:
        mov ax, 5
        stc
        ret

; ----------------------------------------------------------------------------
;  update_curdir_path：依据 path_buf 更新 current_dir（规范绝对路径）
; ----------------------------------------------------------------------------
update_curdir_path:
        push ax bx cx dx si di
        lea si, [path_buf]
        cmp byte [si+1], ':'
        jne .no_drive
        add si, 2
.no_drive:
        cmp byte [si], '\'
        jne .rel
        ; 绝对路径
        cmp byte [si+1], 0
        jne .abs_copy
        ; 根目录
        mov byte [current_dir], '\'
        mov byte [current_dir+1], 0
        jmp .done
.abs_copy:
        lea di, [current_dir]
.copy_abs:
        mov al, [si]
        mov [di], al
        inc si
        inc di
        test al, al
        jnz .copy_abs
        jmp .done
.rel:
        ; 相对路径：逐分量处理
        lea si, [path_buf]
        cmp byte [si+1], ':'
        jne .rel2
        add si, 2
.rel2:
        cmp byte [si], 0
        je .done
.process:
        call get_component
        mov [temp_sep], al
        ; 处理 '.' 与 '..'
        cmp byte [name_buf], '.'
        jne .append
        cmp byte [name_buf+1], '.'
        jne .proc_next
        cmp byte [name_buf+2], 0
        jne .proc_next
        call curdir_up
        jmp .proc_next
.append:
        call curdir_append
.proc_next:
        cmp byte [temp_sep], '\'
        jne .done
        jmp .process
.done:
        pop di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  curdir_append：把 name_buf 作为子目录追加到 current_dir
; ----------------------------------------------------------------------------
curdir_append:
        push ax bx cx si di
        lea di, [current_dir]
        call strlen_di          ; ax = 长度
        add di, ax
        ; 确保 '\' 分隔
        cmp di, current_dir
        je .sep
        cmp byte [di-1], '\'
        je .sep_ok
.sep:
        mov byte [di], '\'
        inc di
.sep_ok:
        lea si, [name_buf]
.copy:
        mov al, [si]
        mov [di], al
        inc si
        inc di
        test al, al
        jnz .copy
        pop di si cx bx ax
        ret

; ----------------------------------------------------------------------------
;  curdir_up：current_dir 上移一级
; ----------------------------------------------------------------------------
curdir_up:
        push ax bx cx si di
        lea di, [current_dir]
        mov bx, 0
.loop:
        mov al, [di]
        cmp al, 0
        je .found
        cmp al, '\'
        jne .next
        mov bx, di
.next:
        inc di
        jmp .loop
.found:
        lea ax, [current_dir]
        cmp bx, ax
        je .root
        mov byte [bx+1], 0
        jmp .done
.root:
        mov byte [current_dir], '\'
        mov byte [current_dir+1], 0
.done:
        pop di si cx bx ax
        ret

; ----------------------------------------------------------------------------
;  strlen_di：求字符串长度
;  入口：DS:DI = 字符串；出口：AX = 长度
; ----------------------------------------------------------------------------
strlen_di:
        push di
        xor ax, ax
.loop:
        cmp byte [di], 0
        je .done
        inc ax
        inc di
        jmp .loop
.done:
        pop di
        ret
