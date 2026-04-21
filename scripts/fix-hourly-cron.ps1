# 修复 HourlyPriceCollector - 使用合法的最大持续时间
$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"

# 删除旧任务（如果存在）
Unregister-ScheduledTask -TaskName 'HourlyPriceCollector' -Confirm:$false -ErrorAction SilentlyContinue

# 创建新任务 - 每小时:05分执行，持续100年
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$RepoRoot\scripts\hourly-price-collector.ps1`""

# 使用100年持续时间（合法范围最大值约P99999DT23H59M59S）
$hundredYears = New-TimeSpan -Days (365 * 100)
$trigger = New-ScheduledTaskTrigger -Once -At "00:05" -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration $hundredYears

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName 'HourlyPriceCollector' -Action $action -Trigger $trigger -Settings $settings -Description "每小时采集BTC/ETH/SOL/黄金/原油价格快照" | Out-Null

# 验证
$info = Get-ScheduledTaskInfo -TaskName 'HourlyPriceCollector'
Write-Output "=== HourlyPriceCollector 修复后状态 ==="
Write-Output "LastRunTime: $($info.LastRunTime)"
Write-Output "NextRunTime: $($info.NextRunTime)"
Write-Output "修复完成"
