# ============================================================================
#  tests/mkhd.ps1 — 构造 LPY-DOS 引导链测试硬盘镜像
#  用法：pwsh tests\mkhd.ps1 -FatBits 16   # → testhd16.img
#        pwsh tests\mkhd.ps1 -FatBits 32   # → testhd32.img
#  生成：MBR(boot\MBR.BIN，分区1 活动) + FAT16/32 卷（起始 LBA 63）+
#        LOADR.SYS + LPYOS.SYS（根目录可按名查找，簇链分配）
#  卷参数与 boot\boot16.asm / boot\boot32.asm 包装内 BPB 默认值严格一致
#
#  Copyright (C) 2026 Nexsteaduser
#  This program is free software under the GNU GPL v3 or later.
# ============================================================================
param(
    [ValidateSet(16, 32)][int]$FatBits = 16,
    [string]$Out = ""
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $Out) { $Out = Join-Path $root "testhd$FatBits.img" }

# ---- 卷参数（与包装 BPB 一致） ----
$BytsPerSec = 512
$SecPerClus = if ($FatBits -eq 16) { 4 } else { 1 }
$RsvdSecCnt = if ($FatBits -eq 16) { 1 } else { 32 }
$NumFATs    = 2
$RootEntCnt = if ($FatBits -eq 16) { 512 } else { 0 }
$Media      = 0xF8
$Spt        = 63
$Heads      = 16
$PartStart  = 63
$TotSec     = if ($FatBits -eq 16) { 33280 } else { 66583 }
$FatSz      = if ($FatBits -eq 16) { 33 } else { 513 }
$RootClus   = if ($FatBits -eq 16) { 0 } else { 2 }
$RootSects  = [math]::Ceiling(($RootEntCnt * 32) / $BytsPerSec)   # 16→32, 32→0
$DataStart  = $PartStart + $RsvdSecCnt + $NumFATs * $FatSz + $RootSects

$img = New-Object byte[] (($PartStart + $TotSec) * $BytsPerSec)

# ---- MBR + 分区表第 1 项 ----
$mbr = [IO.File]::ReadAllBytes((Join-Path $root 'boot\MBR.BIN'))
if ($mbr.Length -ne 512) { throw "MBR.BIN 必须 512 字节，实际 $($mbr.Length)" }
[Array]::Copy($mbr, 0, $img, 0, 512)
$img[446] = 0x80                                                # 活动
$img[450] = if ($FatBits -eq 16) { 0x0E } else { 0x0C }         # FAT16/32 LBA 类型
[Array]::Copy([BitConverter]::GetBytes([uint32]$PartStart), 0, $img, 454, 4)
[Array]::Copy([BitConverter]::GetBytes([uint32]$TotSec),   0, $img, 458, 4)

# ---- VBR（变体 bin + BPB 补丁） ----
$vbrFile = if ($FatBits -eq 16) { 'boot\boot16.bin' } else { 'boot\boot32.bin' }
$vbr = [IO.File]::ReadAllBytes((Join-Path $root $vbrFile))
if ($vbr.Length -ne 512) { throw "$vbrFile 必须 512 字节，实际 $($vbr.Length)" }
function Set-Bpb([byte[]]$v, [int]$off, [uint32]$val, [int]$size) {
    $b = switch ($size) {
        1 { [byte[]]@([byte]$val) }
        2 { [BitConverter]::GetBytes([uint16]$val) }
        4 { [BitConverter]::GetBytes([uint32]$val) }
    }
    [Array]::Copy($b, 0, $v, $off, $size)
}
Set-Bpb $vbr 11 $BytsPerSec 2
Set-Bpb $vbr 13 $SecPerClus 1
Set-Bpb $vbr 14 $RsvdSecCnt 2
Set-Bpb $vbr 16 $NumFATs 1
Set-Bpb $vbr 17 $RootEntCnt 2
Set-Bpb $vbr 19 ($(if ($FatBits -eq 16) { $TotSec } else { 0 })) 2
Set-Bpb $vbr 21 $Media 1
Set-Bpb $vbr 22 ($(if ($FatBits -eq 16) { $FatSz } else { 0 })) 2
Set-Bpb $vbr 24 $Spt 2
Set-Bpb $vbr 26 $Heads 2
Set-Bpb $vbr 28 $PartStart 4
Set-Bpb $vbr 32 ($(if ($FatBits -eq 32) { $TotSec } else { 0 })) 4
if ($FatBits -eq 32) {
    Set-Bpb $vbr 36 $FatSz 4
    Set-Bpb $vbr 44 $RootClus 4
    Set-Bpb $vbr 48 1 2          # fsInfo
    Set-Bpb $vbr 50 6 2          # bkBootSec
}
[Array]::Copy($vbr, 0, $img, $PartStart * $BytsPerSec, 512)

# ---- FAT32：FSInfo 扇区（VBR+1）与备份 VBR（VBR+6） ----
if ($FatBits -eq 32) {
    $fsi = New-Object byte[] $BytsPerSec
    [Array]::Copy([BitConverter]::GetBytes([uint32]0x41615252), 0, $fsi, 0, 4)
    [Array]::Copy([BitConverter]::GetBytes([uint32]0x61417272), 0, $fsi, 484, 4)
    [Array]::Copy([BitConverter]::GetBytes([uint32]::MaxValue), 0, $fsi, 488, 4)
    [Array]::Copy([BitConverter]::GetBytes([uint32]::MaxValue), 0, $fsi, 492, 4)
    [Array]::Copy([byte[]](0x55,0xAA,0,0), 0, $fsi, 508, 4)
    [Array]::Copy($fsi, 0, $img, ($PartStart + 1) * $BytsPerSec, $BytsPerSec)
    [Array]::Copy($vbr, 0, $img, ($PartStart + 6) * $BytsPerSec, 512)
}

# ---- FAT ----
$fat = New-Object byte[] ($FatSz * $BytsPerSec)
function Set-Fat([byte[]]$f, [int]$n, [uint32]$val) {
    if ($FatBits -eq 16) {
        [Array]::Copy([BitConverter]::GetBytes([uint16]$val), 0, $f, $n * 2, 2)
    } else {
        [Array]::Copy([BitConverter]::GetBytes($val), 0, $f, $n * 4, 4)
    }
}
if ($FatBits -eq 16) {
    Set-Fat $fat 0 0xFFF8
    Set-Fat $fat 1 0xFFFF
} else {
    Set-Fat $fat 0 0x0FFFFFF8
    Set-Fat $fat 1 0x0FFFFFFF
    Set-Fat $fat 2 0x0FFFFFFF    # FAT32 根目录单簇
}

# ---- 文件簇链与数据 ----
function Name11([string]$stem, [string]$ext) {
    $s = $stem.ToUpper(); if ($s.Length -gt 8) { $s = $s.Substring(0, 8) }
    $s = $s.PadRight(8); $e = $ext.ToUpper().PadRight(3)
    return ($s + $e)
}
$files = @(
    @{ name = (Name11 'LOADR' 'SYS'); data = [IO.File]::ReadAllBytes((Join-Path $root 'LOADR.SYS')) },
    @{ name = (Name11 'LPYOS' 'SYS'); data = [IO.File]::ReadAllBytes((Join-Path $root 'LPYOS.SYS')) },
    @{ name = (Name11 'LPYCMD' 'COM'); data = [IO.File]::ReadAllBytes((Join-Path $root 'LPYCMD.COM')) }
)
if ($files[1].data.Length -gt 65536) { throw 'LPYOS.SYS 超过 64KB（stage2 加载上限）' }

$entries = @()
$nextClu = 3                    # FAT32 时簇 2 = 根目录
foreach ($f in $files) {
    $n = [math]::Ceiling($f.data.Length / ($BytsPerSec * $SecPerClus))
    if ($n -lt 1) { $n = 1 }
    for ($k = 0; $k -lt $n; $k++) {
        $c = $nextClu + $k
        $v = if ($k -eq $n - 1) { $(if ($FatBits -eq 16) { [uint32]0xFFFF } else { [uint32]0x0FFFFFFF }) } else { [uint32]($c + 1) }
        Set-Fat $fat $c $v
    }
    for ($k = 0; $k -lt ($n * $SecPerClus); $k++) {
        $src = $k * $BytsPerSec
        if ($src -ge $f.data.Length) { break }
        $len = [Math]::Min($BytsPerSec, $f.data.Length - $src)
        [Array]::Copy($f.data, $src, $img, ($DataStart + ($nextClu - 2) * $SecPerClus + $k) * $BytsPerSec, $len)
    }
    $entries += ,@{ name = $f.name; clu = [uint32]$nextClu; size = $f.data.Length }
    $nextClu += $n
}

# ---- 根目录 ----
function New-DirEntry([string]$name11, [int]$attr, [uint32]$clu, [int]$size) {
    $e = New-Object byte[] 32
    for ($i = 0; $i -lt 11; $i++) { $e[$i] = [byte][char]$name11[$i] }
    $e[11] = $attr
    [Array]::Copy([BitConverter]::GetBytes([uint16]($clu -band 0xFFFF)), 0, $e, 26, 2)
    [Array]::Copy([BitConverter]::GetBytes([uint16](($clu -shr 16) -band 0xFFFF)), 0, $e, 20, 2)
    [Array]::Copy([BitConverter]::GetBytes([uint32]$size), 0, $e, 28, 4)
    return $e
}
$rootOff = if ($FatBits -eq 16) {
    ($PartStart + $RsvdSecCnt + $NumFATs * $FatSz) * $BytsPerSec
} else {
    ($DataStart + ($RootClus - 2) * $SecPerClus) * $BytsPerSec
}
$idx = 0
foreach ($en in $entries) {
    [Array]::Copy((New-DirEntry $en.name 0x20 $en.clu $en.size), 0, $img, $rootOff + $idx * 32, 32)
    $idx++
}

# ---- FAT 副本落盘 + 输出 ----
for ($f = 0; $f -lt $NumFATs; $f++) {
    [Array]::Copy($fat, 0, $img, ($PartStart + $RsvdSecCnt + $f * $FatSz) * $BytsPerSec, $fat.Length)
}
[IO.File]::WriteAllBytes($Out, $img)
Write-Host "  测试硬盘镜像: $Out ($($img.Length) 字节, FAT$FatBits, 分区起始 LBA $PartStart)"
