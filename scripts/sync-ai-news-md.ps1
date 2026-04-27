$json = Get-Content "C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\ai-news_latest.json" -Raw | ConvertFrom-Json
$md = @"
# AI/ML News — $(Get-Date -Format 'yyyy-MM-dd')

> Top stories in AI/ML · Source: Multi-RSS · Updated: $(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')

---

"@

if ($json.items) {
    $i = 1
    foreach ($article in $json.items) {
        $title = $article.title -replace '\*\*', '' -replace '\[`"'']', ''
        $md += "### $i. $title`n`n"
        if ($article.desc) { $md += "$($article.desc)`n`n" }
        if ($article.url) { $md += "🔗 [Source]($($article.url))`n`n" }
        if ($article.source) { $md += "*来源: $($article.source)*`n`n" }
        $md += "---\`n`n"
        $i++
    }
}

$mdFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\ai-news_latest.md"
$md | Out-File -FilePath $mdFile -Encoding UTF8
Write-Host "[OK] ai-news_latest.md 已更新，共 $($json.count) 条新闻"
