# ============================================================================
#  LPY-DOS 构建脚本（PowerShell 7+）
#  1. 用 FASM 编译 boot / kernel / shell
#  2. 编译 programs/ 下全部外部 .COM 程序
#  3. 生成 FAT12 1.44MB 软盘镜像 LPY-DOS.img（内核 + shell + 所有程序）
#  4. （可选）启动 QEMU 运行
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
    Write-Host "  FASM  $src"
    & $Fasm $src $out
    if ($LASTEXITCODE -ne 0) { throw "FASM 编译失败: $src" }
}

function Write-Fat12([byte[]]$fat, [int]$n, [int]$val) {
    $off = $n + [math]::Floor($n / 2)
    if (($n -band 1) -eq 0) {
        $fat[$off]    = $val -band 0xFF
        $fat[$off+1]  = ($fat[$off+1] -band 0xF0) -bor (($val -shr 8) -band 0x0F)
    } else {
        $fat[$off]    = ($fat[$off] -band 0x0F) -bor (($val -band 0x0F) -shl 4)
        $fat[$off+1]  = ($val -shr 4) -band 0xFF
    }
}

function New-DirEntry([string]$name11, [int]$attr, [int]$cluster, [int]$size) {
    $e = New-Object byte[] 32
    for ($i = 0; $i -lt 11; $i++) {
        if ($i -lt $name11.Length) { $e[$i] = [byte][char]$name11[$i] } else { $e[$i] = 0x20 }
    }
    $e[11] = $attr
    $e[26] = $cluster -band 0xFF
    $e[27] = ($cluster -shr 8) -band 0xFF
    $e[28] = $size -band 0xFF
    $e[29] = ($size -shr 8) -band 0xFF
    $e[30] = ($size -shr 16) -band 0xFF
    $e[31] = ($size -shr 24) -band 0xFF
    return $e
}

# 构造成 8.3 目录名（11 字节短名）
function Name11([string]$stem, [string]$ext) {
    $s = $stem.ToUpper()
    if ($s.Length -gt 8) { $s = $s.Substring(0, 8) }
    $s = $s.PadRight(8)
    $e = $ext.ToUpper().PadRight(3)
    return ($s + $e)
}

Write-Host '== LPY-DOS 构建 =========================================='

# ---- 1. 编译系统文件 ----
Write-Host '[1/3] 编译引导扇区'
Invoke-Fasm 'boot\boot.asm' 'boot\boot.bin'

Write-Host '[2/3] 编译内核 LPYOS.SYS'
Invoke-Fasm 'kernel\kernel.asm' 'LPYOS.SYS'

Write-Host '[3/3] 编译命令解释器 LPYCMD.COM'
Invoke-Fasm 'shell\shell.asm' 'LPYCMD.COM'

# ---- 1.5 编译全部外部程序 ----
Write-Host '[*]   编译 programs/*.asm（外部 .COM 程序）'
$programComs = @()
foreach ($src in (Get-ChildItem "$PSScriptRoot\programs\*.asm" | Sort-Object Name)) {
    $base = [IO.Path]::GetFileNameWithoutExtension($src.Name)
    $out  = "$PSScriptRoot\programs\$base.COM"
    Invoke-Fasm $src.FullName $out
    $programComs += $out
}
Write-Host "  共编译 $($programComs.Count) 个外部程序"

# ---- 2. 构造镜像 ----
Write-Host '== 生成 FAT12 镜像 ======================================='

$boot   = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'boot\boot.bin'))
$kernel = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'LPYOS.SYS'))
$shell  = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'LPYCMD.COM'))

if ($boot.Length -gt $BytsPerSec) { throw "boot.bin 超过 512 字节" }
if ($kernel.Length -gt 32768)     { throw "LPYOS.SYS 超过 32KB（引导扇区无法加载）" }

# 文件清单：内核 + shell + 所有程序
$items = @()
$items += ,@{ name = Name11 'LPYOS' 'SYS'; data = $kernel }
$items += ,@{ name = Name11 'LPYCMD' 'COM'; data = $shell }
foreach ($p in $programComs) {
    $b   = [IO.Path]::GetFileNameWithoutExtension($p)
    $d   = [IO.File]::ReadAllBytes($p)
    $items += ,@{ name = Name11 $b 'COM'; data = $d }
}

# 镜像缓冲区
$img = New-Object byte[] ($BytsPerSec * $TotSec16)

# ---- 引导扇区 ----
[Array]::Copy($boot, 0, $img, 0, $boot.Length)

# ---- FAT 表（FAT1 + FAT2）----
$fat = New-Object byte[] ($BytsPerSec * $FatSz16)
# 簇 0/1 保留项
$fat[0] = 0xF0
$fat[1] = 0xFF
$fat[2] = 0xFF

# 逐文件分配簇链、写根目录、写数据
$rootStartByte = $RootStart * $BytsPerSec
$nextClu       = 2
$dataPos       = 0        # 相对 DataStart 的簇偏移
$dirIdx        = 0
foreach ($it in $items) {
    $n = [math]::Ceiling($it.data.Length / $BytsPerSec)
    if ($n -lt 1) { $n = 1 }
    # FAT 链
    for ($k = 0; $k -lt $n; $k++) {
        $c = $nextClu + $k
        $v = if ($k -eq $n - 1) { 0xFFF } else { $c + 1 }
        Write-Fat12 $fat $c $v
    }
    # 根目录项
    $e = New-DirEntry $it.name 0x20 $nextClu $it.data.Length
    [Array]::Copy($e, 0, $img, $rootStartByte + $dirIdx * 32, 32)
    # 数据区
    [Array]::Copy($it.data, 0, $img, ($DataStart + $dataPos) * $BytsPerSec, $it.data.Length)
    $dataPos += $n
    $nextClu += $n
    $dirIdx++
    if ($dirIdx -ge $RootEntCnt) { throw '根目录已满' }
}

# 两份 FAT 写入镜像
for ($f = 0; $f -lt $NumFATs; $f++) {
    [Array]::Copy($fat, 0, $img, ($RsvdSecCnt + $f * $FatSz16) * $BytsPerSec, $fat.Length)
}

# ---- 写出镜像 ----
$imgPath = Join-Path $PSScriptRoot 'LPY-DOS.img'
# 若旧的 .img 被其它进程占用，先改名腾出路径再写入；随后清理临时备份
if ([IO.File]::Exists($imgPath)) {
    try { [IO.File]::Move($imgPath, ($imgPath + '.bak')) }
    catch {
        try { Remove-Item $imgPath -Force -ErrorAction Stop }
        catch { throw "无法写入镜像（文件被占用）: $imgPath" }
    }
}
[IO.File]::WriteAllBytes($imgPath, $img)
if ([IO.File]::Exists($imgPath + '.bak')) { Remove-Item ($imgPath + '.bak') -Force -ErrorAction SilentlyContinue }
Write-Host "  镜像已生成: $imgPath ($($img.Length) 字节)"
Write-Host "  共写入 $($items.Count) 个文件，占用 $($nextClu - 2) 簇"

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