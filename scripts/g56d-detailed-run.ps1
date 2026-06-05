# G-56D detailed timing for each check
$ErrorActionPreference = "Continue"
$Workspace = "C:\Users\Administrator\clawd\agents\workspace-gid"
$script = Join-Path $Workspace "scripts\cron-watchdog-v3-30min.ps1"
$logFile = Join-Path $Workspace "data\system\g56d-detailed-run.log"
"" | Set-Content $logFile

# Use -Verbose if possible, but we can also wrap with manual timing
Write-Host "=== Running v3 with Quick + ExtraTiming... ===" -ForegroundColor Cyan
$sw = [System.Diagnostics.Stopwatch]::StartNew()

# Source the script with custom overrides
$scriptContent = Get-Content $script -Raw
# Inject timing
$scriptContent = $scriptContent -replace '(\$results\.hourly_price\s*=\s*Test-HourlyPrice)', '$sw1 = [System.Diagnostics.Stopwatch]::StartNew(); $r = Test-HourlyPrice; $r.elapsed_ms = $sw1.ElapsedMilliseconds; $results.hourly_price = $r'
$scriptContent = $scriptContent -replace 'Test-AINews', '@{ name=''ai_news''; ok=$true; detail=''SKIP'' }'
$scriptContent = $scriptContent -replace 'Test-GitHubTrending', '@{ name=''github_trending''; ok=$true; detail=''SKIP'' }'
$scriptContent = $scriptContent -replace 'Test-AutoPush', '@{ name=''auto_push''; ok=$true; detail=''SKIP'' }'
$scriptContent = $scriptContent -replace 'Test-GFWHealth', '@{ name=''gfw_health''; ok=$true; detail=''SKIP'' }'

# Write modified script
$modifiedPath = Join-Path $Workspace "scripts\g56d-v3-timing.ps1"
$scriptContent | Out-File -FilePath $modifiedPath -Encoding UTF8

$sw.Stop()
Write-Host "  Script prep: $($sw.ElapsedMilliseconds)ms" -ForegroundColor Yellow

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$output = & powershell -ExecutionPolicy Bypass -File $modifiedPath -Quick 2>&1
$sw.Stop()
Write-Host "  Total elapsed: $($sw.ElapsedMilliseconds)ms" -ForegroundColor Green
$output | ForEach-Object { Write-Host "  $_" }
