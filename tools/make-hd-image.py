#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LPY-DOS 预装硬盘镜像生成器
按 src/boot/boot16.asm 写死的 BPB 布局，生成一张可直接引导的 FAT16 硬盘镜像：
  LBA 0           : MBR.BIN + 分区表（活动分区，type 0x0E，起 LBA 63，33280 扇区）
  LBA 63          : boot16.bin VBR
  LBA 63+1..      : FAT1/FAT2/根目录/数据区（LOADR.SYS / LPYOS.SYS / LPYCMD.COM / 全部 .COM）
输出: LPY-DOS-HD.img  (17,071,616 字节)
"""
import os, struct, sys, glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---- boot16.asm 写死的 BPB（不可改，否则 VBR 读错几何）----
BPS       = 512
SPC       = 4
RSVD      = 1
NFATS     = 2
ROOT_ENT  = 512
TOT16     = 33280
MEDIA     = 0xF8
FATSZ     = 33
HIDDEN    = 63          # 分区起始 LBA（MBR 分区表 entry.lba 必须一致）

FAT1_OFF  = RSVD                 # 卷内扇区
ROOT_OFF  = RSVD + NFATS*FATSZ   # 1+66 = 67
ROOT_SECS = (ROOT_ENT*32 + BPS-1)//BPS   # 32
DATA_OFF  = ROOT_OFF + ROOT_SECS          # 99

def name11(stem, ext):
    s = stem.upper()[:8].ljust(8)
    e = ext.upper()[:3].ljust(3)
    return (s+e).encode('ascii')

def build_fat16():
    img = bytearray((HIDDEN + TOT16)*BPS)

    # --- MBR ---
    mbr = bytearray(open(os.path.join(ROOT,'bin','MBR.BIN'),'rb').read())
    assert len(mbr)==512, f"MBR.BIN 应为 512，实际 {len(mbr)}"
    pe = 0x1BE
    img[pe+0]=0x80                 # active
    img[pe+1]=0xFE                 # start head (placeholder)
    img[pe+2]=0xFF                 # start sec|cyl hi
    img[pe+3]=0xFF
    img[pe+4]=0x0E                 # FAT16 LBA
    img[pe+5]=0xFE                 # end head
    img[pe+6]=0xFF
    img[pe+7]=0xFF
    struct.pack_into('<I', img, pe+8,  HIDDEN)     # start LBA
    struct.pack_into('<I', img, pe+12, TOT16)      # sector count
    # MBR code + signature 0xAA55 already in MBR.BIN (last 2 bytes)
    img[0:512]=mbr
    # re-apply partition table on top of MBR code (MBR.BIN leaves 64 zero bytes)
    img[pe+0]=0x80; img[pe+1]=0xFE; img[pe+2]=0xFF; img[pe+3]=0xFF
    img[pe+4]=0x0E; img[pe+5]=0xFE; img[pe+6]=0xFF; img[pe+7]=0xFF
    struct.pack_into('<I', img, pe+8,  HIDDEN)
    struct.pack_into('<I', img, pe+12, TOT16)
    img[510]=0x55; img[511]=0xAA

    # --- VBR (boot16.bin) at partition start ---
    vbr = open(os.path.join(ROOT,'bin','boot16.bin'),'rb').read()
    assert len(vbr)==512, f"boot16.bin 应为 512，实际 {len(vbr)}"
    img[HIDDEN*BPS : HIDDEN*BPS+512] = vbr

    # --- file list ---
    files = [('LOADR','SYS'),('LPYOS','SYS'),('LPYCMD','COM')]
    progdir = os.path.join(ROOT,'bin','programs')
    seen=set()
    for c in sorted(glob.glob(os.path.join(progdir,'*.COM')) + glob.glob(os.path.join(progdir,'*.com'))):
        stem = os.path.splitext(os.path.basename(c))[0]
        key = stem.upper()
        if key in seen: continue
        seen.add(key)
        files.append((stem,'COM'))

    fat = bytearray(FATSZ*BPS)
    fat[0:2] = struct.pack('<H',0xFFF8)   # media desc + EOC
    fat[2:4] = struct.pack('<H',0xFFFF)
    nextclus = 2
    root = bytearray(ROOT_SECS*BPS)
    di = 0
    for stem,ext in files:
        bindir = os.path.join(ROOT,'bin')
        p = os.path.join(bindir, f"{stem}.{ext.lower()}") if stem in ('LOADR','LPYOS','LPYCMD') \
            else os.path.join(progdir, f"{stem}.{ext}")
        # case-insensitive locate for programs
        if not os.path.exists(p):
            cand = glob.glob(os.path.join(progdir, stem+'.[cC][oO][mM]'))
            if cand: p=cand[0]
        data = open(p,'rb').read()
        nsec = (len(data)+BPS-1)//BPS
        nclus = (nsec + SPC-1)//SPC
        if nclus < 1: nclus=1
        startclus = nextclus
        for k in range(nclus):
            c = startclus+k
            val = 0xFFFF if k==nclus-1 else c+1
            struct.pack_into('<H', fat, c*2, val)
        # root entry
        e = bytearray(32)
        e[0:11] = name11(stem,ext)
        e[11]=0x20
        struct.pack_into('<H', e, 26, startclus)
        struct.pack_into('<I', e, 28, len(data))
        root[di*32:di*32+32]=e
        # data
        doff = (HIDDEN + DATA_OFF + (startclus-2)*SPC)*BPS
        img[doff:doff+len(data)] = data
        nextclus += nclus
        di += 1

    # write FAT1 + FAT2
    for f in range(NFATS):
        off = (HIDDEN + RSVD + f*FATSZ)*BPS
        img[off:off+len(fat)] = fat
    # write root dir
    img[(HIDDEN+ROOT_OFF)*BPS:(HIDDEN+ROOT_OFF)*BPS+len(root)] = root

    out = os.path.join(ROOT,'bin','LPY-DOS-HD.img')
    open(out,'wb').write(img)
    print(f"OK -> {out}  {len(img)} bytes")
    print(f"files: {len(files)}  used_clusters: {nextclus-2}  data_off_vol={DATA_OFF}")

if __name__=='__main__':
    build_fat16()
