; ============================================================================
;  boot/boot16.asm — stage1 FAT16 分区变体（测试卷 16 磁头/63 扇区/33280 扇区）
;
;  Copyright (C) 2026 Nexsteaduser
;  This program is free software under the GNU GPL v3 or later.
; ============================================================================
BPB_BYTS_PER_SEC = 512
BPB_SEC_PER_CLUS = 4
BPB_RSVD         = 1
BPB_NUM_FATS     = 2
BPB_ROOT_ENT     = 512
BPB_TOT16        = 33280
BPB_MEDIA        = 0xF8
BPB_FATSZ16      = 33
BPB_SPT          = 63
BPB_HEADS        = 16
BPB_HIDD         = 63
BPB_TOT32        = 0
FATBITS          = 2                 ; FAT16
TARGET_NAME      equ 'LPYOS   SYS'
include 'boot.asm'
