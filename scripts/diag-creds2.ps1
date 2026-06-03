# Credential discovery v2 - 2026-06-04 02:28
Write-Host "=== cmdkey /list (Windows Credential Manager) ==="
cmdkey /list 2>&1 | Select-String -Pattern "github" -CaseSensitive:$false -Context 2,2

Write-Host ""
Write-Host "=== Try git credential fill (corrected) ==="
$proto = "protocol=https"
$gh = "host=github.com"
$result = @($proto, $gh) | git credential fill 2>&1
$result | ForEach-Object { Write-Host "  $_" }
