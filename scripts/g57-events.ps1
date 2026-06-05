# G-57 Read recent TaskScheduler events
$events = Get-WinEvent -LogName 'Microsoft-Windows-TaskScheduler/Operational' -MaxEvents 50 -ErrorAction SilentlyContinue
Write-Host "Total events: $($events.Count)"
foreach ($e in $events | Select-Object -First 30) {
    $msg = $e.Message
    $short = if ($msg.Length -gt 200) { $msg.Substring(0, 200) + "..." } else { $msg }
    Write-Host ("[{0}] ID={1} Level={2}" -f $e.TimeCreated, $e.Id, $e.LevelDisplayName)
    Write-Host ("    {0}" -f $short)
    Write-Host ""
}
