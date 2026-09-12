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
; 仅保留 print_str；十六进制转储空间紧张，错误信息以短字符串直接给出
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
}

macro PRINT_CH ch* {         ; 输出单字符；破坏 AX BX
        mov al, ch
        mov ah, 0x0E
        xor bx, bx
        int 0x10
}

; ---------------- 统一错误出口（终态：挂机不重启） ----------------
; 前置：DS 可用；实例置于唯一全局标号之下。终态无需保存/恢复寄存器。
macro DISK_ERR stage_msg* {
        mov si, stage_msg
        call print_str
.halt:
        hlt
        jmp .halt
}

; ---------------- CHS 读扇区（16 位 LBA，8086 纯指令） ----------------
; 入口 AX=起始LBA, CX=扇区数, ES:BX=缓冲；成功 BX 前进至缓冲末尾、其余可破坏；失败不返回
macro CHS_READ name*, drive_src*, spt_src*, heads_src*, retry_n*, err_lbl* {
name:
        push bx
        mov [.lba], ax
        mov [.cnt], cx
.loop:
        mov ax, [.lba]
        xor dx, dx
        mov cx, word spt_src
        div cx                    ; AX=LBA/SPT，DX=LBA%SPT
        inc dx
        mov [.sec], dl            ; 扇区号 1..SPT
        xor dx, dx
        mov cx, word heads_src
        div cx                    ; AX=柱面，DX=磁头
        mov ch, al
        mov cl, [.sec]
        mov dh, dl
        mov dl, drive_src
        mov al, 1
        mov ah, 0x02
        int 0x13
        jnc .next
        jmp err_lbl                ; 失败 → 终态（err_lbl 挂机，无需保存/恢复）
.next:
        inc word [.lba]
        add bx, 0x200
        dec word [.cnt]
        jnz .loop
        pop bx
        ret
.lba    dw 0
.cnt    dw 0
.sec    db 0
}

; ---------------- INT 13h 扩展检测（DL=盘号） ----------------
macro DAP_PROBE fail_lbl* {
        mov ah, 0x41
        mov bx, 0x55AA
        int 0x13
        jc fail_lbl
        cmp bx, 0xAA55
        jne fail_lbl
}

; ---------------- DAP 读扇区（32 位 LBA，386 指令） ----------------
; 前置：DAP_PROBE 已通过；单次 CX ≤ 0x7F
; 入口 EAX=起始LBA, CX=扇区数, ES:BX=缓冲, DL=盘号；成功 BX 保持、其余可破坏；失败不返回
macro DAP_READ name*, retry_n*, err_lbl* {
name:
        push bx
        mov word [.dap+2], cx        ; 扇区数
        mov word [.dap+4], bx        ; 缓冲偏移
        mov word [.dap+6], es        ; 缓冲段
        mov dword [.dap+8], eax      ; 起始 LBA
        mov si, .dap
        mov dl, [boot_drive]         ; DL 可能被根扫描的 mov dx,rootbuf_seg 覆盖
        mov ah, 0x42
        int 0x13
        jnc .ok
        jmp err_lbl                  ; 失败 → 终态
.ok:
        pop bx
        ret
.dap    db 0x10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
}

; ---------------- LBA-assist CHS 换算（386，MBR 回退路径用） ----------------
; 入口 EAX=LBA；spt_src/heads_src 为 16 位内存操作数（如 [mbr_spt]）
; 出口 CH=柱面低8，CL=扇区|柱面高2，DH=磁头；破坏 EAX EDX
macro LBA_ASSIST name*, spt_src*, heads_src* {
name:
        push ecx
        push ebx
        movzx ebx, word spt_src
        xor edx, edx
        div ebx                   ; EAX=LBA/SPT，EDX=LBA%SPT
        inc edx
        mov ecx, edx              ; 扇区号 1..63
        movzx ebx, word heads_src
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
        push es
if fatbits = FAT32
        shl eax, 2                    ; EAX=FAT 内字节偏移
        xor edx, edx
        mov ebx, 512
        div ebx                       ; EAX=FAT 内扇区数，EDX=扇区内偏移（4 对齐不跨界）
        movzx ecx, word [bpb_sym+bpbT.rsvdSecCnt]
        add eax, ecx                  ; FAT 项所在扇区 LBA
        push eax                      ; LBA 入栈（下述 mov ax,fatbuf_seg 会破坏 EAX）
        mov di, dx                    ; DI=扇区内偏移（16 位变址只能用 bx+di/si）
        mov bx, fatbuf_off
        mov ax, fatbuf_seg
        mov es, ax
        pop eax                       ; 恢复 LBA
        mov cx, 1
        call read_sec
        mov eax, [es:bx+di]           ; 32 位表项
        cmp eax, 0x0FFFFFF8
        jb .ok
        xor eax, eax                  ; 链尾 → 0
else if fatbits = FAT16
        mov si, ax                    ; SI=簇号
        shl ax, 1                     ; AX=簇号*2（FAT16 每项 2 字节）
        xor dx, dx
        mov cx, 512
        div cx                        ; AX=FAT 内扇区数，DX=扇区内偏移
        add ax, word [bpb_sym+bpbT.rsvdSecCnt]   ; FAT 项所在扇区 LBA
        mov bx, fatbuf_off
        mov di, dx                    ; DI=扇区内偏移
        mov cx, 1
        push ax
        mov ax, fatbuf_seg
        mov es, ax
        pop ax
        call read_sec
        mov ax, [es:bx+di]            ; 16 位表项
        cmp ax, 0xFFF8
        jb .ok
        xor ax, ax                    ; 链尾 → 0
else
        mov si, ax                    ; SI=簇号
        mov ax, si
        shr ax, 1
        add ax, si                    ; AX=簇号*1.5
        xor dx, dx
        mov cx, 512
        div cx                        ; AX=FAT 内扇区数，DX=扇区内偏移
        add ax, word [bpb_sym+bpbT.rsvdSecCnt]   ; FAT 项所在扇区 LBA
        mov bx, fatbuf_off
        mov di, dx                    ; DI=扇区内偏移
        mov cx, 1
        push ax
        mov ax, fatbuf_seg
        mov es, ax
        pop ax
        call read_sec
        mov ax, [es:bx+di]            ; 16 位窗口含目标 12 位
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
        pop bx
        ret
}

; ---------------- 按名加载文件（8.3 根目录搜索 + 簇链读取） ----------------
; 设计：寄存器保存集固定（入口 push ax cx dx si di es，出口逆序 pop；BX 存槽恢复），
;       全部中间量走实例内存槽，循环体内除 cmpsb 前的 cx/di 成对压栈外零压栈
;       → 唯一出口 .done，栈恒净
; 前置：调用方 BX = 目标缓冲偏移（目标段由本宏经 TARGET_SEG 常量自行设置）；
;       DS = bpb_sym 与 name_ptr 所在段（stage1/MBR: 0；stage2: 0x2000）
; name_ptr 指向 11 字节文件名；notfound_lbl/err_lbl 均为终态（不返回）
macro READ_FILE name*, fatbits*, bpb_sym*, rootbuf_seg*, fatbuf_seg*, fatbuf_off*, name_ptr*, read_sec*, fat_next*, err_lbl*, notfound_lbl*, tgt_seg* {
name:
        mov [.tbx], bx                ; 目标缓冲偏移入槽
if fatbits = FAT32
        ; ================= FAT32 分支（386） =================
        ; dataStart = rsvd + numFATs*fatSz32
        mov al, [bpb_sym+bpbT.numFATs]
        xor ah, ah
        mov ecx, dword [bpb_sym+bpbT.fatSz32]
        mul ecx                       ; EDX:EAX = numFATs*fatSz32
        movzx ecx, word [bpb_sym+bpbT.rsvdSecCnt]
        add eax, ecx
        mov [.ds32], eax
        ; 根目录：rootClus 起的簇链逐簇扫
        mov eax, dword [bpb_sym+bpbT.rootClus]
        mov [.clu32], eax
.rootscan:
        mov eax, [.clu32]
        test eax, eax
        jz notfound_lbl               ; 根链耗尽未命中
        mov cl, [bpb_sym+bpbT.secPerClus]
        xor ch, ch
        sub eax, 2
        mul ecx                       ; EDX:EAX=(clu-2)*spc
        add eax, [.ds32]              ; EAX=根簇 LBA
        mov dx, rootbuf_seg
        mov es, dx
        xor bx, bx
        call read_sec                 ; 整簇 → ROOTBUF_SEG:0
        mov cl, [bpb_sym+bpbT.secPerClus]
        xor ch, ch
        shl ecx, 4                    ; 本簇目录项数 = spc*16
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
        mov word [.clu32], ax        ; 低 16 位
        mov dx, [es:di+dirT.fstClusHI]
        mov word [.clu32+2], dx      ; 高 16 位
        jmp .chain32
.rootnext:
        mov eax, [.clu32]
        call fat_next                 ; EAX=下一根簇，0=链尾
        mov [.clu32], eax
        jmp .rootscan
.chain32:
        mov ax, tgt_seg
        mov es, ax
        mov bx, [.tbx]
.cluloop32:
        mov eax, [.clu32]
        test eax, eax
        jz .done
        mov cl, [bpb_sym+bpbT.secPerClus]
        xor ch, ch
        sub eax, 2
        mul ecx
        add eax, [.ds32]              ; EAX=簇 LBA
        call read_sec                 ; 簇 → ES:BX
        mov cl, [bpb_sym+bpbT.secPerClus]
        xor ch, ch
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
        mov cx, word [bpb_sym+bpbT.fatSz16]
        mul cx                        ; AX=numFATs*fatSz16
        add ax, word [bpb_sym+bpbT.rsvdSecCnt]
        mov [.rootstart], ax
        ; rootSects = ceil(rootEntCnt/16)（每扇区 16 个 32B 目录项）
        mov ax, word [bpb_sym+bpbT.rootEntCnt]
        add ax, 15
        mov cl, 4
        shr ax, cl                    ; AX=rootSects
        mov [.rootsects], ax
        ; 整个根目录区 → ROOTBUF_SEG:0（read_sec 保持 ES，扫描时沿用）
        mov dx, rootbuf_seg
        mov es, dx
        xor bx, bx
        mov ax, [.rootstart]
        mov cx, [.rootsects]
        call read_sec
        ; 扫描 rootEntCnt 项（ES 仍为 rootbuf_seg）
        xor di, di
        mov cx, word [bpb_sym+bpbT.rootEntCnt]
.entry:
        test cx, cx
        jz notfound_lbl
        push cx
        push di
        mov si, name_ptr
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
        mov ax, tgt_seg
        mov es, ax
        mov bx, [.tbx]
.cluloop:
        mov ax, [.clu]
        test ax, ax
        jz .done
        dec word [.clucnt]          ; 坏链防护：自环/超长链在 4096 簇内终止
        jz notfound_lbl
        mov cl, [bpb_sym+bpbT.secPerClus]
        xor ch, ch
        mov [.spc], cx
        sub ax, 2
        mul cx                        ; DX:AX=(clu-2)*spc
        add ax, [.datastart]          ; AX=簇 LBA
        call read_sec                 ; 簇 → ES:BX
        mov ax, [.spc]                ; 前进量 = spc*512
        mov cl, 9
        shl ax, cl
        add bx, ax
        mov ax, [.clu]                ; 当前簇 → fat_next
        call fat_next                 ; AX=下一簇，0=链尾
        mov [.clu], ax
        jmp .cluloop
end if
.done:
        mov bx, [.tbx]
        ret
.tbx        dw 0
if fatbits <> FAT32
.spc        dw 0
end if
if fatbits = FAT32
.ds32       rd 1
.clu32      rd 1
else
.rootstart  dw 0
.rootsects  dw 0
.datastart  dw 0
.clu        dw 0
end if
if fatbits <> FAT32
.clucnt     dw 4096          ; 坏链防护初值：每簇 dec，到 0 判终止
end if
}
