; ============================================================================
;  查找文件（findfirst/findnext）
; ============================================================================

; ----------------------------------------------------------------------------
;  split_dir_pattern：把 path_buf 分解为目录簇 + 文件名模式
;  出口：search_first = 目录簇，search_pattern = 11 字节模式；CF=1 失败
; ----------------------------------------------------------------------------
split_dir_pattern:
        push ax bx cx dx si di es
        lea si, [path_buf]
        ; 记录最后一个 '\' 的地址
        mov bx, 0
        mov di, si
.find_last:
        cmp byte [di], 0
        je .found_last
        cmp byte [di], '\'
        jne .next
        mov bx, di
.next:
        inc di
        jmp .find_last
.found_last:
        test bx, bx
        jnz .has_dir
        ; 无分隔符：模式为整个路径（相对当前目录）
        mov ax, [cur_dir_first]
        mov [search_first], ax
        lea si, [path_buf]
        jmp .norm
.has_dir:
        ; 若 '\' 在开头 → 目录为根
        lea ax, [path_buf]
        cmp bx, ax
        jne .not_root
        mov word [search_first], 0
        inc bx
        mov si, bx
        jmp .norm
.not_root:
        ; 目录部分 = [path_buf, bx)，模式 = bx+1
        mov byte [bx], 0        ; 临时截断
        lea si, [path_buf]
        call resolve_dir_path
        jc .fail
        mov [search_first], bx
        inc bx
        mov si, bx
.norm:
        lea di, [search_pattern]
        call fat_normalize_name
        clc
        jmp .done
.fail:
        stc
.done:
        pop es di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  resolve_dir_path：把目录路径解析为起始簇
;  入口：DS:SI = 目录路径（0 结尾，可为空）；出口：BX = 目录簇（0=根），CF=1 失败
; ----------------------------------------------------------------------------
resolve_dir_path:
        push ax cx dx si di es
        cmp byte [si], 0
        jne .notempty
        mov bx, [cur_dir_first]
        jmp .done
.notempty:
        cmp byte [si], '\'
        jne .rel
        inc si
        xor bx, bx
        jmp .parse
.rel:
        mov bx, [cur_dir_first]
.parse:
        cmp byte [si], 0
        je .done
.parse_loop:
        call get_component      ; name_buf，AL = 分隔符
        mov [temp_sep], al
        mov [dir_state_first], bx
        mov word [dir_state_pos], 0
.enum:
        call fat_iter_dir
        jc .fail
        lea si, [name_buf]
        lea di, [norm_buf]
        call fat_normalize_name
        push di
        lea si, [norm_buf]
        mov cx, 11
        repe cmpsb
        pop di
        jne .enum
        mov al, [es:di+0Bh]
        test al, ATTR_DIR
        jz .fail
        mov bx, [es:di+1Ah]
        cmp byte [temp_sep], '\'
        jne .done
        jmp .parse_loop
.fail:
        stc
.done:
        pop es di si dx cx ax
        ret

; AH=4E：查找第一个匹配文件
fn_findfirst:
        mov [search_attr], cl
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
        call split_dir_pattern
        jc .notfound
        mov word [search_pos], 0
        jmp fn_findnext
.notfound:
        mov ax, 2
        stc
        ret

; AH=4F：查找下一个匹配文件
fn_findnext:
        mov bx, [search_first]
        mov [dir_state_first], bx
        mov ax, [search_pos]
        mov [dir_state_pos], ax
.loop:
        call fat_iter_dir
        jc .nomore
        ; 过滤：已删除 / 结束 / LFN / 卷标 / 点目录
        mov al, [es:di]
        cmp al, 0E5h
        je .loop
        test al, al
        jz .nomore
        cmp byte [es:di+0Bh], 0Fh
        je .loop
        test byte [es:di+0Bh], ATTR_VOLUME
        jnz .loop
        cmp byte [es:di], '.'
        je .loop
        ; 属性过滤
        mov al, [es:di+0Bh]
        test al, ATTR_DIR
        jz .attr_ok
        test byte [search_attr], ATTR_DIR
        jz .loop
.attr_ok:
        ; 保存目录项信息
        mov al, [es:di+0Bh]
        mov [temp_attr], al
        mov ax, [es:di+16h]
        mov [temp_time], ax
        mov ax, [es:di+18h]
        mov [temp_date], ax
        mov ax, [es:di+1Ch]
        mov word [temp_size], ax
        mov ax, [es:di+1Eh]
        mov word [temp_size+2], ax
        ; 名称转 dotted
        mov si, di
        lea di, [temp_name]
        call fat_83_to_dotted
        ; 模式转 dotted
        lea si, [search_pattern]
        lea di, [temp_pat]
        call fat_83_to_dotted
        ; 通配符匹配
        lea si, [temp_pat]
        lea di, [temp_name]
        call fat_wildcard_match
        jc .loop
        ; 填充 DTA
        mov es, [dta_seg]
        mov di, [dta_off]
        mov al, [temp_attr]
        mov [es:di+15h], al
        mov ax, [temp_time]
        mov [es:di+16h], ax
        mov ax, [temp_date]
        mov [es:di+18h], ax
        mov ax, word [temp_size]
        mov [es:di+1Ah], ax
        mov ax, word [temp_size+2]
        mov [es:di+1Ch], ax
        add di, 1Eh
        lea si, [temp_name]
.copy_name:
        mov al, [si]
        mov [es:di], al
        inc si
        inc di
        test al, al
        jnz .copy_name
        ; 推进搜索位置
        mov ax, [dir_state_pos]
        mov [search_pos], ax
        clc
        ret
.nomore:
        mov ax, 18h
        stc
        ret

; ============================================================================
;  重命名与时间
; ============================================================================

; AH=56：重命名/移动文件
;  入口：DS:DX = 旧路径，ES:DI = 新路径
fn_rename:
        ; 拷贝新路径到 rename_new
        mov ax, [caller_es]
        mov es, ax
        mov si, di
        lea di, [rename_new]
.copy_new:
        mov al, [es:si]
        mov [di], al
        inc si
        inc di
        test al, al
        jnz .copy_new
        ; 查找旧文件
        call fat_find_file
        jc .notfound
        mov ax, [find_dirsector]
        mov [old_sec], ax
        mov ax, [find_diroff]
        mov [old_off], ax
        ; 读旧目录项内容（32 字节）
        mov ax, [old_sec]
        test ax, ax
        jz .notfound
        mov cx, 1
        mov di, ds
        mov es, di
        lea bx, [dir_buf]
        call read_sector_lba
        jc .err
        mov si, [old_off]
        lea di, [old_entry]
        mov cx, 32
        rep movsb
        ; 拷贝新路径到 path_buf 并分解
        lea si, [rename_new]
        lea di, [path_buf]
.copy2:
        mov al, [si]
        mov [di], al
        inc si
        inc di
        test al, al
        jnz .copy2
        call split_parent_name
        jc .notfound
        mov [new_parent], bx
        ; 检查目标目录是否已有同名文件
        mov [dir_state_first], bx
        mov word [dir_state_pos], 0
.check:
        call fat_iter_dir
        jc .no_conflict
        mov al, [es:di]
        cmp al, 0E5h
        je .check
        lea si, [norm_buf]
        mov cx, 11
        push di
        repe cmpsb
        pop di
        jne .check
        ; 同名已存在
        mov ax, 80h
        stc
        ret
.no_conflict:
        ; 在目标目录找空闲项
        mov bx, [new_parent]
        call find_free_dir_entry
        jc .diskfull
        ; 读目标扇区，写新项（名称 + 其余内容）
        mov ax, [find_dirsector]
        mov cx, 1
        mov di, ds
        mov es, di
        lea bx, [dir_buf]
        call read_sector_lba
        jc .err
        mov ax, [find_diroff]
        mov [temp_dirent_off], ax
        add ax, dir_buf
        mov di, ax
        lea si, [norm_buf]
        mov cx, 11
        rep movsb
        lea si, [old_entry+11]
        mov cx, 21
        rep movsb
        mov ax, [find_dirsector]
        mov cx, 1
        lea bx, [dir_buf]
        call write_sector_lba
        jc .err
        ; 删除旧目录项
        mov ax, [old_sec]
        mov cx, 1
        lea bx, [dir_buf]
        call read_sector_lba
        jc .err
        mov di, [old_off]
        mov byte [dir_buf+di], 0E5h
        mov ax, [old_sec]
        mov cx, 1
        lea bx, [dir_buf]
        call write_sector_lba
        jc .err
        xor ax, ax
        ret
.notfound:
        mov ax, 2
        stc
        ret
.diskfull:
        mov ax, 19h
        stc
        ret
.err:
        mov ax, 2
        stc
        ret

; AH=57：取/设文件时间日期
;  入口：AL=0 取（返回 CX=时间, DX=日期），AL=1 设（CX=时间, DX=日期）；BX=句柄
fn_filetime:
        push bx cx dx si bp
        mov bp, bx              ; 句柄号
        call handle_resolve
        jc .err
        mov [temp_fdoff], bx
        ; 读目录项扇区
        mov ax, [bx+FD_DIRSEC]
        test ax, ax
        jz .err
        mov cx, 1
        mov di, ds
        mov es, di
        lea bx, [dir_buf]
        call read_sector_lba
        jc .err
        mov bx, [temp_fdoff]
        mov si, [bx+FD_DIROFF]
        test al, 1
        jnz .set
        mov ax, word [dir_buf+si+16h]
        mov cx, ax
        mov ax, word [dir_buf+si+18h]
        mov dx, ax
        clc
        jmp .done
.set:
        mov word [dir_buf+si+16h], cx
        mov word [dir_buf+si+18h], dx
        mov bx, [temp_fdoff]
        mov ax, [bx+FD_DIRSEC]
        mov cx, 1
        lea bx, [dir_buf]
        call write_sector_lba
        jc .err
        xor ax, ax
        clc
        jmp .done
.err:
        mov ax, 1
        stc
.done:
        pop bp si dx cx bx ax
        ret

temp_fdoff      dw 0

