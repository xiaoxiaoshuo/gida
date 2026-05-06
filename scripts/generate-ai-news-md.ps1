$data = Get-Content 'C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\ai-news_latest.json' | ConvertFrom-Json

$timestamp = [DateTimeOffset]::Parse($data.timestamp).ToString('MM/dd/yyyy HH:mm:ss')

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# AI News Latest")
[void]$sb.AppendLine()
[void]$sb.AppendLine("**更新时间**: $timestamp | **总计**: $($data.count) 条")
[void]$sb.AppendLine()
[void]$sb.AppendLine("## Hacker News Top 30")
[void]$sb.AppendLine()

$i = 1
foreach ($item in $data.items) {
    $date = [DateTimeOffset]::Parse($item.date).ToString('MM/dd/yyyy HH:mm:ss')
    [void]$sb.AppendLine("$i. [$($item.title)]($($item.url)) (Hacker News · $date)")
    $i++
}

[void]$sb.AppendLine()
[void]$sb.AppendLine("## GitHub Trending ($([DateTime]::Today.ToString('yyyy-MM-dd')))")
[void]$sb.AppendLine()

foreach ($repo in $data.repos) {
    $stars = if ($repo.stars -ge 1000) { "$([math]::Round($repo.stars/1000, 1))k" } else { $repo.stars }
    $desc = if ($repo.description) { $repo.description } else { "" }
    [void]$sb.AppendLine("- **[$($repo.repo)]($($repo.url))** ⭐ $stars | Today: +$($repo.today_stars) — $desc")
}

$markdown = $sb.ToString()
$markdown | Set-Content 'C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\ai-news_latest.md' -Encoding UTF8
Write-Host "Markdown updated: $($data.count) items"