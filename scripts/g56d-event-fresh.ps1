$events = Get-WinEvent -LogName 'Microsoft-Windows-TaskScheduler/Operational' -MaxEvents 50 -ErrorAction SilentlyContinue |
    Where-Object { $_.TimeCreated -gt (Get-Date).AddMinutes(-10) }
Write-Host "=== Events in last 10 min: $($events.Count) ===" -ForegroundColor Cyan
foreach ($e in $events) {
    $head = ($e.Message -split "`r?`n")[0..3] -join " | "
    Write-Host "$($e.TimeCreated.ToString('HH:mm:ss')) | ID=$($e.Id) | $($e.LevelDisplayName) | $head"
}

Write-Host ""
Write-Host "=== All CronWatchdog-related events ===" -ForegroundColor Cyan
$all = Get-WinEvent -LogName 'Microsoft-Windows-TaskScheduler/Operational' -MaxEvents 200 -ErrorAction SilentlyContinue
$cronEvts = $all | Where-Object { $_.Message -match 'CronWatchdog' -or $_.Message -match '2147942402' -or $_.Message -match '0x800710E0' }
Write-Host "CronWatchdog-related count: $($cronEvts.Count)" -ForegroundColor Cyan
foreach ($e in $cronEvts | Select-Object -First 20) {
    $head = ($e.Message -split "`r?`n")[0..3] -join " | "
    Write-Host "$($e.TimeCreated.ToString('HH:mm:ss')) | ID=$($e.Id) | $($e.LevelDisplayName) | $head"
}
