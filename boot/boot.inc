; ============================================================================
;  boot/boot.inc — 引导链共享宏库（FASM 1.73+）
;  被 boot.asm（stage1）/ loadr.asm（stage2）/ mbr.asm 包含
;  原则：结构偏移符号化（struc），例程模板化（macro），约束汇编期化（assert）
;
;  Copyright (C) 2026 Nexsteaduser
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
; ============================================================================

; ---------------- FAT 类型常量 ----------------
FAT12 = 1
FAT16 = 2
FAT32 = 3

; ---------------- 魔数 ----------------
EXT_MAGIC = 0x4C42           ; stage1 扩展块魔数（'LB' 小端）
CTX_MAGIC = 0x4C44           ; 引导上下文块魔数（'LD' 小端）

; ---------------- 内存布局常量 ----------------
CTX_LIN        = 0x0500      ; 引导上下文块（段 0，16 字节）
BPB_COPY_LIN   = 0x0510      ; BPB 副本（段 0，64 字节）
TARGET_SEG     = 0x1000      ; 目标文件加载段
STAGE2_SEG     = 0x2000      ; stage2 加载段
ROOTBUF_SEG    = 0x3000      ; 根目录缓冲段（0x0000 起）
ROOTBUF_FATOFF = 0x1C00      ; FAT 扇区缓冲偏移（1024 字节，FAT12 跨界连读）
VBR_LIN        = 0x7C00      ; MBR/stage1/VBR 运行线性地址
STAGE2_MAX     = 8192        ; stage2 尺寸上限

; ---------------- 结构：BPB（FAT12/16 与 FAT32 字段同体） ----------------
struc BPB16 {
        .jmpCode    rb 3     ; 0
        .oemName    rb 8     ; 3
        .bytsPerSec rw 1     ; 11
        .secPerClus rb 1     ; 13
        .rsvdSecCnt rw 1     ; 14
        .numFATs    rb 1     ; 16
        .rootEntCnt rw 1     ; 17
        .totSec16   rw 1     ; 19
        .media      rb 1     ; 21
        .fatSz16    rw 1     ; 22
        .secPerTrk  rw 1     ; 24
        .numHeads   rw 1     ; 26
        .hiddSec    rd 1     ; 28
        .totSec32   rd 1     ; 32
        .fatSz32    rd 1     ; 36  FAT32
        .extFlags   rw 1     ; 40  FAT32
        .fsVer      rw 1     ; 42  FAT32
        .rootClus   rd 1     ; 44  FAT32
        .fsInfo     rw 1     ; 48  FAT32
        .bkBootSec  rw 1     ; 50  FAT32
        .rsvd32     rb 12    ; 52  FAT32 保留区
        .driveNum   rb 1     ; 64  EBPB 起（本项目不依赖）
        .reserved1  rb 1     ; 65
        .bootSig    rb 1     ; 66
        .volumeID   rd 1     ; 67
        .volumeLab  rb 11    ; 71
        .fsType     rb 8     ; 82
}
struc DIRENT {
        .name       rb 11    ; 0
        .attr       rb 1     ; 11
        .ntRes      rb 1     ; 12
        .crtTimeTenth rb 1   ; 13
        .crtTime    rw 1     ; 14
        .crtDate    rw 1     ; 16
        .lstAccDate rw 1     ; 18
        .fstClusHI  rw 1     ; 20  FAT32 高 16 位起始簇
        .wrtTime    rw 1     ; 22
        .wrtDate    rw 1     ; 24
        .fstClus    rw 1     ; 26
        .fileSize   rd 1     ; 28
}
struc PART_ENTRY {
        .flag       rb 1     ; 0  0x80 = 活动
        .chsStart   rb 3     ; 1
        .type       rb 1     ; 4
        .chsEnd     rb 3     ; 5
        .lba        rd 1     ; 8  分区起始 LBA
        .cnt        rd 1     ; 12 分区总扇区数
}
struc STAGE1_EXT {
        .targetName rb 11    ; +0  目标文件名（11 字节 8.3）
        .mediaFlag  rb 1     ; +11
        .magic      rw 1     ; +12 = EXT_MAGIC
}

; ---------------- 偏移常量（virtual at 0 实例化，每个结构独立一块） ----------------
virtual at 0
        bpbT  BPB16
end virtual
virtual at 0
        dirT  DIRENT
end virtual
virtual at 0
        partT PART_ENTRY
end virtual
virtual at 0
        extT  STAGE1_EXT
end virtual
assert bpbT.totSec32 = 32
assert bpbT.fatSz32  = 36
assert bpbT.rootClus = 44
assert dirT.fstClus  = 26
assert dirT.fstClusHI = 20
assert partT.lba     = 8
assert extT.magic    = 12

; ---------------- 打印例程（每个汇编单元实例化一次） ----------------
macro PRINT_PROCS {
print_str:                   ; DS:SI = 0 结束字符串；破坏 AX BX SI
        lodsb
        test al, al
        jz .done
        mov ah, 0x0E
        xor bx, bx
        int 0x10
        jmp print_str
.done:
        ret
hex_nib:                     ; AL 低 4 位 → 字符；破坏 AX BX
        and al, 0x0F
        cmp al, 10
        jb .digit
        add al, 'A'-10
        jmp .emit
.digit:
        add al, '0'
.emit:
        mov ah, 0x0E
        xor bx, bx
        int 0x10
        ret
hex_al:                      ; AL → 两位十六进制；破坏 AX BX
        push ax
        shr al, 4
        call hex_nib
        pop ax
        and al, 0x0F
        call hex_nib
        ret
}

macro PRINT_CH ch* {         ; 输出单字符；破坏 AX BX
        mov al, ch
        mov ah, 0x0E
        xor bx, bx
        int 0x10
}

; ---------------- 统一错误出口（终态：挂机不重启） ----------------
; 前置：AH=INT 13h 错误码，DL=盘号；实例置于唯一全局标号之下
macro DISK_ERR stage_msg* {
        push ax
        push bx
        push cx
        push dx
        push si
        mov si, stage_msg
        call print_str
        mov si, msg_errtail       ; ' ERR='
        call print_str
        mov al, ah
        call hex_al               ; 错误码
        mov si, msg_errdrv        ; ' DRV='
        call print_str
        mov al, dl
        call hex_al               ; 盘号
        PRINT_CH 0x0D
        PRINT_CH 0x0A
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
.halt:
        hlt
        jmp .halt
}

; ---------------- CHS 读扇区（16 位 LBA，8086 纯指令） ----------------
; 入口 AX=起始LBA, CX=扇区数, ES:BX=缓冲；成功全寄存器保持；失败不返回（AH=错误码）
macro CHS_READ name*, drive_src*, spt_src*, heads_src*, retry_n*, err_lbl* {
name:
        push ax
        push cx
        push dx
        push bx
        push si
        push di
        push bp
        mov [.lba], ax
        mov [.cnt], cx
.loop:
        mov byte [.retry], retry_n
.retry:
        mov ax, [.lba]
        xor dx, dx
        mov cx, spt_src
        div cx                    ; AX=LBA/SPT，DX=LBA%SPT
        inc dx
        mov [.sec], dl            ; 扇区号 1..SPT
        xor dx, dx
        mov cx, heads_src
        div cx                    ; AX=柱面，DX=磁头
        mov ch, al
        mov cl, [.sec]
        mov dh, dl
        mov dl, drive_src
        mov al, 1
        mov ah, 0x02
        int 0x13
        jnc .next
        mov [.errcd], ah          ; 暂存错误码（复位破坏 AH）
        xor ah, ah
        int 0x13                  ; 复位驱动器
        dec byte [.retry]
        jnz .retry
        pop bp
        pop di
        pop si
        pop bx
        pop dx
        pop cx
        pop ax
        mov ah, [.errcd]
        jmp err_lbl
.next:
        inc word [.lba]
        add bx, 0x200
        dec word [.cnt]
        jnz .loop
        pop bp
        pop di
        pop si
        pop bx
        pop dx
        pop cx
        pop ax
        ret
.lba    dw 0
.cnt    dw 0
.sec    db 0
.retry  db 0
.errcd  db 0
}

; ---------------- INT 13h 扩展检测（DL=盘号） ----------------
macro DAP_PROBE fail_lbl* {
        mov ah, 0x41
        mov bx, 0x55AA
        int 0x13
        jc fail_lbl
        cmp bx, 0x55AA
        jne fail_lbl
}

; ---------------- DAP 读扇区（32 位 LBA，386 指令） ----------------
; 前置：DAP_PROBE 已通过；单次 CX ≤ 0x7F
; 入口 EAX=起始LBA, CX=扇区数, ES:BX=缓冲, DL=盘号；成功全寄存器保持；失败不返回
macro DAP_READ name*, retry_n*, err_lbl* {
name:
        push ax
        push cx
        push dx
        push bx
        push si
        push di
        push bp
        mov [.cnt], cx
        mov [.off], bx
        mov [.seg], es
        mov dword [.lba], eax
.loop:
        mov byte [.dap+0], 0x10
        mov byte [.dap+1], 0
        mov ax, [.cnt]
        mov [.dap+2], ax
        mov ax, [.off]
        mov [.dap+4], ax
        mov ax, [.seg]
        mov [.dap+6], ax
        mov eax, [.lba]
        mov [.dap+8], eax
        mov dword [.dap+12], 0
        mov byte [.retry], retry_n
.retry:
        mov si, .dap
        mov ah, 0x42
        int 0x13
        jnc .done
        mov [.errcd], ah
        xor ah, ah
        int 0x13                  ; 复位
        dec byte [.retry]
        jnz .retry
        pop bp
        pop di
        pop si
        pop bx
        pop dx
        pop cx
        pop ax
        mov ah, [.errcd]
        jmp err_lbl
.done:
        pop bp
        pop di
        pop si
        pop bx
        pop dx
        pop cx
        pop ax
        ret
.dap    rb 16
.lba    rd 1
.cnt    rw 1
.off    rw 1
.seg    rw 1
.retry  rb 1
.errcd  rb 1
}

; ---------------- LBA-assist CHS 换算（386，MBR 回退路径用） ----------------
; 入口 EAX=LBA；spt_src/heads_src 为 16 位内存操作数（如 [mbr_spt]）
; 出口 CH=柱面低8，CL=扇区|柱面高2，DH=磁头；破坏 EAX EDX
macro LBA_ASSIST name*, spt_src*, heads_src* {
name:
        push ecx
        push ebx
        mov ebx, spt_src
        xor edx, edx
        div ebx                   ; EAX=LBA/SPT，EDX=LBA%SPT
        inc edx
        mov ecx, edx              ; 扇区号 1..63
        mov ebx, heads_src
        xor edx, edx
        div ebx                   ; EAX=柱面，EDX=磁头
        mov dh, dl
        mov ch, al                ; 柱面低 8 位
        shr eax, 8
        and al, 0x03              ; 柱面高 2 位
        shl al, 6
        or cl, al                 ; CL = 扇区 | 柱面高 2 位
        pop ebx
        pop ecx
        ret
}

; ---------------- FAT 表取下一簇 ----------------
; 入口：12/16 → AX=簇号；32 → EAX=簇号。出口：同寄存器=下一簇，0=链尾
; fatbuf_seg 参数为段值表达式（stage1 用常量 ROOTBUF_SEG，stage2 亦用 ROOTBUF_SEG）
; 除返回寄存器外全保持；读失败经 read_sec 转 err_lbl（终态）
macro FAT_NEXT name*, fatbits*, bpb_sym*, fatbuf_seg*, fatbuf_off*, read_sec*, err_lbl* {
name:
        push bx
        push cx
        push dx
        push si
        push es
if fatbits = FAT32
        shl eax, 2                    ; EAX=FAT 内字节偏移
        xor edx, edx
        mov ebx, 512
        div ebx                       ; EAX=FAT 内扇区数，EDX=扇区内偏移（4 对齐不跨界）
        movzx ecx, word [bpb_sym+bpbT.rsvdSecCnt]
        add eax, ecx                  ; FAT 项所在扇区 LBA
        mov [.sec32], eax
        mov bx, fatbuf_off
        mov ax, fatbuf_seg
        mov es, ax
        mov eax, [.sec32]
        mov cx, 1
        call read_sec
        mov eax, [es:bx+edx]          ; 32 位表项
        cmp eax, 0x0FFFFFF8
        jb .ok
        xor eax, eax                  ; 链尾 → 0
else
        mov si, ax                    ; SI=簇号
        mov ax, si
        shr ax, 1
        add ax, si                    ; AX=簇号*1.5
        xor dx, dx
        mov cx, 512
        div cx                        ; AX=FAT 内扇区数，DX=扇区内偏移
        add ax, [bpb_sym+bpbT.rsvdSecCnt]   ; FAT 项所在扇区 LBA
        mov bx, fatbuf_off
        mov cx, 1
        cmp dx, 511                   ; FAT12 表项跨扇区 → 连读两扇区（缓冲 1024B）
        jne .rd
        inc cx
.rd:
        push ax
        mov ax, fatbuf_seg
        mov es, ax
        pop ax
        call read_sec
        mov ax, [es:bx+dx]            ; 16 位窗口含目标 12 位
        test si, 1
        jz .even
        shr ax, 4                     ; 奇簇取高 12 位
        jmp .chk
.even:
        and ax, 0x0FFF                ; 偶簇取低 12 位
.chk:
        cmp ax, 0x0FF8
        jb .ok
        xor ax, ax                    ; 链尾 → 0
end if
.ok:
        pop es
        pop si
        pop dx
        pop cx
        pop bx
        ret
.sec32  rd 1
}

; ---------------- 按名加载文件（8.3 根目录搜索 + 簇链读取） ----------------
; 设计：寄存器保存集固定（入口 push ax cx dx si di es，出口逆序 pop；BX 存槽恢复），
;       全部中间量走实例内存槽，循环体内除 cmpsb 前的 cx/di 成对压栈外零压栈
;       → 唯一出口 .done，栈恒净
; 前置：调用方 BX = 目标缓冲偏移（目标段由本宏经 TARGET_SEG 常量自行设置）；
;       DS = bpb_sym 与 name_ptr 所在段（stage1/MBR: 0；stage2: 0x2000）
; name_ptr 指向 11 字节文件名；notfound_lbl/err_lbl 均为终态（不返回）
macro READ_FILE name*, fatbits*, bpb_sym*, rootbuf_seg*, fatbuf_seg*, fatbuf_off*, name_ptr*, read_sec*, fat_next*, err_lbl*, notfound_lbl* {
name:
        push ax
        push cx
        push dx
        push si
        push di
        push es
        mov [.tbx], bx                ; 目标缓冲偏移入槽
if fatbits = FAT32
        ; ================= FAT32 分支（386） =================
        ; dataStart = rsvd + numFATs*fatSz32
        mov al, [bpb_sym+bpbT.numFATs]
        xor ah, ah
        mov ecx, [bpb_sym+bpbT.fatSz32]
        mul ecx                       ; EDX:EAX = numFATs*fatSz32
        movzx ecx, word [bpb_sym+bpbT.rsvdSecCnt]
        add eax, ecx
        mov [.ds32], eax
        ; 根目录：rootClus 起的簇链逐簇扫
        mov eax, [bpb_sym+bpbT.rootClus]
        mov [.clu32], eax
.rootscan:
        mov eax, [.clu32]
        test eax, eax
        jz notfound_lbl               ; 根链耗尽未命中
        mov cl, [bpb_sym+bpbT.secPerClus]
        xor ch, ch
        mov [.spc], cx
        sub eax, 2
        mul ecx                       ; EDX:EAX=(clu-2)*spc
        add eax, [.ds32]              ; EAX=根簇 LBA
        mov dx, rootbuf_seg
        mov es, dx
        xor bx, bx
        call read_sec                 ; 整簇 → ROOTBUF_SEG:0
        mov cx, [.spc]
        shl ecx, 4                    ; 本簇目录项数 = spc*16
        mov dx, rootbuf_seg
        mov es, dx
        xor di, di
.entry32:
        test cx, cx
        jz .rootnext
        mov si, name_ptr
        push cx
        push di
        mov cx, 11
        repe cmpsb                    ; DS:SI（名） vs ES:DI（项）
        pop di
        pop cx
        je .hit32
        add di, 32
        dec cx
        jmp .entry32
.hit32:
        mov ax, [es:di+dirT.fstClus]
        mov dx, [es:di+dirT.fstClusHI]
        shl edx, 16
        mov dx, ax                    ; EDX = 32 位起始簇
        mov eax, edx
        mov [.clu32], eax             ; → 文件链首簇
        jmp .chain32
.rootnext:
        mov eax, [.clu32]
        call fat_next                 ; EAX=下一根簇，0=链尾
        mov [.clu32], eax
        jmp .rootscan
.chain32:
        mov ax, TARGET_SEG
        mov es, ax
        mov bx, [.tbx]
        mov word [.nclu], 0
.cluloop32:
        inc word [.nclu]
        cmp word [.nclu], 0x1000      ; 簇数 >4096 → FAT 环等坏链
        ja notfound_lbl               ; → 终态报错，禁止静默灌内存
        mov eax, [.clu32]
        test eax, eax
        jz .done
        mov cl, [bpb_sym+bpbT.secPerClus]
        xor ch, ch
        mov [.spc], cx
        sub eax, 2
        mul ecx
        add eax, [.ds32]              ; EAX=簇 LBA
        call read_sec                 ; 簇 → ES:BX
        mov cx, [.spc]
        shl ecx, 9                    ; 前进量 = spc*512（386 允许 imm）
        add bx, cx
        mov eax, [.clu32]
        call fat_next                 ; EAX=下一簇，0=链尾
        mov [.clu32], eax
        jmp .cluloop32
else
        ; ================= FAT12/16 分支（8086 纯指令） =================
        ; rootStart = rsvd + numFATs*fatSz16
        mov al, [bpb_sym+bpbT.numFATs]
        xor ah, ah
        mov cx, [bpb_sym+bpbT.fatSz16]
        mul cx                        ; AX=numFATs*fatSz16
        add ax, [bpb_sym+bpbT.rsvdSecCnt]
        mov [.rootstart], ax
        ; rootSects = (rootEntCnt*32+511)/512
        mov ax, [bpb_sym+bpbT.rootEntCnt]
        shl ax, 1
        shl ax, 1
        shl ax, 1
        shl ax, 1
        shl ax, 1                     ; ×32
        add ax, 511
        xor dx, dx
        mov cx, 512
        div cx                        ; AX=rootSects
        mov [.rootsects], ax
        ; 整个根目录区 → ROOTBUF_SEG:0
        mov dx, rootbuf_seg
        mov es, dx
        xor bx, bx
        mov ax, [.rootstart]
        mov cx, [.rootsects]
        call read_sec
        ; 扫描 rootEntCnt 项
        mov dx, rootbuf_seg
        mov es, dx
        xor di, di
        mov cx, [bpb_sym+bpbT.rootEntCnt]
.entry:
        test cx, cx
        jz notfound_lbl
        mov si, name_ptr
        push cx
        push di
        mov cx, 11
        repe cmpsb                    ; DS:SI（名） vs ES:DI（项）
        pop di
        pop cx
        je .hit
        add di, 32
        dec cx
        jmp .entry
.hit:
        mov ax, [es:di+dirT.fstClus]
        mov [.clu], ax                ; 文件链首簇
        ; dataStart = rootStart + rootSects
        mov ax, [.rootstart]
        add ax, [.rootsects]
        mov [.datastart], ax
        ; 恢复目标缓冲
        mov ax, TARGET_SEG
        mov es, ax
        mov bx, [.tbx]
        mov word [.nclu], 0
.cluloop:
        inc word [.nclu]
        cmp word [.nclu], 0x1000      ; 簇数 >4096 → FAT 环等坏链
        ja notfound_lbl               ; → 终态报错，禁止静默灌内存
        mov ax, [.clu]
        test ax, ax
        jz .done
        mov cl, [bpb_sym+bpbT.secPerClus]
        xor ch, ch
        mov [.spc], cx
        sub ax, 2
        mul cx                        ; DX:AX=(clu-2)*spc
        add ax, [.datastart]          ; AX=簇 LBA
        call read_sec                 ; 簇 → ES:BX
        mov cx, [.spc]
        push ax                       ; 当前簇（BX 前进借用 AX 乘法）
        mov ax, cx
        mov cx, 512
        mul cx                        ; AX=spc*512（DX=0）
        add bx, ax
        pop ax                        ; 当前簇 → fat_next
        call fat_next                 ; AX=下一簇，0=链尾
        mov [.clu], ax
        jmp .cluloop
end if
.done:
        mov bx, [.tbx]
        pop es
        pop di
        pop si
        pop dx
        pop cx
        pop ax
        ret
.tbx        dw 0
.spc        dw 0
.nclu       dw 0
if fatbits = FAT32
.ds32       rd 1
.clu32      rd 1
else
.rootstart  dw 0
.rootsects  dw 0
.datastart  dw 0
.clu        dw 0
end if
}
