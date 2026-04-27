$json = Get-Content "C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\ai-news_latest.json" -Raw | ConvertFrom-Json
Write-Host "Total: $($json.items.Count) items"
Write-Host ""

$json.items | Group-Object source | ForEach-Object {
    Write-Host "$($_.Name): $($_.Count) items"
}

Write-Host ""
Write-Host "=== Checking VentureBeat items ==="
$json.items | Where-Object { $_.source -eq "VentureBeat AI" } | ForEach-Object {
    Write-Host "Title: $($_.title)"
    Write-Host "URL: $($_.url)"
    Write-Host "Desc length: $(if($_.desc) { $_.desc.Length } else { 0 })"
    Write-Host "Date: $($_.date)"
    Write-Host "---"
}
