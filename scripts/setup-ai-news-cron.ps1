$ErrorActionPreference = "Continue"

$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"

# Remove existing
$existing = Get-ScheduledTask -TaskName "AINewsCollector_6h" -ErrorAction SilentlyContinue
if ($existing) { Unregister-ScheduledTask -TaskName "AINewsCollector_6h" -Confirm:$false }

# === HN 采集 (主脚本) ===
$action1 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$RepoRoot\scripts\fetch-hn-top30.ps1`""

# === GitHub Trending ===
$action2 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$RepoRoot\scripts\gh-trending-v3.ps1`""

# 触发器: 00:00, 06:00, 12:00, 18:00 北京时间
$trigger1 = New-ScheduledTaskTrigger -Daily -At "00:00"
$trigger2 = New-ScheduledTaskTrigger -Daily -At "06:00"
$trigger3 = New-ScheduledTaskTrigger -Daily -At "12:00"
$trigger4 = New-ScheduledTaskTrigger -Daily -At "18:00"

# 设置 - 用 Administrator 账户运行（Interactive）
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false `
    -DontStopOnIdle:$false

$principal = New-ScheduledTaskPrincipal `
    -UserId "Administrator" `
    -LogonType Interactive `
    -RunLevel Highest

$description = "AI新闻采集: HN Top30 + GitHub Trending (每6小时)"

$task = Register-ScheduledTask -TaskName "AINewsCollector_6h" `
    -Action $action1,$action2 `
    -Trigger $trigger1,$trigger2,$trigger3,$trigger4 `
    -Settings $settings `
    -Principal $principal `
    -Description $description -Force

Write-Host "Task created: AINewsCollector_6h (Administrator, Interactive)"
Write-Host "Next run: $((Get-ScheduledTaskInfo -TaskName 'AINewsCollector_6h').NextRunTime)"