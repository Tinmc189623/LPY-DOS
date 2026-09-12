; ============================================================================
;  boot/boot12.asm — stage1 FAT12 1.44MB 软盘变体
;
;  Copyright (C) 2026 Nexsteaduser
;  This program is free software under the GNU GPL v3 or later.
; ============================================================================
BPB_BYTS_PER_SEC = 512
BPB_SEC_PER_CLUS = 1
BPB_RSVD         = 1
BPB_NUM_FATS     = 2
BPB_ROOT_ENT     = 224
BPB_TOT16        = 2880
BPB_MEDIA        = 0xF0
BPB_FATSZ16      = 9
BPB_SPT          = 18
BPB_HEADS        = 2
BPB_HIDD         = 0
BPB_TOT32        = 0
FATBITS          = 1                 ; FAT12
TARGET_NAME      equ 'LOADR   SYS'   ; 过渡期目标（子项目 4 后切 IO.SYS）
include 'boot.asm'
