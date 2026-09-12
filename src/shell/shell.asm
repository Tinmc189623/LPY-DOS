; ============================================================================
;  LPY-DOS 命令解释器 LPYCMD.COM
;  命令解释器：内建命令 + 外部 .COM 程序执行
;
;  编译：fasm shell.asm LPYCMD.COM
;  运行：由内核 reshell 加载，DS=ES=SS=PSP 段，入口 org 100h
;
;  Copyright (C) 2026 Nexsteaduser
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
; ============================================================================

use16
org 100h

include '..\build\version.inc'   ; 版本常量（由 build.ps1 从 version.ini 生成）


; ============================================================================
;  子模块（按 include 顺序拼接为完整程序；勿在 include 间插代码，新内容进对应子模块）
; ============================================================================
include 'shell_start.asm'
include 'shell_table.asm'
include 'shell_main.asm'
include 'shell_dispatch.asm'
include 'shell_exec.asm'
include 'shell_cmd_file.asm'
include 'shell_cmd_sys.asm'
include 'shell_output.asm'
include 'shell_data.asm'
