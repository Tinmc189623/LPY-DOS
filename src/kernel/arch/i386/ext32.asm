; ============================================================================
;  arch/i386/ext32.asm — 386 保护模式扩展入口（独立二进制 EXT32.BIN）
;  由 16 位实模式内核加载到高端内存后跳转到本扩展：开 A20、进 32 位保护模式，
;  再转入 C 运行时（arch/i386/c/kmain.c）。
;  本文件与 16 位内核分离编译，内核本体不含任何 386 指令。
;  编译：fasm arch/i386/ext32.asm EXT32.BIN
; ============================================================================

format binary
use32
org 0

; ---- 16 位 real-mode prologue（由实模式内核直接跳转进入，此时仍是实模式）----
        ; 注意：FASM 本文件默认 use32；进入点由实模式调用，先切到 use16 写 16 位代码
use16
start16:
        cli
        call enable_a20
        lgdt [gdt_ptr]
        mov eax, cr0
        or  eax, 1
        mov cr0, eax
        jmp 08h:.flush_pm
use32
.flush_pm:
        mov ax, 10h
        mov ds, ax
        mov es, ax
        mov ss, ax
        mov fs, ax
        mov gs, ax
        xor esp, esp
        mov esp, 00090000h
        ; 转入 C 运行时主函数 kmain（arch/i386/c/kmain.c）。
        ; 未链接 C 目标时，下方 asm 提供同名占位，保证本扩展可独立汇编。
        call kmain
.hang:
        hlt
        jmp .hang

; 无 C 工具链时的占位 kmain；链接 kmain.o 后由 C 版本取代。
kmain:
        mov edi, 000B8000h      ; VGA 文本缓冲
        mov ah, 0x0A
        mov esi, .msg
.l:
        lodsb
        test al, al
        jz .d
        stosw
        jmp .l
.d:
        ret
.msg db '386 PM extension loaded (C runtime pending)',0

; ---- enable A20（16 位）----
use16
enable_a20:
        push ax
.w1:
        in al, 64h
        test al, 2
        jnz .w1
        mov al, 0D1h
        out 64h, al
.w2:
        in al, 64h
        test al, 2
        jnz .w2
        mov al, 0DFh
        out 60h, al
.w3:
        in al, 64h
        test al, 2
        jnz .w3
        pop ax
        ret
use32

; ---- GDT（4GB flat）----
align 4
gdt:
        dq 0
        dw 0FFFFh, 0, 0x9A00, 0xCF   ; 0x08 code
        dw 0FFFFh, 0, 0x9200, 0xCF   ; 0x10 data
gdt_end:
gdt_ptr:
        dw gdt_end - gdt - 1
        dd gdt
