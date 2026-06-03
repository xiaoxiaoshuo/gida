# Credential discovery v3 - 2026-06-04 02:28
Write-Host "=== git credential fill ==="
$input = "protocol=https`nhost=github.com`n"
$tmpFile = New-TemporaryFile
Set-Content -Path $tmpFile.FullName -Value $input -NoNewline
$result = & git credential fill < $tmpFile.FullName 2>&1
$result | ForEach-Object { Write-Host "  $_" }
Remove-Item $tmpFile.FullName
