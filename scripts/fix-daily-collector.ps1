$ErrorActionPreference = "Continue"

$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"
$exePath = "D:\Program Files\PowerShell\7\pwsh.exe"

# Fix daily collector by changing powershell.exe -> pwsh.exe
$tasks = @("DailyCollector_AM", "DailyCollector_PM")
foreach ($tname in $tasks) {
    $task = Get-ScheduledTask -TaskName $tname -ErrorAction SilentlyContinue
    if ($task) {
        $oldAction = $task.Actions[0]
        Write-Host "Fixing $tname..."
        Write-Host "  Old Execute: $($oldAction.Execute)"
        Write-Host "  Old Args:    $($oldAction.Arguments)"
        
        # Rebuild args with pwsh instead of powershell
        $newArgs = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$RepoRoot\scripts\daily-collector.ps1`""
        $newAction = New-ScheduledTaskAction -Execute $exePath -Argument $newArgs
        
        Set-ScheduledTask -TaskName $tname -Action $newAction
        Write-Host "  New Execute: $exePath"
        Write-Host "  New Args:    $newArgs"
        
        # Test the task
        Write-Host "  Testing..."
        Start-ScheduledTask -TaskName $tname
        Start-Sleep 15
        $info = Get-ScheduledTaskInfo -TaskName $tname
        $hex = "0x" + $info.LastTaskResult.ToString("X8")
        Write-Host "  Result: $($info.LastTaskResult) (hex: $hex)"
        Write-Host "  LastRun: $($info.LastRunTime)"
    } else {
        Write-Host "Task $tname not found"
    }
}

Write-Host "All done"