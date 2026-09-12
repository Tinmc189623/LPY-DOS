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

