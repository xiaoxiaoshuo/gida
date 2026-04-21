$json = Get-Content "C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\ai-news_latest.json" -Raw | ConvertFrom-Json
$md = @"
# AI/ML News — $(Get-Date -Format 'yyyy-MM-dd')

> Top stories in AI/ML · Source: Multi-RSS · Updated: $($json.timestamp)

---

"@

if ($json.sources) {
    $sourceList = $json.sources | ForEach-Object { "- [$($_.name)]($($_.url))" } | Join-String -Separator "`n"
    $md += "**Sources:**`n$sourceList`n`n---\`n`n"
}

if ($json.articles) {
    $i = 1
    foreach ($article in $json.articles) {
        $title = $article.title -replace '\*\*', '' -replace '\[`"'']', ''
        $md += "### $i. $title`n`n"
        if ($article.summary) { $md += "$($article.summary)`n`n" }
        if ($article.url) { $md += "🔗 [Source]($($article.url))`n`n" }
        if ($article.source) { $md += "*来源: $($article.source)*`n`n" }
        $md += "---\`n`n"
        $i++
    }
}

$mdFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\ai-news_latest.md"
$md | Out-File -FilePath $mdFile -Encoding UTF8
Write-Host "[OK] ai-news_latest.md 已更新"