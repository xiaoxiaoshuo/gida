# register-hourly-task.ps1 - 注册每小时价格采集定时任务
$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"

Unregister-ScheduledTask -TaskName 'HourlyPriceCollector' -Confirm:$false -ErrorAction SilentlyContinue

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -NoLogo -Command `"Set-Location '$RepoRoot'; & '.\\scripts\\hourly-price-collector.ps1'`""

$trigger = New-ScheduledTaskTrigger -Once -At '00:05' -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 365)

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName 'HourlyPriceCollector' -Action $action -Trigger $trigger -Settings $settings -Description '每小时采集BTC/ETH/SOL/黄金/原油价格快照' | Out-Null

Write-Host "Task registered"
$info = Get-ScheduledTaskInfo -TaskName 'HourlyPriceCollector'
Write-Host "LastRunTime: $($info.LastRunTime)"
Write-Host "NextRunTime: $($info.NextRunTime)"
Write-Host "State: $($info.State)"
