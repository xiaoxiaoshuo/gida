$ErrorActionPreference = "Continue"

$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"

# Remove existing task if present
$existing = Get-ScheduledTask -TaskName "AINewsCollector_6h" -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName "AINewsCollector_6h" -Confirm:$false
    Write-Host "Removed existing task"
}

# HN采集脚本 (6小时一次)
$action1 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$RepoRoot\scripts\fetch-hn-top30.ps1`""

# GitHub Trending 采集脚本 (6小时一次)
$action2 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$RepoRoot\scripts\gh-trending-v3.ps1`""

# 简报生成脚本 (采集完成后)
$action3 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$RepoRoot\scripts\hourly-briefing.ps1`""

# 4个触发器: 00:00, 06:00, 12:00, 18:00 北京时间 = UTC-8
$trigger1 = New-ScheduledTaskTrigger -Daily -At "00:00" -RandomDelay (New-TimeSpan -Minutes 3)
$trigger2 = New-ScheduledTaskTrigger -Daily -At "06:00" -RandomDelay (New-TimeSpan -Minutes 3)
$trigger3 = New-ScheduledTaskTrigger -Daily -At "12:00" -RandomDelay (New-TimeSpan -Minutes 3)
$trigger4 = New-ScheduledTaskTrigger -Daily -At "18:00" -RandomDelay (New-TimeSpan -Minutes 3)

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable:$false -DontStopOnIdle:$false
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$description = "AI新闻采集: HN Top30 + GitHub Trending + 简报 (每6小时)"

# 注册任务 - 4个触发器全部添加
$task = Register-ScheduledTask -TaskName "AINewsCollector_6h" -Action $action1,$action2,$action3 -Trigger $trigger1,$trigger2,$trigger3,$trigger4 -Settings $settings -Principal $principal -Description $description -Force

Write-Host "Task created: AINewsCollector_6h"
Write-Host "Triggers: 00:00, 06:00, 12:00, 18:00 (北京时间)"
Write-Host "State: $($task.State)"
Write-Host ""
Write-Host "Action 1 (HN):   $($task.Actions[0].Execute) $($task.Actions[0].Arguments)"
Write-Host "Action 2 (GH):   $($task.Actions[1].Execute) $($task.Actions[1].Arguments)"
Write-Host "Action 3 (Brief): $($task.Actions[2].Execute) $($task.Actions[2].Arguments)"