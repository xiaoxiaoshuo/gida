# sync-hn-md.ps1 - HN Top 30 转 Markdown
# 输出: data/tech/hacker-news_latest.md

$jsonPath = "C:\Users\Administrator\clawd\agents\workspace-gid\data\tech\hacker-news_latest.json"
$mdPath = "C:\Users\Administrator\clawd\agents\workspace-gid\data\tech\hacker-news_latest.md"

$json = Get-Content $jsonPath -Raw | ConvertFrom-Json

$md = @"
# Hacker News Top 30 — $(Get-Date -Format 'yyyy-MM-dd HH:mm') GMT+8

> **采集时间**: $($json.采集时间) | **数量**: $($json.数量) | **来源**: HN Front Page
> **链接**: https://news.ycombinator.com/

---

"@

if ($json.items) {
    $i = 1
    foreach ($item in $json.items) {
        $title = $item.title
        $score = $item.score
        $author = $item.by
        $comments = if ($item.descendants) { $item.descendants } else { 0 }
        $url = if ($item.url) { $item.url } else { "https://news.ycombinator.com/item?id=$($item.id)" }
        $hnUrl = "https://news.ycombinator.com/item?id=$($item.id)"
        
        $md += "### $i. $title`n`n"
        $md += "- **Score**: $score | **Comments**: $comments | **By**: $author`n"
        $md += "- 🔗 [Article]($url) | 💬 [HN Discussion]($hnUrl)`n`n"
        $i++
    }
}

$md | Out-File -FilePath $mdPath -Encoding UTF8
Write-Host "[OK] hacker-news_latest.md 已更新，共 $($json.数量) 条"
Write-Host "[OK] 路径: $mdPath"
