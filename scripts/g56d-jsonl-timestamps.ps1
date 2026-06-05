$jsonl = "C:\Users\Administrator\clawd\agents\workspace-gid\data\system\cron-health-watchdog.jsonl"
$lines = Get-Content $jsonl
Write-Host "=== Total lines: $($lines.Count) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "=== Timestamps ===" -ForegroundColor Cyan
foreach ($line in $lines) {
    try {
        $obj = $line | ConvertFrom-Json
        $ok = $obj.ok
        $failed = $obj.failed
        $date = $obj.date
        Write-Host ("  {0} | date={1} | ok={2} failed={3}" -f $obj.timestamp, $date, $ok, $failed)
    } catch {
        Write-Host "  [parse-error] $line" -ForegroundColor Red
    }
}
Write-Host ""
Write-Host "=== Last 2 lines (raw, truncated) ===" -ForegroundColor Cyan
$lines | Select-Object -Last 2 | ForEach-Object { Write-Host ($_.Substring(0, [Math]::Min(200, $_.Length)) + "...") }
