# G-57 Get-ScheduledTaskInfo for the broken 3
$names = @('BridgeCollector2h','FomcD7Tracker','AINewsCollector_0400','AINewsCollector_6h','CronWatchdogV3_30min','HourlyPriceCollector')
foreach ($n in $names) {
  $t = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
  if ($null -eq $t) { Write-Host "[$n] NOT FOUND"; continue }
  $info = Get-ScheduledTaskInfo -TaskName $n -ErrorAction SilentlyContinue
  $p = $t.Principal
  Write-Host "=== $n ==="
  Write-Host ("  Principal: LogonType={0}, UserId={1}, RunLevel={2}" -f $p.LogonType, $p.UserId, $p.RunLevel)
  if ($info) {
    Write-Host ("  LastRunTime: {0}" -f $info.LastRunTime)
    Write-Host ("  LastTaskResult: {0} (0x{0:X8})" -f $info.LastTaskResult)
    Write-Host ("  NextRunTime: {0}" -f $info.NextRunTime)
    Write-Host ("  NumberOfMissedRuns: {0}" -f $info.NumberOfMissedRuns)
  }
  Write-Host ("  Actions count: {0}" -f $t.Actions.Count)
  foreach ($a in $t.Actions) {
    Write-Host ("    - Execute={0} Arguments={1}" -f $a.Execute, $a.Arguments)
  }
  Write-Host ""
}
