# G-57 Final Verification
$names = @('BridgeCollector2h','FomcD7Tracker','AINewsCollector_0400')
foreach ($n in $names) {
    $t = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    if ($null -eq $t) {
        Write-Host "${n}: NOT REGISTERED"
        continue
    }
    $p = $t.Principal
    $info = Get-ScheduledTaskInfo -TaskName $n
    $a = $t.Actions[0]
    Write-Host "=== $n ==="
    Write-Host "  Principal: LogonType=$($p.LogonType), UserId=$($p.UserId), RunLevel=$($p.RunLevel)"
    Write-Host "  Action: Command=$($a.Execute)"
    Write-Host "  LastRun=$($info.LastRunTime)"
    Write-Host "  LastResult=0x$('{0:X8}' -f $info.LastTaskResult)"
    Write-Host "  NextRun=$($info.NextRunTime)"
    Write-Host ""
}
