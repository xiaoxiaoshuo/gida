$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Users\Administrator\clawd\agents\workspace-gid\scripts\heartbeat-self-check.ps1"
$trigger = New-ScheduledTaskTrigger -Once -At "06:00" -RepetitionInterval (New-TimeSpan -Hours 6) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName "HeartbeatSelfCheck" -Action $action -Trigger $trigger -Settings $settings -Description "每6小时工作区自检" -Force | Out-Null
Write-Host "HeartbeatSelfCheck: $?"
Get-ScheduledTask -TaskName "HeartbeatSelfCheck" | Format-List TaskName, State
