; ============================================================================
;  命令分发
; ============================================================================
dispatch:
        push ax bx si di
        lea si, [cmd_table]
.find:
        cmp byte [si], 0        ; 表尾
        je .external
        lea di, [cmd_name]
        push si
        call strcmp_i
        pop si
        je .found
        add si, 14
        jmp .find
.found:
        ; DX 不在 dispatch 的保存列表（ax bx si di）中，用它暂存处理函数地址，
        ; 避免 pop 恢复寄存器时把 bx 中的地址覆盖掉
        mov dx, [si+12]
        pop di si bx ax
        call dx                 ; 调用命令处理
        jmp dispatch_done
.external:
        pop di si bx ax
        call exec_external
dispatch_done:
        ret

