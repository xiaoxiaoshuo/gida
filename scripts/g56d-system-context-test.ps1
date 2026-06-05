# G-56D system-context timing test
# Run v3 script as SYSTEM (via scheduled task that completes in <10s)
# Then capture timing breakdown
$ErrorActionPreference = "Continue"
$Workspace = "C:\Users\Administrator\clawd\agents\workspace-gid"
$script = Join-Path $Workspace "scripts\cron-watchdog-v3-30min.ps1"
$logFile = Join-Path $Workspace "data\system\g56d-system-context-test.log"
"" | Set-Content $logFile

Write-Host "=== Direct test (no SYSTEM) ===" -ForegroundColor Cyan
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$output = & powershell -ExecutionPolicy Bypass -File $script -Quick 2>&1
$sw.Stop()
Write-Host "  Elapsed: $($sw.ElapsedMilliseconds)ms" -ForegroundColor Green
$output | Select-Object -First 3 | ForEach-Object { Write-Host "  $_" }

Write-Host ""
Write-Host "=== Now testing the Get-ScheduledTask warn call ===" -ForegroundColor Cyan
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $prevInfo = Get-ScheduledTask -TaskName 'CronWatchdogV3_30min' -ErrorAction SilentlyContinue | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue
    Write-Host "  Get-ScheduledTask succeeded: LastTaskResult=$($prevInfo.LastTaskResult)" -ForegroundColor Green
} catch {
    Write-Host "  Get-ScheduledTask FAILED: $_" -ForegroundColor Red
}
$sw.Stop()
Write-Host "  Elapsed: $($sw.ElapsedMilliseconds)ms" -ForegroundColor Yellow
