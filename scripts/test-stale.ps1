$Now = Get-Date
$ts = [DateTime]::Parse("2026-03-26 03:16:48")
$age = ($Now - $ts).TotalHours
Write-Host "Current: $Now"
Write-Host "Price timestamp: $ts"
Write-Host "Age in hours: $age"
Write-Host "Is stale (>2h)?: $($age -gt 2)"
