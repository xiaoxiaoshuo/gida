$file = "C:\Users\Administrator\clawd\agents\workspace-gid\.last_push_time"
$content = Get-Content $file -Raw
Write-Host "Raw: '$content'"
Write-Host "Trim: '$($content.Trim())'"
$dt = [DateTime]::Parse($content.Trim())
Write-Host "Parsed: $dt"
$now = Get-Date
$elapsed = ($now - $dt).TotalMinutes
Write-Host "Elapsed: $elapsed"