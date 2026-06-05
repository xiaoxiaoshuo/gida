# G-56D 11:47: complete uninstall + reinstall of the task
# This breaks the OS-level cached state that holds the abandoned mutex

Write-Host "=== Step 1: Unregister existing task ===" -ForegroundColor Cyan
try {
    Unregister-ScheduledTask -TaskName 'CronWatchdogV3_30min' -Confirm:$false
    Write-Host "Unregistered" -ForegroundColor Green
} catch {
    Write-Host "Unregister FAILED: $_" -ForegroundColor Red
}

Start-Sleep -Seconds 3

Write-Host ""
Write-Host "=== Step 2: Re-register fresh task ===" -ForegroundColor Cyan

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\cron-watchdog-v3-wrapper.ps1"' `
    -WorkingDirectory 'C:\Users\Administrator\clawd\agents\workspace-gid'

$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

$trigger = New-ScheduledTaskTrigger -Once -At '2026-06-05T11:50:00'
$trigger.Repetition = (New-ScheduledTaskTrigger -Once -At '2026-06-05T11:50:00' `
    -RepetitionInterval (New-TimeSpan -Minutes 30) `
    -RepetitionDuration (New-TimeSpan -Days 365)).Repetition

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -DontStopOnIdleEnd `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

try {
    Register-ScheduledTask `
        -TaskName 'CronWatchdogV3_30min' `
        -Action $action `
        -Principal $principal `
        -Trigger $trigger `
        -Settings $settings `
        -Description 'cron-watchdog-v3 30-min interval (G-56D 11:47 fresh install with wrapper)' `
        -Force | Out-Null
    Write-Host "Re-registered" -ForegroundColor Green
} catch {
    Write-Host "Register FAILED: $_" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "=== Step 3: Verify ===" -ForegroundColor Cyan
Get-ScheduledTask -TaskName 'CronWatchdogV3_30min' | Select-Object TaskName, State, @{n='Action';e={$_.Actions.Arguments}} | Format-List
Get-ScheduledTask -TaskName 'CronWatchdogV3_30min' | Get-ScheduledTaskInfo | Format-List TaskName, LastRunTime, LastTaskResult, NextRunTime
