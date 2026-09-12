# ============================================================================
#  tests/qemu.ps1 — 无头 QEMU 验证辅助（LPY-DOS 引导链测试）
#  用法：. .\tests\qemu.ps1
#    Start-LpyQemu -Image <img> [-Hd]   # 启动（-Hd 走 -hda/-boot c）
#    Send-Monitor -Cmd 'screendump C:/.../x.ppm'
#    Convert-Ppm -PpmPath x.ppm -PngPath x.png
#    Stop-LpyQemu
#
#  Copyright (C) 2026 Nexsteaduser
#  This program is free software under the GNU GPL v3 or later.
# ============================================================================
$script:LpyQemuProc = $null
$script:LpyMonitorPort = 0

function Find-LpyQemu {
    $hit = Get-Command qemu-system-i386 -ErrorAction SilentlyContinue
    if ($hit) { return $hit.Source }
    foreach ($c in @('C:\Program Files\qemu\qemu-system-i386.exe', 'D:\qemu\qemu-system-i386.exe')) {
        if (Test-Path $c) { return $c }
    }
    throw '未找到 qemu-system-i386'
}

function Start-LpyQemu {
    param([string]$Image, [switch]$Hd)
    Get-Process qemu-system-i386 -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 500
    $qemu = Find-LpyQemu
    $script:LpyMonitorPort = Get-Random -Minimum 20000 -Maximum 30000
    $drive = if ($Hd) { 'disk' } else { 'floppy' }
    $boot  = if ($Hd) { '-boot','c' } else { '-boot','a' }
    $args  = @('-drive',"file=$Image,format=raw,index=0,media=$drive") + $boot + @('-display','none','-monitor',"telnet:127.0.0.1:$($script:LpyMonitorPort),server,nowait")
    $script:LpyQemuProc = Start-Process -FilePath $qemu -ArgumentList $args -PassThru
    Start-Sleep -Seconds 2
    if ($script:LpyQemuProc.HasExited) { throw "QEMU 启动即退出（端口 $script:LpyMonitorPort 可能被占用）" }
    return $script:LpyQemuProc
}

function Send-Monitor {
    param([string]$Cmd)
    $c = [Net.Sockets.TcpClient]::new('127.0.0.1', $script:LpyMonitorPort)
    $s = $c.GetStream()
    $b = New-Object byte[] 8192
    Start-Sleep -Milliseconds 300
    while ($s.DataAvailable) { [void]$s.Read($b, 0, $b.Length) }   # Drain 回显
    $w = [Text.Encoding]::ASCII.GetBytes($Cmd + "`n")
    $s.Write($w, 0, $w.Length)
    Start-Sleep -Milliseconds 600
    $out = ''
    while ($s.DataAvailable) { $n = $s.Read($b, 0, $b.Length); $out += [Text.Encoding]::ASCII.GetString($b, 0, $n) }
    $c.Close()
    return $out
}

function Convert-Ppm {
    param([string]$PpmPath, [string]$PngPath)
    Add-Type -AssemblyName System.Drawing
    $b = [IO.File]::ReadAllBytes($PpmPath)
    if ($b[0] -ne 0x50 -or $b[1] -ne 0x36) { throw "不是 P6 PPM: $PpmPath" }
    $pos = 2; $vals = @()
    while ($vals.Count -lt 3) {
        while ($b[$pos] -le 32) { $pos++ }
        $v = 0
        while ($b[$pos] -ge 48 -and $b[$pos] -le 57) { $v = $v * 10 + ($b[$pos] - 48); $pos++ }
        $vals += $v; $pos++
    }
    $w = $vals[0]; $h = $vals[1]
    $bmp = [System.Drawing.Bitmap]::new($w, $h)
    $rect = [System.Drawing.Rectangle]::new(0, 0, $w, $h)
    $bd = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $px = New-Object byte[] ($bd.Stride * $h)
    $src = $pos
    for ($y = 0; $y -lt $h; $y++) {
        $o = $y * $bd.Stride
        for ($x = 0; $x -lt $w; $x++) {
            $px[$o] = $b[$src + 2]; $px[$o + 1] = $b[$src + 1]; $px[$o + 2] = $b[$src]
            $o += 3; $src += 3
        }
    }
    [System.Runtime.InteropServices.Marshal]::Copy($px, 0, $bd.Scan0, $px.Length)
    $bmp.UnlockBits($bd)
    $bmp.Save($PngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

function Stop-LpyQemu {
    if ($script:LpyQemuProc -and -not $script:LpyQemuProc.HasExited) {
        $script:LpyQemuProc.Kill()
    }
    $script:LpyQemuProc = $null
}
