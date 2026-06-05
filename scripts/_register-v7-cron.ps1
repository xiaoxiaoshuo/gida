# Register gh-trending-v7 as Task Scheduler job
# Hourly at minute 30 (offset from existing :00 jobs)
# 5-minute timeout

$taskName = 'gh-trending-v7-hourly'
$scriptPath = 'C:\Users\Administrator\clawd\agents\workspace-gid\scripts\gh-trending-v7-search-api.ps1'
$logPath = 'C:\Users\Administrator\clawd\agents\workspace-gid\data\system\gh-trending-v7-cron.log'

# Action: powershell -File ...
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" >> `"$logPath`" 2>&1"

# Trigger: hourly, offset 30 min (so it runs at 00:30, 01:30, ...)
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 3650)
$trigger.StartBoundary = (Get-Date -Format 'yyyy-MM-dd') + 'T00:30:00'

# Principal: current user, run whether logged in or not
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType S4U -RunLevel Highest

# Settings
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

# 删除已存在 (幂等)
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "[INFO] Removed existing task: $taskName"
}

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "GitHub Trending v7 hourly collector (Search API realtime, 30min offset, 5min timeout)"

# Verify
$task = Get-ScheduledTask -TaskName $taskName
$info = Get-ScheduledTaskInfo -TaskName $taskName
Write-Host ('[REGISTERED] ' + $taskName + ' state=' + $task.State)
Write-Host ('[TRIGGER] next run: ' + $info.NextRunTime)
Write-Host ('[LOG] ' + $logPath)
