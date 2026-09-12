; ============================================================================
;  句柄与文件描述符管理
; ============================================================================

; 追加变量
read_total      dw 0
req_remain      dw 0
temp_alloc      dw 0
temp_next       dw 0
temp_dirent_seg dw 0
temp_dirent_off dw 0
rename_new      db 80 dup(0)
rename_last     db 11 dup(0)
create_attr     db 0

; ----------------------------------------------------------------------------
;  fd_alloc：分配空闲文件描述符
;  出口：BX = fd 偏移（fd_table 起），CF=1 表示无空闲
; ----------------------------------------------------------------------------
fd_alloc:
        push ax cx di
        lea di, [fd_table]
        mov cx, NUM_HANDLES
        xor bx, bx
.loop:
        cmp word [di], 0
        je .found
        add di, FD_LEN
        inc bx
        loop .loop
        stc
        jmp .done
.found:
        clc
.done:
        pop di cx ax
        ret

; ----------------------------------------------------------------------------
;  handle_alloc：分配空闲句柄
;  出口：CX = 句柄号，CF=1 表示已满
; ----------------------------------------------------------------------------
handle_alloc:
        push ax bx
        lea bx, [handles]
        mov cx, 0
.loop:
        cmp word [bx], 0FFFFh
        je .found
        add bx, 2
        inc cx
        cmp cx, NUM_HANDLES
        jae .full
        jmp .loop
.full:
        stc
        jmp .done
.found:
        clc
.done:
        pop bx ax
        ret

; ----------------------------------------------------------------------------
;  fd_read：从文件描述符读取数据
;  入口：BX = fd 偏移，CX = 请求字节数，ES:DI = 目标缓冲
;  出口：AX = 实际读取字节数
; ----------------------------------------------------------------------------
fd_read:
        push ax bx cx dx si di bp
        mov bp, bx
        mov [read_dst_seg], es
        mov [read_dst_off], di
        mov [req_remain], cx
        mov word [read_total], 0
.loop:
        cmp word [req_remain], 0
        je .done
        ; 检查 EOF
        mov ax, [bp+FD_POS]
        mov dx, [bp+FD_POS+2]
        cmp dx, [bp+FD_SIZE+2]
        jb .ok
        ja .done
        cmp ax, [bp+FD_SIZE]
        jae .done
.ok:
        ; 确保当前簇覆盖 pos
        mov dx, [bpb_sec_per_clus]
        shl dx, 9                ; dx = 簇字节数
        mov ax, [bp+FD_POS]
        mov bx, [bp+FD_POS+2]
        sub ax, [bp+FD_CURPOS]
        sbb bx, [bp+FD_CURPOS+2]
        jc .repos
        test bx, bx
        jnz .advance
        cmp ax, dx
        jae .advance
        mov bx, ax               ; 簇内偏移
        jmp .in
.advance:
        mov bx, [bp+FD_CURCLU]
        call fat_get_next
        cmp ax, 0FF8h
        jae .done
        mov [bp+FD_CURCLU], ax
        mov ax, [bpb_sec_per_clus]
        add [bp+FD_CURPOS], ax
        adc word [bp+FD_CURPOS+2], 0
        jmp .loop
.repos:
        mov ax, [bp+FD_CLUSTER]
        mov [bp+FD_CURCLU], ax
        mov word [bp+FD_CURPOS], 0
        mov word [bp+FD_CURPOS+2], 0
        jmp .loop
.in:
        ; bx = 簇内偏移；读该扇区
        mov ax, bx
        mov si, 512
        xor dx, dx
        div si                   ; ax = 簇内扇区号, dx = 扇区内偏移
        mov [temp_sector], ax
        mov [temp_off], dx
        push dx
        mov bx, [bp+FD_CURCLU]
        call cluster_to_lba
        add ax, [temp_sector]
        mov cx, 1
        mov di, ds
        mov es, di
        lea bx, [dir_buf]
        call read_sector_lba
        pop dx
        ; n = min(req_remain, 512 - 扇区内偏移)
        mov cx, 512
        sub cx, dx
        mov ax, [req_remain]
        cmp ax, cx
        jbe .n1
        mov ax, cx
.n1:
        mov cx, ax
        mov si, dir_buf
        add si, dx
        mov es, [read_dst_seg]
        mov di, [read_dst_off]
        rep movsb
        ; 更新状态
        add [read_dst_off], ax
        add [read_total], ax
        sub [req_remain], ax
        add [bp+FD_POS], ax
        adc word [bp+FD_POS+2], 0
        jmp .loop
.done:
        mov ax, [read_total]
        pop bp di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  fd_write：向文件描述符写入数据（自动扩展文件）
;  入口：BX = fd 偏移，CX = 字节数，ES:DI = 源数据
;  出口：AX = 实际写入字节数
; ----------------------------------------------------------------------------
fd_write:
        push ax bx cx dx si di bp
        mov bp, bx
        mov [read_dst_seg], es
        mov [read_dst_off], di
        mov [req_remain], cx
        mov word [read_total], 0
.loop:
        cmp word [req_remain], 0
        je .finish
        ; 确保簇覆盖 pos（必要时扩展）
        mov ax, [bp+FD_CURCLU]
        test ax, ax
        jz .need_extend          ; 空文件
        mov dx, [bpb_sec_per_clus]
        shl dx, 9
        mov ax, [bp+FD_POS]
        mov bx, [bp+FD_POS+2]
        sub ax, [bp+FD_CURPOS]
        sbb bx, [bp+FD_CURPOS+2]
        jc .repos
        test bx, bx
        jnz .advance
        cmp ax, dx
        jb .in
        ; 位置在簇尾边界，需要新簇
        jmp .advance
.advance:
        mov bx, [bp+FD_CURCLU]
        call fat_get_next
        cmp ax, 0FF8h
        jae .need_extend
        mov [bp+FD_CURCLU], ax
        mov ax, [bpb_sec_per_clus]
        add [bp+FD_CURPOS], ax
        adc word [bp+FD_CURPOS+2], 0
        jmp .loop
.repos:
        mov ax, [bp+FD_CLUSTER]
        mov [bp+FD_CURCLU], ax
        mov word [bp+FD_CURPOS], 0
        mov word [bp+FD_CURPOS+2], 0
        jmp .loop
.need_extend:
        ; 分配新簇
        call fat_alloc
        test ax, ax
        jz .finish
        mov [temp_alloc], ax
        ; 判断是否首个簇
        cmp word [bp+FD_CLUSTER], 0
        jne .link_tail
        ; 首个簇
        mov ax, [temp_alloc]
        mov [bp+FD_CLUSTER], ax
        mov [bp+FD_CURCLU], ax
        mov word [bp+FD_CURPOS], 0
        mov word [bp+FD_CURPOS+2], 0
        jmp .in
.link_tail:
        ; 链接到链尾
        mov bx, [bp+FD_CLUSTER]
.walk:
        push bx
        call fat_get_next
        pop bx
        cmp ax, 0FF8h
        jae .link
        mov bx, ax
        jmp .walk
.link:
        mov ax, [temp_alloc]
        call fat_set_next        ; 旧链尾 -> 新簇
        mov ax, [temp_alloc]
        mov [bp+FD_CURCLU], ax
        jmp .in
.in:
        ; 簇内偏移 = pos - curpos
        mov ax, [bp+FD_POS]
        mov bx, [bp+FD_POS+2]
        sub ax, [bp+FD_CURPOS]
        sbb bx, [bp+FD_CURPOS+2]
        mov bx, ax
        ; 读扇区（读-改-写）
        mov ax, bx
        mov si, 512
        xor dx, dx
        div si
        mov [temp_sector], ax
        mov [temp_off], dx
        push dx
        mov bx, [bp+FD_CURCLU]
        call cluster_to_lba
        add ax, [temp_sector]
        mov cx, 1
        mov di, ds
        mov es, di
        lea bx, [dir_buf]
        call read_sector_lba
        pop dx
        ; n = min(req_remain, 512 - 扇区内偏移)
        mov cx, 512
        sub cx, dx
        mov ax, [req_remain]
        cmp ax, cx
        jbe .n1
        mov ax, cx
.n1:
        ; 拷贝源数据到 dir_buf+dx
        mov cx, ax
        push ax ds
        mov di, dir_buf
        add di, dx
        mov ax, [read_dst_seg]
        mov ds, ax
        mov si, [read_dst_off]
        rep movsb
        pop ds ax
        ; 写回扇区
        mov bx, [bp+FD_CURCLU]
        call cluster_to_lba
        add ax, [temp_sector]
        mov cx, 1
        lea bx, [dir_buf]
        call write_sector_lba
        ; 更新状态
        add [read_dst_off], ax
        add [read_total], ax
        sub [req_remain], ax
        add [bp+FD_POS], ax
        adc word [bp+FD_POS+2], 0
        jmp .loop
.finish:
        ; 更新文件大小并写回目录项
        mov ax, [bp+FD_POS]
        mov dx, [bp+FD_POS+2]
        cmp dx, [bp+FD_SIZE+2]
        jb .size_ok
        ja .use_pos
        cmp ax, [bp+FD_SIZE]
        jbe .size_ok
.use_pos:
        mov [bp+FD_SIZE], ax
        mov [bp+FD_SIZE+2], dx
.size_ok:
        call write_dir_entry
        mov ax, [read_total]
        pop bp di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  write_dir_entry：把 fd 的起始簇与大小写回目录项
;  入口：BP = fd 偏移
; ----------------------------------------------------------------------------
write_dir_entry:
        push ax bx cx dx si di es
        mov ax, [bp+FD_DIRSEC]
        test ax, ax
        jz .done
        mov cx, 1
        mov di, ds
        mov es, di
        lea bx, [dir_buf]
        call read_sector_lba
        jc .done
        mov di, [bp+FD_DIROFF]
        mov ax, [bp+FD_CLUSTER]
        mov word [dir_buf+di+1Ah], ax
        mov ax, [bp+FD_SIZE]
        mov word [dir_buf+di+1Ch], ax
        mov ax, [bp+FD_SIZE+2]
        mov word [dir_buf+di+1Eh], ax
        mov ax, [bp+FD_DIRSEC]
        mov cx, 1
        lea bx, [dir_buf]
        call write_sector_lba
.done:
        pop es di si dx cx bx ax
        ret

; ============================================================================
;  文件 API 服务（INT 21h AH=3C~57）
; ============================================================================

; 追加变量
parent_cluster  dw 0            ; 父目录起始簇（0=根）
create_cluster  dw 0            ; 新建目录项起始簇（文件为 0）
temp_handle     dw 0            ; 临时句柄号
temp_sep        db 0            ; 临时分隔符
temp_attr       db 0            ; 匹配项属性
temp_time       dw 0            ; 匹配项时间
temp_date       dw 0            ; 匹配项日期
temp_size       dd 0            ; 匹配项大小
temp_name       db 13 dup(0)    ; 匹配项名（dotted）
temp_pat        db 13 dup(0)    ; 模式（dotted）
search_attr     db 0            ; findfirst 属性过滤
newdir_clu      dw 0            ; 新目录簇
temp_lba        dw 0            ; 临时 LBA
temp_newclu     dw 0            ; 临时新簇号
old_sec         dw 0            ; 重命名旧目录项扇区
old_off         dw 0            ; 重命名旧目录项偏移
old_entry       db 32 dup(0)    ; 重命名旧目录项内容
new_parent      dw 0            ; 重命名目标父目录簇

; ----------------------------------------------------------------------------
;  handle_resolve：句柄号转文件描述符偏移
;  入口：BX = 句柄号；出口：BX = fd 偏移，CF=0；CF=1 无效句柄
; ----------------------------------------------------------------------------
handle_resolve:
        push ax cx
        cmp bx, NUM_HANDLES
        jae .err
        shl bx, 1
        mov ax, [handles+bx]
        cmp ax, 0FFFFh
        je .err
        test ax, 8000h
        jnz .err
        mov bx, ax
        clc
        jmp .done
.err:
        stc
.done:
        pop cx ax
        ret

; ----------------------------------------------------------------------------
;  load_file_clusters：按簇链加载整个文件到 ES:DI
;  入口：find_firstclu = 起始簇，find_size = 文件大小，ES:DI = 目标
;  出口：CF=1 表示失败
; ----------------------------------------------------------------------------
load_file_clusters:
        push ax bx cx dx si di
        mov bx, [find_firstclu]
        test bx, bx
        jz .done                ; 空文件
        mov si, 0               ; 已加载字节数
.load_clu:
        push bx cx
        mov bx, bx
        call cluster_to_lba     ; ax = 数据区 LBA
        pop cx
        push cx
        mov cx, [bpb_sec_per_clus]
        mov bx, di
        call read_sectors_lba   ; 读整个簇到 es:di
        pop cx bx
        jc .err
        mov dx, [bpb_sec_per_clus]
        shl dx, 9               ; dx = 簇字节数
        add di, dx
        add si, dx
        cmp si, word [find_size]
        jae .done
        ; 下一簇
        push bx
        call fat_get_next
        pop bx
        cmp ax, 0FF8h
        jae .done
        mov bx, ax
        jmp .load_clu
.done:
        clc
        jmp .out
.err:
        stc
.out:
        pop di si dx cx bx ax
        ret

