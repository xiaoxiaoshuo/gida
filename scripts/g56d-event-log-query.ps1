# G-56D Event log query
$logs = @("Application", "System", "Microsoft-Windows-TaskScheduler/Operational")
$out = @()

foreach ($log in $logs) {
    try {
        $events = Get-WinEvent -LogName $log -MaxEvents 500 -ErrorAction SilentlyContinue
        $matched = $events | Where-Object {
            $msg = $_.Message
            ($msg -match 'CronWatchdog') -or
            ($msg -match '0x800710E0') -or
            ($msg -match '2147942402') -or
            ($msg -match 'ABANDONED')
        }
        foreach ($e in $matched) {
            $out += [PSCustomObject]@{
                Time = $e.TimeCreated
                Log = $log
                Id = $e.Id
                Level = $e.LevelDisplayName
                Provider = $e.ProviderName
                MsgHead = ($e.Message -split "`n")[0..3] -join " | "
            }
        }
    } catch {
        $out += [PSCustomObject]@{
            Time = Get-Date
            Log = $log
            Id = "N/A"
            Level = "ERR"
            Provider = "query"
            MsgHead = $_.Exception.Message
        }
    }
}

$out | Format-Table -AutoSize -Wrap | Out-String -Stream | Select-Object -First 50
Write-Host "=== Total matches: $($out.Count) ===" -ForegroundColor Cyan
