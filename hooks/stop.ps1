# claudespeak (Windows): cut off speech. With a tag, only that player; with none, every session's.
param([string]$Tag = '')
$pattern = if ($Tag) { 'play\.ps1.* ' + [regex]::Escape($Tag) } else { 'play\.ps1.* claudespeak-\d+' }
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
  Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -match $pattern } |
  ForEach-Object { & taskkill.exe /F /T /PID $_.ProcessId *> $null }
exit 0
