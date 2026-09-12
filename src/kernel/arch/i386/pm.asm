; ============================================================================
;  arch/i386/pm.asm — 386 增强：保护模式脚手架
;  提供：GDT、A20 线开启、进入 32 位保护模式例程。
;  当前 16 位实模式引导路径不调用 i386_enter_pm；本模块为后续 32 位内核预留，
;  提供可调用例程与描述符表，不破坏现有实模式启动流程。
; ============================================================================

; ---- GDT：null / flat code / flat data（4GB，32 位）----
align 4
gdt32:
        dq 0                            ; 0x00 空描述符
        dw 0FFFFh, 0x0000, 0x9A00, 0xCF ; 0x08 flat code（use32, 4GB）
        dw 0FFFFh, 0x0000, 0x9200, 0xCF ; 0x10 flat data（4GB）
gdt32_end:

gdt32_ptr:
        dw gdt32_end - gdt32 - 1
        dd gdt32

; ---- i386_enable_a20：通过 8042 键盘控制器开启 A20 ----
i386_enable_a20:
        push ax
        call .wait_write
        mov al, 0D1h            ; 写端口 64：准备写输出端口
        out 64h, al
        call .wait_write
        mov al, 0DFh            ; 输出值：A20 置 1
        out 60h, al
        call .wait_write
        pop ax
        ret
.wait_write:
        push ax
.loop:
        in al, 64h
        test al, 02h            ; bit1=1 表示输入缓冲满
        jnz .loop
        pop ax
        ret

; ---- i386_enter_pm：进入 32 位保护模式（进入后不返回实模式）----
;  调用前应已 cli。进入后 DS/ES/SS/FS/GS = 0x10，ESP = 0x90000。
i386_enter_pm:
        cli
        call i386_enable_a20
        lgdt [gdt32_ptr]
        mov eax, cr0
        or  eax, 1
        mov cr0, eax
        jmp 08h:.pm_flush       ; 远跳转清流水线，加载 CS=0x08
use32
.pm_flush:
        mov ax, 0x10
        mov ds, ax
        mov es, ax
        mov ss, ax
        mov fs, ax
        mov gs, ax
        xor esp, esp
        mov esp, 00090000h      ; 预留 32 位栈
        ; TODO: 跳转到 32 位 C/汇编内核入口（arch/i386/kernel32.asm）
.halt:
        hlt
        jmp .halt
use16
