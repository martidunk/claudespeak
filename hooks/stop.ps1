# claudespeak (Windows): cut off speech. With a tag, only that player; with none, every session's.
param([string]$Tag = '')
$pattern = if ($Tag) { 'play\.ps1.* ' + [regex]::Escape($Tag) } else { 'play\.ps1.* claudespeak-\d+' }
$players = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
  Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -match $pattern })
$players | ForEach-Object { & taskkill.exe /F /T /PID $_.ProcessId *> $null }

# A player may have handed its clip to PIC (the optional tray face); killing the player doesn't
# silence PIC, so tell it too. With a tag, only when that player was still alive: otherwise the
# voice PIC is using may belong to another session.
if (-not $Tag -or $players.Count -gt 0) {
  $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', 'PIC.Speak.v1', [System.IO.Pipes.PipeDirection]::InOut)
  try {
    $pipe.Connect(300)
    $writer = New-Object System.IO.StreamWriter($pipe, (New-Object System.Text.UTF8Encoding($false)))
    $writer.AutoFlush = $true
    $writer.WriteLine('stop')
    [void](New-Object System.IO.StreamReader($pipe)).ReadLine()
  } catch { } finally { $pipe.Dispose() }
}
exit 0
