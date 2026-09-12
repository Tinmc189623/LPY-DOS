# ============================================================================
#  LPY-DOS SDK 构建脚本（兼容 Windows PowerShell 5.1 与 PowerShell 7+）
#  用 FASM 编译 sdk/examples 下的所有第三方示例为 .COM
#
#  用法：
#    PowerShell 5.1 : powershell -ExecutionPolicy Bypass -File sdk/build.ps1 [文件名|all]
#    PowerShell 7+  : pwsh -File sdk/build.ps1 [文件名|all]
#    默认 all：编译 examples 下所有 .asm
#
#  Copyright (C) 2026 Nexsteaduser
#  Licensed under GPL v3 or later.
# ============================================================================

$ErrorActionPreference = 'Stop'

# 自动定位 FASM：环境变量 LPYDOS_FASM -> PATH -> 常见安装路径
$Fasm = $null
if ($env:LPYDOS_FASM -and (Test-Path $env:LPYDOS_FASM)) { $Fasm = $env:LPYDOS_FASM }
if (-not $Fasm) {
    $hit = Get-Command 'fasm' -ErrorAction SilentlyContinue
    if ($hit) { $Fasm = $hit.Source }
}
if (-not $Fasm) {
    foreach ($c in @('D:\fasm\FASM.EXE','C:\fasm\FASM.EXE')) {
        if (Test-Path $c) { $Fasm = $c; break }
    }
}
if (-not $Fasm) {
    $host.UI.WriteErrorLine('未找到 FASM 汇编器。')
    $host.UI.WriteErrorLine('请从 https://flatassembler.net/ 下载安装，或用环境变量 LPYDOS_FASM 指定其路径后重试。')
    exit 1
}

$ExDir     = Join-Path $PSScriptRoot 'examples'

function Build-One([string]$src) {
    $out = [IO.Path]::ChangeExtension($src, '.COM')
    Write-Host "  FASM  $src -> $(Split-Path $out -Leaf)"
    & $Fasm $src $out
    if ($LASTEXITCODE -ne 0) { throw "FASM 编译失败: $src" }
}

Write-Host '== LPY-DOS SDK 示例构建 =============================='

$targets = if ($args.Count -gt 0) { $args } else { 'all' }

if ($targets -eq 'all' -or $targets -contains 'all') {
    $files = Get-ChildItem -Path $ExDir -Filter '*.asm'
    foreach ($f in $files) { Build-One $f.FullName }
} else {
    foreach ($t in $targets) {
        $path = Join-Path $ExDir ($t + '.asm')
        if (-not (Test-Path $path)) { throw "未找到示例: $t" }
        Build-One $path
    }
}

Write-Host '== 完成。将生成的 .COM 放入系统镜像即可在 LPYCMD 中运行。=='