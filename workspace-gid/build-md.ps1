$base = "C:\Users\Administrator\clawd\agents\workspace-gid"
$data = Get-Content "$base\data\ai\ai-news_latest.json" | ConvertFrom-Json

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# AI News Latest")
[void]$sb.AppendLine()
[void]$sb.AppendLine("**更新时间**: $($data.timestamp) | **总计**: $($data.count) 条")
[void]$sb.AppendLine()

# HN Items
[void]$sb.AppendLine("## Hacker News Top 30")
[void]$sb.AppendLine()
$rank = 1
foreach ($item in $data.items) {
    [void]$sb.AppendLine("$rank. [$($item.title)]($($item.url)) ($($item.source) · $($item.date))")
    $rank++
}

# GitHub Trending
[void]$sb.AppendLine()
[void]$sb.AppendLine("## GitHub Trending (2026-05-06)")
[void]$sb.AppendLine()
foreach ($repo in $data.repos) {
    [void]$sb.AppendLine("- **[$($repo.repo)]($($repo.url))** ⭐ $([Math]::Round($repo.stars/1000,1))k | Today: +$($repo.today_stars) — $($repo.description)")
}

# Sources
[void]$sb.AppendLine()
[void]$sb.AppendLine("## Sources")
[void]$sb.AppendLine()
[void]$sb.AppendLine("| 来源 | 状态 |")
[void]$sb.AppendLine("|------|------|")
foreach ($s in $data.sources) {
    [void]$sb.AppendLine("| $($s.name) | $($s.status) |")
}

[void]$sb.AppendLine()
[void]$sb.AppendLine("*自动生成于 $($data.timestamp)*")

$sb.ToString() | Set-Content "$base\data\ai\ai-news_latest.md" -Encoding UTF8
Write-Host "Markdown generated."
