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
# Drop a BOM (or its mis-decoded bytes) that a caller's pipe may have put in front.
$at = $header.IndexOf('Authorization:')
if ($at -gt 0) { $header = $header.Substring($at) }
$wav = $Body -replace '\.json$', '.wav'
# Piping the header into curl's -H @- from PowerShell 5.1 sends it malformed (Fish then
# answers 401), so hand curl a header file with no line ending, deleted straight after.
$headerFile = $Body -replace '\.json$', '.hdr'

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

  [IO.File]::WriteAllText($headerFile, $header)
  try {
    $code = & curl.exe -s --max-time 60 -H "@$headerFile" -A $Tag `
      -H 'Content-Type: application/json' -H "model: $Model" `
      --data-binary "@$Body" -o $wav -w '%{http_code}' $Url
  } finally {
    try { [IO.File]::Delete($headerFile) } catch { }
  }
  if ("$code" -ne '200') {
    if ("$code" -eq '000' -or "$code" -eq '') { [Console]::Error.WriteLine('claudespeak: Fish text-to-speech: no response (network?)') }
    else { [Console]::Error.WriteLine("returned error: $code") }
    exit 1
  }
  # A newer reply took over while this one was downloading.
  if ((Get-Content -LiteralPath $CurrentFile -Raw) -ne $Tag) { exit 0 }

  # Fish streams its WAV, so the RIFF and data length fields are placeholders (~4 GB).
  # SoundPlayer then plays nothing and returns at once. Write the real lengths in.
  $bytes = [IO.File]::ReadAllBytes($wav)
  $dataAt = -1
  for ($i = 12; $i -le $bytes.Length - 8; $i++) {
    if ($bytes[$i] -eq 0x64 -and $bytes[$i+1] -eq 0x61 -and $bytes[$i+2] -eq 0x74 -and $bytes[$i+3] -eq 0x61) { $dataAt = $i; break }
  }
  if ($bytes.Length -ge 44 -and $dataAt -gt 0) {
    [BitConverter]::GetBytes([uint32]($bytes.Length - 8)).CopyTo($bytes, 4)
    [BitConverter]::GetBytes([uint32]($bytes.Length - $dataAt - 8)).CopyTo($bytes, $dataAt + 4)
    [IO.File]::WriteAllBytes($wav, $bytes)
  }

  $player = New-Object System.Media.SoundPlayer $wav
  $player.PlaySync()
} catch {
  [Console]::Error.WriteLine("claudespeak: $($_.Exception.Message)")
  exit 1
} finally {
  try { [IO.File]::Delete($wav) } catch { }
}
