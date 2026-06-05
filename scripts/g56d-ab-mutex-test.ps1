# G-56D A/B mutex reproduce test
# Instance A: launch first, check 5/5 + exit 0
# Instance B: launch 5sec later, expect SKIP

$ErrorActionPreference = "Continue"
$Workspace = "C:\Users\Administrator\clawd\agents\workspace-gid"
$script = Join-Path $Workspace "scripts\cron-watchdog-v3-30min.ps1"
$instance = $args[0]
$sleepSec = [int]$args[1]

if ($sleepSec -gt 0) {
    Start-Sleep -Seconds $sleepSec
}

Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Instance $instance starting (after ${sleepSec}s sleep)..." -ForegroundColor Cyan

# Use Quick to avoid auto-push hang, but keep mutex logic intact
$output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -Quick 2>&1
$exit = $LASTEXITCODE

Write-Host "=== Instance $instance output ===" -ForegroundColor Yellow
$output | ForEach-Object { Write-Host "  $_" }
Write-Host "=== Instance $instance exit code: $exit ===" -ForegroundColor $(if($exit -eq 0){"Green"}else{"Red"})

# Log result
$logFile = Join-Path $Workspace "data\system\g56d-mutex-ab-test.log"
$entry = @{
    ts = (Get-Date -Format "o")
    instance = $instance
    sleep_sec = $sleepSec
    exit_code = $exit
    output = ($output -join "`n")
} | ConvertTo-Json -Compress -Depth 4
Add-Content -Path $logFile -Value $entry
