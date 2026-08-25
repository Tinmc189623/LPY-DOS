; ============================================================================
;  fat.asm — FAT12/FAT16 文件系统与文件 API
;  对标 MS-DOS 的文件系统服务（INT 21h AH=3C~57）
; ============================================================================

; ----------------------------------------------------------------------------
;  FAT 相关变量
; ----------------------------------------------------------------------------
dir_state_first dw 0            ; 目录枚举：起始簇（0=根目录）
dir_state_pos   dw 0            ; 目录枚举：当前项序号
; 查找结果
find_firstclu   dw 0
find_size       dd 0
find_attr       db 0
find_dirsector  dw 0            ; 目录项所在扇区 LBA
find_diroff     dw 0            ; 目录项在扇区内偏移
find_name       db 11 dup(0)    ; 11 字节文件名
; 路径解析临时
name_buf        db 13 dup(0)    ; 8.3 分量缓冲
norm_buf        db 11 dup(0)    ; 规范化 11 字节名
; 文件读写临时
read_dst_seg    dw 0
read_dst_off    dw 0
temp_clusoff    dw 0
temp_sector     dw 0
temp_off        dw 0
temp_remain     dw 0
; findfirst/findnext 状态
search_pattern  db 13 dup(0)    ; 搜索模式（转小写 8.3，0 结尾）
search_first    dw 0            ; 搜索起始目录簇
search_pos      dw 0            ; 当前搜索项序号

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
        pop es di si dx cx bx ax
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
        mov di, dir_buf
        add di, dx
        clc
        jmp .out
.end:
        stc
.out:
        pop si dx cx bx ax
        ret

; ============================================================================
;  文件名工具
; ============================================================================

; ----------------------------------------------------------------------------
;  fat_normalize_name：把 "NAME.EXT" 转成 11 字节 "NAME    EXT"（大写，空格填充）
;  入口：DS:SI = 源（0 结尾），DS:DI = 目标（11 字节）
; ----------------------------------------------------------------------------
fat_normalize_name:
        push ax bx cx dx si di
        ; 先全部填空格
        mov cx, 11
        mov al, ' '
        push di
.fillsp:
        mov [di], al
        inc di
        loop .fillsp
        pop di
        ; 拷贝主名（最多 8 字符，遇 '.' 或 0 停止）
        mov cx, 8
.main:
        mov al, [si]
        cmp al, '.'
        je .ext
        cmp al, 0
        je .done
        test cx, cx
        jz .skipm
        call upper
        mov [di], al
        inc di
        dec cx
.skipm:
        inc si
        jmp .main
.ext:
        ; cx = 8 - 主名实际长度；扩展名起点 = di + cx
        mov ax, di
        add ax, cx
        mov di, ax
        inc si
        mov cx, 3
.e:
        mov al, [si]
        cmp al, 0
        je .done
        test cx, cx
        jz .skipe
        call upper
        mov [di], al
        inc di
        dec cx
.skipe:
        inc si
        jmp .e
.done:
        pop di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  fat_83_to_dotted：11 字节名转 "NAME.EXT"（0 结尾）
;  入口：DS:SI = 11 字节，DS:DI = 目标（最多 13 字节）
; ----------------------------------------------------------------------------
fat_83_to_dotted:
        push ax bx cx si di
        ; 拷贝主名（去尾部空格）
        mov cx, 8
        mov bx, si
.main:
        mov al, [bx]
        cmp al, ' '
        je .main_done
        cmp al, 0
        je .main_done
        mov [di], al
        inc di
        inc bx
        loop .main
.main_done:
        ; 判断是否有扩展名
        mov al, [si+8]
        cmp al, ' '
        je .noext
        cmp al, 0
        je .noext
        mov al, '.'
        mov [di], al
        inc di
        mov cx, 3
        mov bx, si
        add bx, 8
.ext:
        mov al, [bx]
        cmp al, ' '
        je .ext_done
        cmp al, 0
        je .ext_done
        mov [di], al
        inc di
        inc bx
        loop .ext
.ext_done:
.noext:
        mov byte [di], 0
        pop di si cx bx ax
        ret

; ----------------------------------------------------------------------------
;  fat_wildcard_match：通配符匹配（支持 '*' 与 '?'，不区分大小写）
;  入口：DS:SI = 模式（0 结尾），DS:DI = 实际串（0 结尾）
;  出口：CF=0 表示匹配，CF=1 表示不匹配
; ----------------------------------------------------------------------------
fat_wildcard_match:
        push ax bx cx dx si di
.match:
        mov al, [si]
        cmp al, '*'
        je .star
        cmp al, 0
        je .check_end
        ; 普通字符或 '?'
        mov bl, [di]
        cmp al, '?'
        je .q
        call upper               ; 模式字符大写
        mov ah, al
        mov al, bl
        call upper               ; 实际字符大写
        cmp al, ah
        jne .fail
        inc si
        inc di
        jmp .match
.q:
        cmp bl, 0                ; '?' 不能匹配空
        je .fail
        inc si
        inc di
        jmp .match
.check_end:
        ; 模式结束：实际串也必须结束
        cmp byte [di], 0
        jne .fail
        clc
        jmp .done
.star:
        ; 跳过连续 '*'
        inc si
.skip_stars:
        cmp byte [si], '*'
        jne .after_star
        inc si
        jmp .skip_stars
.after_star:
        cmp byte [si], 0
        je .success              ; 模式以 * 结尾：剩余任意
        mov bx, si               ; bx = 段起点（'*' 后的首个非 '*'）
        ; 从当前 di 开始尝试匹配该段
.match_seg:
        push bx
        mov si, bx
        call wildcard_seg_impl
        pop bx
        jnc .match               ; 段匹配成功，继续主循环
        ; 段匹配失败：串游标前进一位重试
        cmp byte [di], 0
        je .fail
        inc di
        jmp .match_seg
.success:
        clc
        jmp .done
.fail:
        stc
.done:
        pop di si dx cx bx ax
        ret

; ----------------------------------------------------------------------------
;  wildcard_seg_impl：从 SI 起匹配到下一个 '*' 或模式结束（供通配符匹配内部使用）
;  出口：CF=0 成功（SI/DI 已推进）；CF=1 失败
; ----------------------------------------------------------------------------
wildcard_seg_impl:
        push ax bx
.loop:
        mov al, [si]
        cmp al, '*'
        je .ok
        cmp al, 0
        je .ok
        mov bl, [di]
        cmp al, '?'
        je .any
        call upper
        mov ah, al
        mov al, bl
        call upper
        cmp al, ah
        jne .fail
        inc si
        inc di
        jmp .loop
.any:
        cmp bl, 0
        je .fail
        inc si
        inc di
        jmp .loop
.ok:
        pop bx ax
        clc
        ret
.fail:
        pop bx ax
        stc
        ret

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
        push ax bx cx dx si di es
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
        ; 规范化分量名
        lea si, [name_buf]
        lea di, [norm_buf]
        call fat_normalize_name
        ; 与目录项 11 字节名比较
        push di
        lea si, [norm_buf]
        mov cx, 11
        repe cmpsb
        pop di
        je .found_comp
        jmp .enum
.found_comp:
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
        pop es di si dx cx bx ax
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

; ============================================================================
;  文件读写
; ============================================================================

; AH=3F：读文件（句柄 0/1/2 走设备）
fn_read:
        cmp bx, 2
        ja .file
        ; 设备读（键盘）：读 CX 个字符到 DS:DX
        mov es, [caller_ds]
        mov di, dx
        xor si, si
.loop_dev:
        cmp si, cx
        jae .done_dev
        call kbd_read_char
        mov [es:di], al
        inc di
        inc si
        jmp .loop_dev
.done_dev:
        mov ax, si
        ret
.file:
        call handle_resolve
        jc .err
        ; bx = fd 偏移
        mov es, [caller_ds]
        mov di, dx
        call fd_read
        ret
.err:
        mov ax, 6
        stc
        ret

; AH=40：写文件（句柄 0/1/2 走设备）
fn_write:
        cmp bx, 2
        ja .file
        ; 设备写
        mov es, [caller_ds]
        mov si, dx
        mov ax, cx
        push ax
.loop_dev:
        mov al, [es:si]
        call put_char
        inc si
        loop .loop_dev
        pop ax
        ret
.file:
        call handle_resolve
        jc .err
        mov es, [caller_ds]
        mov di, dx
        call fd_write
        ret
.err:
        mov ax, 6
        stc
        ret

; AH=41：删除文件
fn_delete:
        mov es, [caller_ds]
        call fat_find_file
        jc .notfound
        test byte [find_attr], ATTR_DIR
        jnz .acc
        test byte [find_attr], ATTR_READONLY
        jnz .acc
        ; 释放簇链
        mov bx, [find_firstclu]
        test bx, bx
        jz .clr_entry
.free_chain:
        push bx
        call fat_get_next
        pop bx
        test ax, ax
        jz .clr_entry
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
.clr_entry:
        ; 目录项首字节置 0xE5
        mov ax, [find_dirsector]
        test ax, ax
        jz .notfound
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
.err:
        mov ax, 2
        stc
        ret
.notfound:
        mov ax, 2
        stc
        ret
.acc:
        mov ax, 5
        stc
        ret

; AH=42：移动文件指针
;  入口：AL=0 起 1 当前 2 末尾，BX=句柄，CX:DX = 位移
;  出口：DX:AX = 新位置
fn_lseek:
        call handle_resolve
        jc .err
        cmp al, 2
        je .from_end
        cmp al, 1
        je .from_cur
        ; 从开头
        mov word [bx+FD_POS], dx
        mov word [bx+FD_POS+2], cx
        jmp .update
.from_cur:
        add [bx+FD_POS], dx
        adc word [bx+FD_POS+2], cx
        jmp .update
.from_end:
        mov ax, [bx+FD_SIZE]
        mov si, [bx+FD_SIZE+2]
        add ax, dx
        adc si, cx
        mov [bx+FD_POS], ax
        mov [bx+FD_POS+2], si
.update:
        mov ax, [bx+FD_POS]
        mov dx, [bx+FD_POS+2]
        ret
.err:
        mov ax, 1
        stc
        ret

; AH=43：取/设文件属性
;  入口：AL=0 取（CX=属性），AL=1 设（CX=属性）；DS:DX = 路径
fn_getattr:
        test al, 1
        jnz .set
        mov es, [caller_ds]
        call fat_find_file
        jc .notfound
        xor ch, ch
        mov cl, [find_attr]
        ret
.set:
        mov es, [caller_ds]
        call fat_find_file
        jc .notfound
        ; 修改目录项属性字节
        mov ax, [find_dirsector]
        test ax, ax
        jz .notfound
        mov [temp_attr], cl     ; 保存属性
        mov cx, 1
        mov di, ds
        mov es, di
        lea bx, [dir_buf]
        call read_sector_lba
        jc .err
        mov di, [find_diroff]
        mov al, [temp_attr]
        mov byte [dir_buf+di+0Bh], al
        mov ax, [find_dirsector]
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
.err:
        mov ax, 2
        stc
        ret

; AH=47：取当前目录
;  入口：DL = 驱动器（0=默认），DS:SI = 缓冲
fn_get_cwd:
        test dl, dl
        jnz .err
        mov es, [caller_ds]
        mov di, si
        lea si, [current_dir]
.copy:
        mov al, [si]
        mov [es:di], al
        inc si
        inc di
        test al, al
        jnz .copy
        clc
        ret
.err:
        mov ax, 15
        stc
        ret

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
