Set-Location 'C:\Users\Administrator\clawd\agents\workspace-gid'
$cutoff = Get-Date '2026-06-05 06:20'
$end = Get-Date '2026-06-05 06:40'
$results = Get-ChildItem -Path INTEL,briefings,data -Recurse -ErrorAction SilentlyContinue | Where-Object { ($_.LastWriteTime -gt $cutoff) -and ($_.LastWriteTime -lt $end) } | Select-Object FullName, Length, LastWriteTime
Write-Host ("Files: " + $results.Count)
$results | Format-Table -AutoSize
