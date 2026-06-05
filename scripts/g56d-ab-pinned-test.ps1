# G-56D pinned A/B test: A holds mutex, B starts while A is still running
$ErrorActionPreference = "Continue"
$Workspace = "C:\Users\Administrator\clawd\agents\workspace-gid"
$script = Join-Path $Workspace "scripts\cron-watchdog-v3-30min.ps1"
$logFile = Join-Path $Workspace "data\system\g56d-ab-pinned.log"

# Clear log
"" | Set-Content $logFile

# Use Mock v3 script that holds mutex for 8s before doing checks
$mockScript = @"
`$ErrorActionPreference = "Continue"
`$mutexName = "Global\GidaCronWatchdogV3_30min_Mutex"
`$mutex = New-Object System.Threading.Mutex(`$false, `$mutexName)
`$log = "C:\Users\Administrator\clawd\agents\workspace-gid\data\system\g56d-ab-pinned.log"
`$entryTemplate = @{
    ts = (Get-Date -Format "o")
    test_id = "PINNED-A"
    pid = `$PID
    event = ""
    acquired = `$false
    detail = ""
}
function Log-Evt(`$event, `$acquired, `$detail) {
    `$e = `$entryTemplate.Clone()
    `$e.event = `$event
    `$e.acquired = `$acquired
    `$e.detail = `$detail
    Add-Content -Path `$log -Value (`$e | ConvertTo-Json -Compress)
    Write-Host "[PINNED-A | `$PID] `$event | acquired=`$acquired | `$detail" -ForegroundColor $(if(`$acquired){"Green"}else{"Yellow"})
}
if (`$mutex.WaitOne(0, `$false)) {
    Log-Evt "acquired" `$true "Mutex held, sleeping 8s"
    Start-Sleep -Seconds 8
    try { `$mutex.ReleaseMutex() | Out-Null; Log-Evt "released" `$true "Released" } catch { Log-Evt "release_err" `$false `$_ }
} else {
    Log-Evt "skipped" `$false "Another instance holds"
}
`$mutex.Dispose()
"@

$mockPath = Join-Path $Workspace "scripts\g56d-mock-hold.ps1"
$mockScript | Out-File -FilePath $mockPath -Encoding UTF8

# Start PINNED-A in background
Write-Host "Starting PINNED-A (holds 8s)..." -ForegroundColor Cyan
$proc = Start-Process powershell -ArgumentList @('-ExecutionPolicy','Bypass','-File',$mockPath) -PassThru
Write-Host "PINNED-A PID: $($proc.Id)" -ForegroundColor Cyan

# Wait 2s, then run real v3 script (B)
Start-Sleep -Seconds 2
Write-Host ""
Write-Host "Starting B (real v3, while A holds)..." -ForegroundColor Yellow
& powershell -ExecutionPolicy Bypass -File $script -Quick 2>&1 | Out-String -Stream | ForEach-Object { Write-Host "  $_" }

# Wait for A
$proc.WaitForExit()
Write-Host ""
Write-Host "PINNED-A exited" -ForegroundColor Cyan

Write-Host ""
Write-Host "=== Log ===" -ForegroundColor Cyan
Get-Content $logFile | ForEach-Object {
    try {
        $obj = $_ | ConvertFrom-Json
        if ($obj.test_id) {
            Write-Host "  $($obj.ts) | test=$($obj.test_id) | pid=$($obj.pid) | evt=$($obj.event) | acquired=$($obj.acquired) | $($obj.detail)"
        }
    } catch {}
}
