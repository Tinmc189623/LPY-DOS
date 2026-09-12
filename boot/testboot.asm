; ============================================================================
;  boot/testboot.asm — boot.inc 汇编期静态测试
;  验证结构偏移、常量与结构总长；输出为空文件，fasm 退出码 0 即通过
;
;  Copyright (C) 2026 Nexsteaduser
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
; ============================================================================

use16
org 0

include 'boot.inc'

; ---- 常量 ----
assert CTX_LIN = 0x0500
assert BPB_COPY_LIN = 0x0510
assert TARGET_SEG = 0x1000
assert STAGE2_SEG = 0x2000
assert ROOTBUF_SEG = 0x3000
assert ROOTBUF_FATOFF = 0x1C00
assert VBR_LIN = 0x7C00
assert EXT_MAGIC = 0x4C42
assert CTX_MAGIC = 0x4C44

; ---- BPB16 偏移 ----
assert bpbT.bytsPerSec = 11
assert bpbT.secPerClus = 13
assert bpbT.rsvdSecCnt = 14
assert bpbT.numFATs = 16
assert bpbT.rootEntCnt = 17
assert bpbT.totSec16 = 19
assert bpbT.media = 21
assert bpbT.fatSz16 = 22
assert bpbT.secPerTrk = 24
assert bpbT.numHeads = 26
assert bpbT.hiddSec = 28
assert bpbT.totSec32 = 32
assert bpbT.fatSz32 = 36
assert bpbT.extFlags = 40
assert bpbT.fsVer = 42
assert bpbT.rootClus = 44
assert bpbT.fsInfo = 48
assert bpbT.bkBootSec = 50
assert bpbT.rsvd32 = 52
assert bpbT.driveNum = 64

; ---- DIRENT / PART_ENTRY / STAGE1_EXT 偏移 ----
assert dirT.name = 0
assert dirT.attr = 11
assert dirT.fstClusHI = 20
assert dirT.fstClus = 26
assert dirT.fileSize = 28
assert partT.flag = 0
assert partT.chsStart = 1
assert partT.type = 4
assert partT.chsEnd = 5
assert partT.lba = 8
assert partT.cnt = 12
assert extT.targetName = 0
assert extT.mediaFlag = 11
assert extT.magic = 12

; ---- 结构总长 ----
virtual at 0
        s1 BPB16
        assert $ = 90
end virtual
virtual at 0
        s2 DIRENT
        assert $ = 32
end virtual
virtual at 0
        s3 PART_ENTRY
        assert $ = 16
end virtual
virtual at 0
        s4 STAGE1_EXT
        assert $ = 14
end virtual
