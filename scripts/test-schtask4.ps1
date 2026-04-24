$ErrorActionPreference = "Continue"

$scriptPath = "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\fetch-hn-top30.ps1"
$exePath = "D:\Program Files\PowerShell\7\pwsh.exe"

$action = New-ScheduledTaskAction -Execute $exePath -Argument "-ExecutionPolicy Bypass -NoLogo -File `"$scriptPath`" 2>&1 | Out-File C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\test_output.txt"
$trigger = New-ScheduledTaskTrigger -Daily -At "15:05"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId "Administrator" -LogonType Interactive -RunLevel Highest

$task = Register-ScheduledTask -TaskName "Test_HN_1505" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Test with redirect" -Force

Write-Host "Task created: Test_HN_1505"
Write-Host "Starting task..."

Start-ScheduledTask -TaskName "Test_HN_1505"
Start-Sleep 25

$info = Get-ScheduledTaskInfo -TaskName "Test_HN_1505"
$hexResult = "0x" + $info.LastTaskResult.ToString("X8")
Write-Host "LastTaskResult: $($info.LastTaskResult) (hex: $hexResult)"
Write-Host "LastRunTime: $($info.LastRunTime)"

# Check output
$outFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\test_output.txt"
if (Test-Path $outFile) {
    Write-Host "Output:"
    Get-Content $outFile | Select-Object -First 10
} else {
    Write-Host "Output file NOT found"
}

Unregister-ScheduledTask -TaskName "Test_HN_1505" -Confirm:$false
Write-Host "Cleanup done"