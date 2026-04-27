$json = Get-Content "C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\ai-news_latest.json" -Raw | ConvertFrom-Json
Write-Host "Total items: $($json.items.Count)"
Write-Host ""
$vb = $json.items | Where-Object { $_.source -eq "VentureBeat AI" }
Write-Host "VentureBeat items: $($vb.Count)"
$vb | Select-Object -First 3 | ForEach-Object {
    Write-Host "Title: $($_.title)"
    Write-Host "URL: $($_.url)"
    Write-Host "Desc (50): $($_.desc.Substring(0, [Math]::Min(50, $_.desc.Length)))"
    Write-Host "---"
}
Write-Host ""
$verge = $json.items | Where-Object { $_.source -eq "The Verge" }
Write-Host "The Verge items: $($verge.Count)"
$verge | Select-Object -First 3 | ForEach-Object {
    Write-Host "Title: $($_.title)"
    Write-Host "URL: $($_.url)"
    Write-Host "Date: $($_.date)"
    Write-Host "---"
}
