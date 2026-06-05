# Update task to use wrapper
$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\cron-watchdog-v3-wrapper.ps1"' `
    -WorkingDirectory 'C:\Users\Administrator\clawd\agents\workspace-gid'

Write-Host "New action:" -ForegroundColor Cyan
$action | Format-List

try {
    Set-ScheduledTask -TaskName 'CronWatchdogV3_30min' -Action $action -ErrorAction Stop
    Write-Host "Set-ScheduledTask OK" -ForegroundColor Green
} catch {
    Write-Host "Set-ScheduledTask FAILED: $_" -ForegroundColor Red
    exit 1
}

# Verify
Get-ScheduledTask -TaskName 'CronWatchdogV3_30min' | Select-Object TaskName, State, @{n='Action';e={$_.Actions.Arguments}} | Format-List
