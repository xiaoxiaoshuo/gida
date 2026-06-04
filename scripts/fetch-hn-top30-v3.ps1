# fetch-hn-top30-v3.ps1
# 拉取 HN top 30 故事, 写入时序归档 + latest (解决 GWF 不可达 + PowerShell TLS 抖动)
# v3: 改用 Algolia HN search API 兜底, 减少 Firebase 单点依赖
[CmdletBinding()]
param(
    [int]$Count = 30
)

$root = "C:\Users\Administrator\clawd\agents\workspace-gid\data\tech"
$ts = Get-Date -Format "yyyy-MM-dd_HH-mm"
$archPath = "$root\hacker-news-$ts.json"
$latestPath = "$root\hacker-news_latest.json"

Write-Host "[INFO] 尝试 1: Firebase topstories.json ..."
try {
    $ids = Invoke-RestMethod -Uri "https://hacker-news.firebaseio.com/v0/topstories.json" -TimeoutSec 20
    Write-Host "[OK] topstories 返回 $($ids.Count) 个 ID"
    $ids = $ids | Select-Object -First $Count
}
catch {
    Write-Host "[FAIL] Firebase 失败: $($_.Exception.Message)"
    Write-Host "[INFO] 尝试 2: Algolia search ..."
    try {
        $algolia = Invoke-RestMethod -Uri "https://hn.algolia.com/api/v1/search?tags=front_page" -TimeoutSec 20
        $ids = $algolia.hits | Select-Object -First $Count -ExpandProperty objectID
        Write-Host "[OK] Algolia 返回 $($algolia.hits.Count) 条, 取 $($ids.Count) 个 ID"
    }
    catch {
        Write-Host "[FAIL] Algolia 也失败: $($_.Exception.Message)"
        exit 1
    }
}

$results = @()
foreach ($id in $ids) {
    try {
        $resp = Invoke-RestMethod -Uri "https://hacker-news.firebaseio.com/v0/item/$id.json" -TimeoutSec 10
        if ($resp) {
            $results += $resp
            $title = if ($resp.title.Length -gt 60) { $resp.title.Substring(0, 60) + "..." } else { $resp.title }
            Write-Host "[OK] $id - $title"
        }
    }
    catch {
        Write-Host "[WARN] $id 拉取失败, 跳过"
    }
    Start-Sleep -Milliseconds 80
}

$output = @{
    采集时间 = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss+08:00")
    数量     = $results.Count
    items    = $results
} | ConvertTo-Json -Depth 8

$output | Out-File -FilePath $archPath -Encoding UTF8
$output | Out-File -FilePath $latestPath -Encoding UTF8
Write-Host "[OK] 写入: $archPath"
Write-Host "[OK] 写入: $latestPath"
Write-Host "[DONE] 共 $($results.Count) 条"
