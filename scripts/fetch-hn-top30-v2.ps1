# fetch-hn-top30-v2.ps1 - 实时 HN Top 30 拉取
# 与 v1 区别: 实时查询 topstories.json, 而不是硬编码 ID

$baseUrl = "https://hacker-news.firebaseio.com/v0/"
$results = @()

Write-Host "[INFO] 拉取 HN topstories.json ..."
try {
    $ids = Invoke-RestMethod -Uri ($baseUrl + "topstories.json") -TimeoutSec 15
    Write-Host "[OK] topstories 返回 $($ids.Count) 个 ID"
} catch {
    Write-Host "[FAIL] topstories 拉取失败: $_"
    exit 1
}

$ids = $ids | Select-Object -First 30

foreach ($id in $ids) {
    $url = $baseUrl + "item/$id.json"
    try {
        $resp = Invoke-RestMethod -Uri $url -TimeoutSec 10
        if ($resp) {
            $results += $resp
            $title = if ($resp.title.Length -gt 60) { $resp.title.Substring(0, 60) + "..." } else { $resp.title }
            Write-Host "[OK] $id - $title"
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
} | ConvertTo-Json -Depth 8

# 写入最新 + 归档
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$archivePath = "data\tech\hacker-news-$timestamp.json"
$latestPath = "data\tech\hacker-news_latest.json"

$output | Out-File -FilePath $archivePath -Encoding UTF8
$output | Out-File -FilePath $latestPath -Encoding UTF8
Write-Host "[OK] 写入: $archivePath"
Write-Host "[OK] 写入: $latestPath"
Write-Host "[DONE] 共 $($results.Count) 条"
