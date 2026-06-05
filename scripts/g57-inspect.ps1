# G-57 Inspect - 12:00 inspection of broken tasks
$ErrorActionPreference = 'SilentlyContinue'
$tasks = @('BridgeCollector2h','FomcD7Tracker','AINewsCollector_0400')
foreach ($name in $tasks) {
  $t = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
  Write-Host "=== $name ==="
  if ($null -eq $t) { Write-Host "NOT FOUND"; continue }
  Write-Host ("TaskPath: " + $t.TaskPath)
  Write-Host ("State: " + $t.State)
  Write-Host ("Principal.LogonType: " + $t.Principal.LogonType)
  Write-Host ("Principal.UserId: " + $t.Principal.UserId)
  Write-Host ("Principal.RunLevel: " + $t.Principal.RunLevel)
  Write-Host ("LastRunTime: " + $t.LastRunTime)
  Write-Host ("LastTaskResult: " + $t.LastTaskResult)
  Write-Host ("NextRunTime: " + $t.NextRunTime)
  Write-Host ""
}
Write-Host "=== healthy reference: CronWatchdogV3 ==="
$t2 = Get-ScheduledTask -TaskName 'CronWatchdogV3' -ErrorAction SilentlyContinue
if ($null -ne $t2) {
  Write-Host ("Principal.LogonType: " + $t2.Principal.LogonType)
  Write-Host ("Principal.UserId: " + $t2.Principal.UserId)
  Write-Host ("Principal.RunLevel: " + $t2.Principal.RunLevel)
  Write-Host ("LastTaskResult: " + $t2.LastTaskResult)
}
