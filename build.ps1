# ============================================================================
#  LPY-DOS 构建脚本（PowerShell 7+）
#  1. 用 FASM 编译 boot / kernel / shell
#  2. 生成 FAT12 1.44MB 软盘镜像 LPY-DOS.img
#  3. （可选）启动 QEMU 运行
#
#  用法：pwsh build.ps1 [run]
#    run 参数表示构建后启动 QEMU
#
#  Copyright (C) 2026 Nexlyh
#  This program is free software under the GNU GPL v3 or later.
# ============================================================================

$ErrorActionPreference = 'Stop'

# 工具路径
$Fasm = 'D:\fasm\FASM.EXE'
$Qemu = 'qemu-system-i386.exe'

# 镜像几何（与 boot.asm BPB 一致）
$BytsPerSec  = 512
$SecPerClus  = 1
$RsvdSecCnt  = 1
$NumFATs     = 2
$RootEntCnt  = 224
$TotSec16    = 2880
$FatSz16     = 9
$RootStart   = $RsvdSecCnt + ($NumFATs * $FatSz16)   # 19
$RootSects   = [math]::Ceiling(($RootEntCnt * 32) / $BytsPerSec)  # 14
$DataStart   = $RootStart + $RootSects               # 33

function Invoke-Fasm([string]$src, [string]$out) {
    Write-Host "  FASM  $src -> $out"
    & $Fasm $src $out
    if ($LASTEXITCODE -ne 0) { throw "FASM 编译失败: $src" }
}

Write-Host '== LPY-DOS 构建 =========================================='

# ---- 1. 编译 ----
Write-Host '[1/3] 编译引导扇区'
Invoke-Fasm 'boot\boot.asm' 'boot\boot.bin'

Write-Host '[2/3] 编译内核 LPYOS.SYS'
Invoke-Fasm 'kernel\kernel.asm' 'LPYOS.SYS'

Write-Host '[3/3] 编译命令解释器 LPYCMD.COM'
Invoke-Fasm 'shell\shell.asm' 'LPYCMD.COM'

# ---- 2. 构造镜像 ----
Write-Host '== 生成 FAT12 镜像 LPY-DOS.img ==========================='

$boot  = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'boot\boot.bin'))
$kernel = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'LPYOS.SYS'))
$shell  = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'LPYCMD.COM'))

if ($boot.Length -gt $BytsPerSec) { throw "boot.bin 超过 512 字节" }
if ($kernel.Length -gt 32768)     { throw "LPYOS.SYS 超过 32KB（引导扇区无法加载）" }

$kSize = $kernel.Length
$sSize = $shell.Length
$kClu  = [math]::Ceiling($kSize / $BytsPerSec)   # 内核占用簇数
$sClu  = [math]::Ceiling($sSize / $BytsPerSec)   # 外壳占用簇数

# 镜像缓冲区
$img = New-Object byte[] ($BytsPerSec * $TotSec16)

# ---- 引导扇区 ----
[Array]::Copy($boot, 0, $img, 0, $boot.Length)

# ---- FAT 表（FAT1 + FAT2）----
function Write-Fat12([byte[]]$fat, [int]$n, [int]$val) {
    $off = $n + [math]::Floor($n / 2)
    if (($n -band 1) -eq 0) {
        # 偶簇：低 8 位在 fat[off]，高 4 位在 fat[off+1] 低半字节
        $fat[$off]    = $val -band 0xFF
        $fat[$off+1]  = ($fat[$off+1] -band 0xF0) -bor (($val -shr 8) -band 0x0F)
    } else {
        # 奇簇：低 4 位在 fat[off] 高半字节，高 8 位在 fat[off+1]
        $fat[$off]    = ($fat[$off] -band 0x0F) -bor (($val -band 0x0F) -shl 4)
        $fat[$off+1]  = ($val -shr 4) -band 0xFF
    }
}

$fat = New-Object byte[] ($BytsPerSec * $FatSz16)
# 簇 0/1 保留项：介质描述符 F0，结束标记
$fat[0] = 0xF0
$fat[1] = 0xFF
$fat[2] = 0xFF

# 内核簇链：2 .. 2+kClu-1
for ($i = 0; $i -lt $kClu; $i++) {
    $cur = 2 + $i
    if ($i -eq $kClu - 1) { Write-Fat12 $fat $cur 0xFFF } else { Write-Fat12 $fat $cur ($cur + 1) }
}
# 外壳簇链：2+kClu ..
$sFirst = 2 + $kClu
for ($i = 0; $i -lt $sClu; $i++) {
    $cur = $sFirst + $i
    if ($i -eq $sClu - 1) { Write-Fat12 $fat $cur 0xFFF } else { Write-Fat12 $fat $cur ($cur + 1) }
}

# 两份 FAT 写入镜像
$fatStart = $RsvdSecCnt
for ($f = 0; $f -lt $NumFATs; $f++) {
    [Array]::Copy($fat, 0, $img, ($fatStart + $f * $FatSz16) * $BytsPerSec, $fat.Length)
}

# ---- 根目录 ----
function New-DirEntry([string]$name11, [int]$attr, [int]$cluster, [int]$size) {
    $e = New-Object byte[] 32
    # 11 字节文件名（0 结尾名则空格填充）
    for ($i = 0; $i -lt 11; $i++) {
        if ($i -lt $name11.Length) { $e[$i] = [byte][char]$name11[$i] } else { $e[$i] = 0x20 }
    }
    $e[11] = $attr
    # 12-21 保留 0
    $e[26] = $cluster -band 0xFF
    $e[27] = ($cluster -shr 8) -band 0xFF
    $e[28] = $size -band 0xFF
    $e[29] = ($size -shr 8) -band 0xFF
    $e[30] = ($size -shr 16) -band 0xFF
    $e[31] = ($size -shr 24) -band 0xFF
    return $e
}

$rootStartByte = $RootStart * $BytsPerSec
# LPYOS.SYS
$e1 = New-DirEntry 'LPYOS   SYS' 0x20 2 $kSize
[Array]::Copy($e1, 0, $img, $rootStartByte, 32)
# LPYCMD.COM
$e2 = New-DirEntry 'LPYCMD  COM' 0x20 $sFirst $sSize
[Array]::Copy($e2, 0, $img, $rootStartByte + 32, 32)

# ---- 数据区 ----
$kLba = $DataStart                       # cluster 2
[Array]::Copy($kernel, 0, $img, $kLba * $BytsPerSec, $kernel.Length)
$sLba = $DataStart + $kClu               # cluster 2+kClu
[Array]::Copy($shell, 0, $img, $sLba * $BytsPerSec, $shell.Length)

# ---- 写出镜像 ----
$imgPath = Join-Path $PSScriptRoot 'LPY-DOS.img'
[IO.File]::WriteAllBytes($imgPath, $img)
Write-Host "  镜像已生成: $imgPath ($($img.Length) 字节)"
Write-Host "  LPYOS.SYS: $kSize 字节 / $kClu 簇 (起始簇 2)"
Write-Host "  LPYCMD.COM: $sSize 字节 / $sClu 簇 (起始簇 $sFirst)"

# ---- 3. 启动 QEMU ----
if ($args -contains 'run') {
    Write-Host '== 启动 QEMU ============================================'
    if (Get-Command $Qemu -ErrorAction SilentlyContinue) {
        & $Qemu -fda $imgPath -boot a -display gtk
    } else {
        Write-Host "未找到 $Qemu，请安装 QEMU 后手动运行："
        Write-Host "  $Qemu -fda $imgPath -boot a"
    }
}
