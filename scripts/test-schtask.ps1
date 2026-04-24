$ErrorActionPreference = "Continue"

# Test 1: Simple echo task
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -NoProfile -Command `"Write-Host 'TASK WORKS'; Start-Sleep 5; Write-Host 'DONE'`""
$trigger = New-ScheduledTaskTrigger -Daily -At "14:30"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId "Administrator" -LogonType Interactive -RunLevel Highest

$task = Register-ScheduledTask -TaskName "Test_Echo_1430" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Test" -Force

Write-Host "Task created: Test_Echo_1430"
Write-Host "Starting task..."

Start-ScheduledTask -TaskName "Test_Echo_1430"
Start-Sleep 15

$info = Get-ScheduledTaskInfo -TaskName "Test_Echo_1430"
$hexResult = "0x" + $info.LastTaskResult.ToString("X8")
Write-Host "LastTaskResult: $($info.LastTaskResult) (hex: $hexResult)"
Write-Host "LastRunTime: $($info.LastRunTime)"
Write-Host "State: $($info.State)"

Unregister-ScheduledTask -TaskName "Test_Echo_1430" -Confirm:$false
Write-Host "Cleanup done"