$ErrorActionPreference = "Continue"

$batPath = "C:\Users\Administrator\clawd\agents\workspace-gid\run-ai-news.bat"

$action = New-ScheduledTaskAction -Execute $batPath
$trigger = New-ScheduledTaskTrigger -Daily -At "15:25"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId "Administrator" -LogonType Interactive -RunLevel Highest

$task = Register-ScheduledTask -TaskName "Test_Bat_1525" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Test batch task" -Force

Write-Host "Task created: Test_Bat_1525"
Write-Host "Starting task..."

Start-ScheduledTask -TaskName "Test_Bat_1525"
Start-Sleep 30

$info = Get-ScheduledTaskInfo -TaskName "Test_Bat_1525"
Write-Host "LastTaskResult: $($info.LastTaskResult) (hex: 0x$($info.LastTaskResult.ToString('X8')))"
Write-Host "LastRunTime: $($info.LastRunTime)"

# Check log
$logFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\cron_log.txt"
if (Test-Path $logFile) {
    Write-Host "Log contents:"
    Get-Content $logFile | Select-Object -Last 10
} else {
    Write-Host "Log file NOT found"
}

# Check output files
$hnFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\hn-top30-2026-04-24.json"
if (Test-Path $hnFile) {
    Write-Host "HN file: $(Get-Item $hnFile | Select-Object -ExpandProperty LastWriteTime)"
}

Unregister-ScheduledTask -TaskName "Test_Bat_1525" -Confirm:$false
Write-Host "Cleanup done"