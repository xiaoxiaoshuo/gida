$ErrorActionPreference = "Continue"

$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"
$exePath = "D:\Program Files\PowerShell\7\pwsh.exe"

# Remove existing
$existing = Get-ScheduledTask -TaskName "AINewsCollector_6h" -ErrorAction SilentlyContinue
if ($existing) { Unregister-ScheduledTask -TaskName "AINewsCollector_6h" -Confirm:$false }

# Use wrapper script (bat file that calls pwsh with proper args)
$action = New-ScheduledTaskAction -Execute $exePath -Argument "-ExecutionPolicy Bypass -NoLogo -WindowStyle Hidden -File `"$RepoRoot\run-ai-news-wrapper.ps1`""

# 触发器: 00:00, 06:00, 12:00, 18:00 北京时间
$trigger1 = New-ScheduledTaskTrigger -Daily -At "00:00"
$trigger2 = New-ScheduledTaskTrigger -Daily -At "06:00"
$trigger3 = New-ScheduledTaskTrigger -Daily -At "12:00"
$trigger4 = New-ScheduledTaskTrigger -Daily -At "18:00"

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable:$false -DontStopOnIdle:$false

$principal = New-ScheduledTaskPrincipal -UserId "Administrator" -LogonType Interactive -RunLevel Highest

$description = "AI新闻采集: HN Top30 + GitHub Trending (每6小时)"

$task = Register-ScheduledTask -TaskName "AINewsCollector_6h" `
    -Action $action `
    -Trigger $trigger1,$trigger2,$trigger3,$trigger4 `
    -Settings $settings `
    -Principal $principal `
    -Description $description -Force

Write-Host "Task created: AINewsCollector_6h"
Write-Host "Uses wrapper: run-ai-news-wrapper.ps1 (pwsh.exe)"
Write-Host "Triggers: 00:00, 06:00, 12:00, 18:00 (北京时间)"
Write-Host ""
$info = Get-ScheduledTaskInfo -TaskName "AINewsCollector_6h"
Write-Host "Next run: $($info.NextRunTime)"
Write-Host "Last result: $($info.LastTaskResult) (hex: 0x$($info.LastTaskResult.ToString('X8')))"