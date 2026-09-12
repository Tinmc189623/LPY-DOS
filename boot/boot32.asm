; ============================================================================
;  boot/boot32.asm — stage1 FAT32 分区变体（允许 386 指令；测试卷 66583 扇区）
;
;  Copyright (C) 2026 Nexsteaduser
;  This program is free software under the GNU GPL v3 or later.
; ============================================================================
BPB_BYTS_PER_SEC = 512
BPB_SEC_PER_CLUS = 1
BPB_RSVD         = 32
BPB_NUM_FATS     = 2
BPB_ROOT_ENT     = 0
BPB_TOT16        = 0
BPB_MEDIA        = 0xF8
BPB_FATSZ16      = 0
BPB_SPT          = 63
BPB_HEADS        = 16
BPB_HIDD         = 63
BPB_TOT32        = 66583
BPB_FATSZ32      = 513
BPB_ROOTCLUS     = 2
FATBITS          = 3                 ; FAT32
TARGET_NAME      equ 'LOADR   SYS'
include 'boot.asm'
