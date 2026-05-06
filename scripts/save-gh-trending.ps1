$data = Get-Content data/github-trending-temp.json -Raw | ConvertFrom-Json
$now = Get-Date

$datedFile = 'data/ai/github-trending-' + $now.ToString('yyyy-MM-dd') + '.json'
$datedData = @{
  timestamp = $now.ToString('yyyy-MM-dd HH:mm:ss')
  count = $data.Count
  repos = $data
} | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText((Join-Path $PWD $datedFile), $datedData, [System.Text.Encoding]::UTF8)
Write-Host 'Written:' $datedFile

$latestData = @{
  timestamp = $now.ToString('yyyy-MM-dd HH:mm:ss')
  count = $data.Count
  repos = $data
} | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText((Join-Path $PWD 'data/ai/github-trending_latest.json'), $latestData, [System.Text.Encoding]::UTF8)
Write-Host 'Written: data/ai/github-trending_latest.json'