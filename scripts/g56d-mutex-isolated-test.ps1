# G-56D isolated mutex test
# Create mutex in process 1, hold it, then try to acquire in process 2
# This tests the cross-process mutex behavior

param(
    [string]$TestId = "isolated",
    [int]$HoldSec = 0
)

$ErrorActionPreference = "Continue"
$mutexName = "Global\GidaCronWatchdogV3_30min_Mutex"
$mutex = $null
$logFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\system\g56d-mutex-isolated.log"
$entryTemplate = @{
    ts = (Get-Date -Format "o")
    test_id = $TestId
    pid = $PID
    event = ""
    mutex_name = $mutexName
    acquired = $false
    detail = ""
}

function Log-Evt($event, $acquired, $detail) {
    $e = $entryTemplate.Clone()
    $e.event = $event
    $e.acquired = $acquired
    $e.detail = $detail
    Add-Content -Path $logFile -Value ($e | ConvertTo-Json -Compress)
    Write-Host "[$TestId | $PID] $event | acquired=$acquired | $detail" -ForegroundColor $(if($acquired){"Green"}else{"Yellow"})
}

try {
    $mutex = New-Object System.Threading.Mutex($false, $mutexName)
    Log-Evt "created" $false "Mutex object created"
    
    if ($mutex.WaitOne(0, $false)) {
        Log-Evt "acquired" $true "WaitOne(0, false) returned true"
        if ($HoldSec -gt 0) {
            Log-Evt "holding" $true "Sleeping ${HoldSec}s while holding"
            Start-Sleep -Seconds $HoldSec
        }
        try { $mutex.ReleaseMutex() | Out-Null; Log-Evt "released" $true "ReleaseMutex OK" } catch {
            Log-Evt "release_err" $false "ReleaseMutex: $_"
        }
    } else {
        Log-Evt "skipped" $false "WaitOne(0, false) returned false (another instance holds)"
    }
} catch {
    Log-Evt "error" $false "Exception: $_"
} finally {
    if ($mutex) { try { $mutex.Dispose() } catch {} }
}
