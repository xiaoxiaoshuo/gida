# HourlyPriceCollector - 修复循环触发器
# 使用 -Once + 足够大的 Duration 来实现无限循环
$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"

Unregister-ScheduledTask -TaskName 'HourlyPriceCollector' -Confirm:$false -ErrorAction SilentlyContinue

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$RepoRoot\scripts\hourly-price-collector.ps1`""

# 使用 -Once + 1年 Duration（Task Scheduler 最大支持 P99999DT23H59M59S）
# PowerShell New-TimeSpan 最大约 P10675199DT02H48M05.4775807S
$oneYear = New-TimeSpan -Days 365
$trigger = New-ScheduledTaskTrigger -Once -At "00:05" -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration $oneYear

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName 'HourlyPriceCollector' -Action $action -Trigger $trigger -Settings $settings -Description "每小时采集BTC/ETH/SOL/黄金/原油价格快照" | Out-Null

$info = Get-ScheduledTaskInfo -TaskName 'HourlyPriceCollector'
$task = Get-ScheduledTask -TaskName 'HourlyPriceCollector'
Write-Output "=== HourlyPriceCollector 修复后 ==="
Write-Output "LastRunTime: $($info.LastRunTime)"
Write-Output "NextRunTime: $($info.NextRunTime)"
foreach ($t in $task.Triggers) {
    Write-Output "TriggerType: $($t.TriggerType)"
    Write-Output "StartBoundary: $($t.StartBoundary)"
    Write-Output "Repetition.Interval: $($t.Repetition.Interval)"
    Write-Output "Repetition.Duration: $($t.Repetition.Duration)"
}
