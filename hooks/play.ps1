# claudespeak (Windows): fetch a Fish TTS clip as WAV and play it. One voice at a time.
# Called as: powershell -File play.ps1 <tag> <bodyJson> <currentFile> <model> <url>
# The Authorization header arrives on stdin (so the key never appears in a command line).
param(
  [Parameter(Mandatory)][string]$Tag,
  [Parameter(Mandatory)][string]$Body,
  [Parameter(Mandatory)][string]$CurrentFile,
  [Parameter(Mandatory)][string]$Model,
  [Parameter(Mandatory)][string]$Url
)
$ErrorActionPreference = 'Stop'
$header = [Console]::In.ReadToEnd().Trim()
$wav = $Body -replace '\.json$', '.wav'

function Stop-OtherSpeech {
  # Any other claudespeak player (and its curl child), never this process.
  Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -match 'play\.ps1.* claudespeak-\d+' } |
    ForEach-Object { & taskkill.exe /F /T /PID $_.ProcessId *> $null }
}

try {
  Set-Content -LiteralPath $CurrentFile -Value $Tag -NoNewline -Encoding ascii
  Stop-OtherSpeech
  if ((Get-Content -LiteralPath $CurrentFile -Raw) -ne $Tag) { exit 0 }

  $code = $header | & curl.exe -s --max-time 60 -H '@-' -A $Tag `
    -H 'Content-Type: application/json' -H "model: $Model" `
    --data-binary "@$Body" -o $wav -w '%{http_code}' $Url
  if ("$code" -ne '200') {
    if ("$code" -eq '000' -or "$code" -eq '') { [Console]::Error.WriteLine('claudespeak: Fish text-to-speech: no response (network?)') }
    else { [Console]::Error.WriteLine("returned error: $code") }
    exit 1
  }
  # A newer reply took over while this one was downloading.
  if ((Get-Content -LiteralPath $CurrentFile -Raw) -ne $Tag) { exit 0 }

  $player = New-Object System.Media.SoundPlayer $wav
  $player.PlaySync()
} catch {
  [Console]::Error.WriteLine("claudespeak: $($_.Exception.Message)")
  exit 1
} finally {
  try { [IO.File]::Delete($wav) } catch { }
}
