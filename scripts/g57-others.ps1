# G-57 check other potentially broken tasks
$names = @('DailyCollector','HeartbeatSelfCheck','HPC_Test','gh-trending-v7-hourly')
foreach ($n in $names) {
    $t = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($null -eq $t) { Write-Host "${n}: NOT FOUND"; continue }
    $p = $t.Principal
    $info = Get-ScheduledTaskInfo -TaskName $n -ErrorAction SilentlyContinue
    $cmd = $t.Actions[0].Execute
    Write-Host ("{0}: P=[{1}/{2}/{3}] Cmd={4} LastResult=0x{5:X8} LastRun={6}" -f $n, $p.LogonType, $p.UserId, $p.RunLevel, $cmd, $info.LastTaskResult, $info.LastRunTime)
}
