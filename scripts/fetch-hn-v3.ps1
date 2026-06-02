# fetch-hn-v3.ps1 - HN 多 API fallback
# 与 v2 区别: Firebase API → Algolia API (Firebase 受 GFW 影响)

$algoliaUrl = "https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage=30"
$firebaseUrl = "https://hacker-news.firebaseio.com/v0/topstories.json"
$results = @()
$source = ""

Write-Host "[INFO] 尝试 Algolia API ..."
try {
    $resp = Invoke-RestMethod -Uri $algoliaUrl -TimeoutSec 20
    if ($resp.hits) {
        $source = "Algolia"
        foreach ($h in $resp.hits) {
            $results += [PSCustomObject]@{
                id          = $h.objectID
                title       = $h.title
                url         = $h.url
                by          = $h.author
                score       = $h.points
                descendants = $h.num_comments
                time        = $h.created_at_i
            }
        }
        Write-Host "[OK] Algolia 返回 $($results.Count) 条"
    }
} catch {
    Write-Host "[FAIL] Algolia 失败: $_"
}

if ($results.Count -eq 0) {
    Write-Host "[INFO] 尝试 Firebase API ..."
    try {
        $ids = Invoke-RestMethod -Uri $firebaseUrl -TimeoutSec 20 | Select-Object -First 30
        foreach ($id in $ids) {
            $item = Invoke-RestMethod -Uri "https://hacker-news.firebaseio.com/v0/item/$id.json" -TimeoutSec 10
            if ($item) {
                $results += [PSCustomObject]@{
                    id          = $item.id
                    title       = $item.title
                    url         = $item.url
                    by          = $item.by
                    score       = $item.score
                    descendants = $item.descendants
                    time        = $item.time
                }
            }
        }
        $source = "Firebase"
        Write-Host "[OK] Firebase 返回 $($results.Count) 条"
    } catch {
        Write-Host "[FAIL] Firebase 失败: $_"
        exit 1
    }
}

$output = @{
    采集时间 = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    数量 = $results.Count
    source = $source
    items = $results
} | ConvertTo-Json -Depth 8

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$archivePath = "data\tech\hacker-news-$timestamp.json"
$latestPath = "data\tech\hacker-news_latest.json"

$output | Out-File -FilePath $archivePath -Encoding UTF8
$output | Out-File -FilePath $latestPath -Encoding UTF8
Write-Host "[OK] 写入: $archivePath (source=$source)"
Write-Host "[OK] 写入: $latestPath"
Write-Host "[DONE] 共 $($results.Count) 条 (source: $source)"
