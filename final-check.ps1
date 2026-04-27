$json = Get-Content "C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\ai-news_latest.json" -Raw | ConvertFrom-Json
Write-Host "Timestamp: $($json.timestamp)"
Write-Host "Total count: $($json.count)"
Write-Host ""
Write-Host "Sources:"
$json.sources | ForEach-Object {
    Write-Host "- $($_.name): $($_.count) items"
}
Write-Host ""
Write-Host "Date range check (first 5 and last 5):"
$json.items | Select-Object -First 5 | ForEach-Object { Write-Host "$($_.source): $($_.title.Substring(0, [Math]::Min(60, $_.title.Length)))..." }
Write-Host "..."
$json.items | Select-Object -Last 5 | ForEach-Object { Write-Host "$($_.source): $($_.title.Substring(0, [Math]::Min(60, $_.title.Length)))..." }