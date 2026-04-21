# HN Top 30采集脚本
$ids = @(
  47840219,47843194,47841129,47843715,47834565,47838703,47812749,47839645,47833558,47836784,
  47840980,47811668,47834195,47822549,47831742,47811154,47835928,47841149,47832969,47809338,
  47832248,47823777,47839835,47826839,47789291,47837176,47807609,47833247,47834184,47835735
)

$baseUrl = "https://hacker-news.firebaseio.com/v0/item/{0}.json"
$results = @()

foreach ($id in $ids) {
  $url = [string]::Format($baseUrl, $id)
  try {
    $resp = Invoke-WebRequest -Uri $url -TimeoutSec 10
    if ($resp.StatusCode -eq 200) {
      $item = $resp.Content | ConvertFrom-Json
      $results += $item
      Write-Host "[OK] $id - $($item.title.Substring(0, [Math]::Min(60, $item.title.Length)))"
    }
  } catch {
    Write-Host "[FAIL] $id - $_"
  }
  Start-Sleep -Milliseconds 100
}

$output = @{
 采集时间 = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
  数量 = $results.Count
  items = $results
}

$output | ConvertTo-Json -Depth 5 | Out-File -FilePath "C:/Users/Administrator/clawd/agents/workspace-gid/data/tech/hacker-news_latest.json" -Encoding UTF8
Write-Host "写入完成，共 $($results.Count) 条"
