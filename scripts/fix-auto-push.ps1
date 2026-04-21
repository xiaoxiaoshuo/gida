$content = Get-Content 'C:\Users\Administrator\clawd\agents\workspace-gid\scripts\auto-push.ps1' -Raw
$fixed = $content -replace 'ParseExact\(\$LastPushTime, "yyyy-MM-dd HH:mm", \$null\)', 'Parse($LastPushTime.Trim())'
$fixed | Out-File 'C:\Users\Administrator\clawd\agents\workspace-gid\scripts\auto-push.ps1' -NoNewline -Encoding UTF8
Write-Host "[OK] Fixed"