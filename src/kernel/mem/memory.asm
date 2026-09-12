; ============================================================================
;  memory.asm — MCB 内存管理、PSP 建立、COM 程序加载执行与进程终止
;  进程模型：MCB 链、PSP、EXEC 与程序退出
;
;  Copyright (C) 2026 Nexsteaduser
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
; ============================================================================

; 内存控制块（MCB）字段偏移
MCB_TYPE        equ 0           ; 'M'=中间块, 'Z'=最后块
MCB_OWNER       equ 1           ; 拥有者 PSP 段（0=空闲）
MCB_SIZE        equ 3           ; 块大小（单位：段，即 16 字节）
MCB_NAME        equ 8           ; 8 字节程序名

; ----------------------------------------------------------------------------
;  进程上下文变量
; ----------------------------------------------------------------------------
saved_int22     dd 0            ; 旧的 INT 22h（父进程终止地址）
saved_psp       dw 0            ; 父 PSP 段
saved_ss        dw 0            ; 父进程栈段
saved_sp        dw 0            ; 父进程栈指针
prog_seg        dw 0            ; 当前程序加载段（块段）
prog_size       dw 0            ; 当前程序块段数（用于块内栈顶计算）
mcb_first_seg   dw 0            ; MCB 链首段（内核末尾空闲块的 MCB）
temp_alloc_req  dw 0            ; mc_alloc 请求段数暂存


; ============================================================================
;  子模块（按 include 顺序拼接为完整模块；勿在 include 间插代码，新内容进对应子模块）
; ============================================================================
include 'mcb.asm'
include 'psp.asm'
include 'exec.asm'
include 'term.asm'
