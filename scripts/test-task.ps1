# test-task.ps1 - 诊断Scheduled Task执行问题
$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"
$LogFile = "$RepoRoot\memory\schtask-test.log"

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -NoLogo -Command `"Write-Host hello world; Write-Host (Get-Location); Get-Date | Out-File -FilePath '$RepoRoot\memory\schtask-test.log' -Encoding UTF8; exit 0`""

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(10)

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Unregister-ScheduledTask -TaskName 'HPC_Test' -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName 'HPC_Test' -Action $action -Trigger $trigger -Settings $settings -Description 'test' | Out-Null

Write-Host "Test task registered, will run in 10 seconds..."
