$ErrorActionPreference = "Continue"

# Check the current AI news task
Write-Host "=== Current AINewsCollector_6h ==="
$info = Get-ScheduledTaskInfo -TaskName "AINewsCollector_6h"
Write-Host "LastTaskResult: $($info.LastTaskResult) (hex: 0x$($info.LastTaskResult.ToString('X8')))"
Write-Host "LastRunTime: $($info.LastRunTime)"
Write-Host "NextRunTime: $($info.NextRunTime)"
Write-Host "NumberOfMissedRuns: $($info.NumberOfMissedRuns)"
Write-Host ""

# Check today's HN output
$todayFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\hn-top30-2026-04-24.json"
if (Test-Path $todayFile) {
    Write-Host "Today's HN file exists: $(Get-Item $todayFile | Select-Object -ExpandProperty LastWriteTime)"
    $content = Get-Content $todayFile -Raw
    if ($content) {
        $items = $content | ConvertFrom-Json
        Write-Host "Items count: $($items.Count)"
    }
} else {
    Write-Host "Today's HN file NOT found: $todayFile"
}
Write-Host ""

# Check github-trending today's output
$ghFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\github-trending-2026-04-24.json"
if (Test-Path $ghFile) {
    Write-Host "Today's GH file exists: $(Get-Item $ghFile | Select-Object -ExpandProperty LastWriteTime)"
} else {
    Write-Host "Today's GH file NOT found: $ghFile"
}
Write-Host ""

# Manual run test
Write-Host "=== Manual run test ==="
Write-Host "Running fetch-hn-top30.ps1 directly..."
& "D:\Program Files\PowerShell\7\pwsh.exe" -ExecutionPolicy Bypass -NoLogo -File "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\fetch-hn-top30.ps1" 2>&1 | Select-Object -Last 5
Write-Host "Exit code: $LASTEXITCODE"