# G-56D launcher: start HOLD-A in background, then CHECK-B after delay
$scriptPath = "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\g56d-mutex-isolated-test.ps1"

# Clear log
$logFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\system\g56d-mutex-isolated.log"
"" | Set-Content $logFile

# Start HOLD-A in background, holding mutex for 15s
Write-Host "Starting HOLD-A (15s)..." -ForegroundColor Cyan
$proc = Start-Process powershell -ArgumentList @('-ExecutionPolicy','Bypass','-File',$scriptPath,'HOLD-A','15') -PassThru
Write-Host "HOLD-A PID: $($proc.Id)" -ForegroundColor Cyan

# Wait 3s, then CHECK-B
Start-Sleep -Seconds 3
Write-Host ""
Write-Host "Starting CHECK-B (should be SKIPPED if mutex works)..." -ForegroundColor Yellow
& powershell -ExecutionPolicy Bypass -File $scriptPath 'CHECK-B' '0'
Write-Host "CHECK-B returned" -ForegroundColor Yellow

# Wait for HOLD-A to complete
$proc.WaitForExit()
Write-Host ""
Write-Host "HOLD-A exited" -ForegroundColor Cyan

Write-Host ""
Write-Host "=== Log entries ===" -ForegroundColor Cyan
Get-Content $logFile | ForEach-Object {
    $obj = $_ | ConvertFrom-Json
    Write-Host "  $($obj.ts) | test=$($obj.test_id) | pid=$($obj.pid) | evt=$($obj.event) | acquired=$($obj.acquired) | $($obj.detail)"
}
