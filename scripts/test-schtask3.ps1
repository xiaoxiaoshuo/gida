$ErrorActionPreference = "Continue"

# Use pwsh.exe like HourlyPriceCollector does
$scriptPath = "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\fetch-hn-top30.ps1"
$exePath = "D:\Program Files\PowerShell\7\pwsh.exe"

$action = New-ScheduledTaskAction -Execute $exePath -Argument "-ExecutionPolicy Bypass -NoLogo -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Daily -At "14:55"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId "Administrator" -LogonType Interactive -RunLevel Highest

$task = Register-ScheduledTask -TaskName "Test_HN_1455" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Test with pwsh" -Force

Write-Host "Task created: Test_HN_1455"
Write-Host "Starting task..."

Start-ScheduledTask -TaskName "Test_HN_1455"
Start-Sleep 20

$info = Get-ScheduledTaskInfo -TaskName "Test_HN_1455"
$hexResult = "0x" + $info.LastTaskResult.ToString("X8")
Write-Host "LastTaskResult: $($info.LastTaskResult) (hex: $hexResult)"
Write-Host "LastRunTime: $($info.LastRunTime)"
Write-Host "State: $($info.State)"

Unregister-ScheduledTask -TaskName "Test_HN_1455" -Confirm:$false
Write-Host "Cleanup done"