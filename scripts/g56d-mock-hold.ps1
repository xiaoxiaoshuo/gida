$ErrorActionPreference = "Continue"
$mutexName = "Global\GidaCronWatchdogV3_30min_Mutex"
$mutex = New-Object System.Threading.Mutex($false, $mutexName)
$log = "C:\Users\Administrator\clawd\agents\workspace-gid\data\system\g56d-ab-pinned.log"
$entryTemplate = @{
    ts = (Get-Date -Format "o")
    test_id = "PINNED-A"
    pid = $PID
    event = ""
    acquired = $false
    detail = ""
}
function Log-Evt($event, $acquired, $detail) {
    $e = $entryTemplate.Clone()
    $e.event = $event
    $e.acquired = $acquired
    $e.detail = $detail
    Add-Content -Path $log -Value ($e | ConvertTo-Json -Compress)
    Write-Host "[PINNED-A | $PID] $event | acquired=$acquired | $detail" -ForegroundColor 
}
if ($mutex.WaitOne(0, $false)) {
    Log-Evt "acquired" $true "Mutex held, sleeping 8s"
    Start-Sleep -Seconds 8
    try { $mutex.ReleaseMutex() | Out-Null; Log-Evt "released" $true "Released" } catch { Log-Evt "release_err" $false $_ }
} else {
    Log-Evt "skipped" $false "Another instance holds"
}
$mutex.Dispose()
