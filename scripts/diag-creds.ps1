# Credential discovery - 2026-06-04 02:27
Write-Host "=== ENV CHECK ==="
Write-Host "GITHUB_TOKEN: $([string]::IsNullOrEmpty($env:GITHUB_TOKEN))"
Write-Host "GH_TOKEN: $([string]::IsNullOrEmpty($env:GH_TOKEN))"
Write-Host "GIDA_TOKEN: $([string]::IsNullOrEmpty($env:GIDA_TOKEN))"

Write-Host "=== .git-credentials ==="
$gc = "$HOME\.git-credentials"
if (Test-Path $gc) { Get-Content $gc | Select-Object -First 3 } else { Write-Host "<NOT FOUND>" }

Write-Host "=== .netrc ==="
$nr = "$HOME\_netrc"
if (Test-Path $nr) { Get-Content $nr | Select-Object -First 3 } else { Write-Host "<NOT FOUND>" }

Write-Host "=== Git Credential Helper ==="
git config --global --get credential.helper
git config --get credential.helper

Write-Host "=== Try git credential fill ==="
$proto = "protocol=https"
$host = "host=github.com"
$out = $proto, $host | git credential fill 2>&1
$out | ForEach-Object { Write-Host $_ }
