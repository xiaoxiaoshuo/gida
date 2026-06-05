# G-57 list all scheduled tasks with full Principal info
Get-ScheduledTask | Where-Object { $_.State -ne 'Disabled' } | ForEach-Object {
  $p = $_.Principal
  $line = "{0,-30} | State={1,-8} | P=[{2}/{3}/{4}] | LastResult={5} | LastRun={6} | NextRun={7}" -f `
    $_.TaskName, $_.State, $p.LogonType, $p.UserId, $p.RunLevel, $_.LastTaskResult, $_.LastRunTime, $_.NextRunTime
  Write-Host $line
}
