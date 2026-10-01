# Narration WAVs from narration.json with the Windows voice (local, no network).
Add-Type -AssemblyName System.Speech
$items = Get-Content -Raw -Encoding UTF8 "$PSScriptRoot\narration.json" | ConvertFrom-Json
$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
try { $s.SelectVoice('Microsoft Zira Desktop') } catch {}
$s.Rate = 0
foreach ($it in $items) {
  $out = "$PSScriptRoot\vendor-panel-demo\assets\voice\$($it.id).wav"
  $s.SetOutputToWaveFile($out)
  $s.Speak($it.text)
  $s.SetOutputToNull()
  Write-Output "$($it.id).wav"
}
$s.Dispose()
