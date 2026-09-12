param(
  [int]$Port = 55555,
  [int]$SleepMs = 600
)
# Robust QEMU monitor helper: sends commands, waits, returns full decoded output.
function New-Mon {
  param([int]$P)
  $c = New-Object System.Net.Sockets.TcpClient
  $c.Connect('127.0.0.1', $P)
  $s = $c.GetStream()
  $w = New-Object System.IO.StreamWriter($s)
  $r = New-Object System.IO.StreamReader($s)
  $w.AutoFlush = $true
  Start-Sleep -Milliseconds 300
  while ($s.DataAvailable) { $null = $r.ReadLine() }
  return @{ c = $c; s = $s; w = $w; r = $r }
}
function Send-Mon {
  param($m, [string]$cmd, [int]$wait = 500)
  $m.w.WriteLine($cmd)
  Start-Sleep -Milliseconds $wait
  $out = @()
  $deadline = (Get-Date).AddMilliseconds(800)
  while (((Get-Date) -lt $deadline) -and $m.s.DataAvailable) {
    $out += $m.r.ReadLine()
  }
  # strip prompt echoes
  return ($out | Where-Object { $_ -notmatch '^\(qemu\)' -and $_.Trim() -ne '' })
}

$m = New-Mon $Port

if ($env:QCMD -eq 'regs') {
  Send-Mon $m 'info registers' 700 | Where-Object { $_ -match 'EAX|EBX|ECX|EDX|ESI|EDI|EBP|ESP|EIP|EFL|^CS|^SS|^DS|^ES|HLT' }
}
elseif ($env:QCMD -eq 'screen') {
  # dump VGA text buffer 0xB8000, 80x25, decode chars
  $lines = Send-Mon $m 'xp /2000xb 0xb8000' 1500
  $bytes = @()
  foreach ($l in $lines) {
    foreach ($mm in [regex]::Matches($l, '0x([0-9a-f]{2})')) { $bytes += [Convert]::ToByte($mm.Groups[1].Value,16) }
  }
  $sb = New-Object System.Text.StringBuilder
  for ($i = 0; $i -lt [Math]::Min(2000, $bytes.Count); $i += 2) {
    $ch = [char]$bytes[$i]
    if ($bytes[$i] -eq 0x20) { $ch = ' ' }
    elseif ($bytes[$i] -lt 32 -or $bytes[$i] -gt 126) { $ch = ' ' }
    [void]$sb.Append($ch)
  }
  $txt = $sb.ToString()
  for ($row = 0; $row -lt 25; $row++) {
    $start = $row*80
    if ($start + 80 -gt $txt.Length) { break }
    $seg = $txt.Substring($start, 80).TrimEnd()
    if ($seg.Trim().Length -gt 0) { Write-Output ("{0,2}: {1}" -f $row, $seg) }
  }
}
elseif ($env:QCMD -eq 'ring') {
  $lines = Send-Mon $m 'xp /512xb 0x10ad1' 1200
  $bytes = @()
  foreach ($l in $lines) {
    foreach ($mm in [regex]::Matches($l, '0x([0-9a-f]{2})')) { $bytes += [Convert]::ToByte($mm.Groups[1].Value,16) }
  }
  $hex = ($bytes | ForEach-Object { $_.ToString('x2') }) -join ' '
  Write-Output $hex
}
elseif ($env:QCMD -eq 'send') {
  foreach ($k in ($env:QKEYS -split ',')) { Send-Mon $m "sendkey $k" 150 | Out-Null }
  Write-Output "sent $env:QKEYS"
}

$m.c.Close()
