; ============================================================================
;  PSP 建立
; ============================================================================

; ----------------------------------------------------------------------------
;  setup_sys_psp：建立内核自身 PSP（SYS_PSP_SEG）并登记为当前 PSP
;  入口：无，出口：无
; ----------------------------------------------------------------------------
setup_sys_psp:
        push ax bx cx es
        mov ax, SYS_PSP_SEG
        mov es, ax
        ; PSP+0：INT 20h 指令（程序终止）
        mov byte [es:0], 0CDh
        mov byte [es:1], 20h
        ; PSP+2：内存顶端段
        mov word [es:2], MEM_TOP_SEG
        ; PSP+0A~0x14：从 IVT 拷贝 INT 22h/23h/24h 地址
        xor ax, ax
        mov bx, ax
        mov ds, bx
        mov ax, [22h*4]
        mov [es:0Ah], ax
        mov ax, [22h*4+2]
        mov [es:0Ch], ax
        mov ax, [23h*4]
        mov [es:0Eh], ax
        mov ax, [23h*4+2]
        mov [es:10h], ax
        mov ax, [24h*4]
        mov [es:12h], ax
        mov ax, [24h*4+2]
        mov [es:14h], ax
        mov ax, KERNEL_SEG
        mov ds, ax
        ; PSP+16：父 PSP = 自身
        mov word [es:16h], SYS_PSP_SEG
        ; PSP+2C：环境段 = 0（无环境）
        mov word [es:2Ch], 0
        ; PSP+18：句柄表 20 字节全 0xFF
        mov cx, 20
        mov bx, 18h
.fill:
        mov byte [es:bx], 0FFh
        inc bx
        loop .fill
        ; FCB 区与命令行尾部
        call fill_psp_fields
        ; 默认 DTA = PSP:0x80
        mov word [dta_seg], SYS_PSP_SEG
        mov word [dta_off], 80h
        mov [current_psp], SYS_PSP_SEG
        pop es cx bx ax
        ret

; ----------------------------------------------------------------------------
;  fill_psp_fields：填充 PSP 的 FCB 区与命令行尾部
;  入口：ES = PSP 段（KERNEL_SEG）；命令行取自 exec_cmdline[0]=长度
; ----------------------------------------------------------------------------
fill_psp_fields:
        push ax bx cx si di
        ; PSP+5C/6C：默认 FCB 区填充空格（各 16 字节）
        mov cx, 32
        mov bx, 5Ch
.fill_fcb:
        mov byte [es:bx], 20h
        inc bx
        loop .fill_fcb
        ; PSP+80：命令行尾部长度 + 字符 + 0Dh
        lea si, [exec_cmdline]  ; si = 长度字节
        lea di, [es:80h]
        mov cl, [si]
        xor ch, ch
        mov [di], cl            ; 长度
        inc si
        inc di
        rep movsb               ; 复制字符
        mov byte [es:di], 0Dh   ; 回车
        pop di si cx bx ax
        ret

