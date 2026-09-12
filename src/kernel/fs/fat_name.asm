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

