$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\cron-watchdog-v3-30min.ps1"' `
    -WorkingDirectory 'C:\Users\Administrator\clawd\agents\workspace-gid'

Write-Host "Action:" -ForegroundColor Cyan
$action | Format-List

# Try to update the task
try {
    Set-ScheduledTask -TaskName 'CronWatchdogV3_30min' -Action $action -ErrorAction Stop
    Write-Host "Set-ScheduledTask OK" -ForegroundColor Green
} catch {
    Write-Host "Set-ScheduledTask FAILED: $_" -ForegroundColor Red
    # Try unregister + register
    Unregister-ScheduledTask -TaskName 'CronWatchdogV3_30min' -Confirm:$false -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    # Re-register with full settings
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $triggers = New-ScheduledTaskTrigger -Once -At '2026-06-05T11:45:00'
    $triggers.Repetition = (New-ScheduledTaskTrigger -Once -At '2026-06-05T11:45:00' -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 365)).Repetition
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -DontStopOnIdleEnd `
        -StartWhenAvailable `
        -MultipleInstances IgnoreNew `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

    Register-ScheduledTask `
        -TaskName 'CronWatchdogV3_30min' `
        -Action $action `
        -Principal $principal `
        -Trigger $triggers `
        -Settings $settings `
        -Description 'cron-watchdog-v3 30-min interval (G-56D 11:44 patch)' `
        -Force | Out-Null
    Write-Host "Re-registered" -ForegroundColor Green
}

# Verify
Write-Host ""
Write-Host "=== Updated task ===" -ForegroundColor Cyan
Get-ScheduledTask -TaskName 'CronWatchdogV3_30min' | Select-Object TaskName, State, @{n='Action';e={$_.Actions.Arguments}} | Format-List
