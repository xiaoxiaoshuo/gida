$hn = Get-Content 'C:\Users\Administrator\clawd\agents\workspace-gid\data\tech\hacker-news_latest.json' | ConvertFrom-Json
$gh = Get-Content 'C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\github-trending_latest.json' | ConvertFrom-Json

$now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

# HN items
$hnItems = $hn.items | Where-Object { $_.type -eq 'story' -or $_.type -eq 'job' } | Select-Object -First 30 | ForEach-Object {
    $itemId = $_.id
    @{
        title = $_.title
        source = 'Hacker News'
        url = if ($_.url) { $_.url } else { "https://news.ycombinator.com/item?id=$itemId" }
        date = [DateTimeOffset]::FromUnixTimeSeconds($_.time).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        desc = ''
    }
}

# GH repos
$ghRepos = @()
$rank = 1
$gh.repos | ForEach-Object {
    $repoName = $_.name -replace ' ', '/'
    $ghRepos += @{
        built_by = @()
        stars = $_.stars
        rank = $rank
        repo = $repoName
        forks = 0
        today_stars = $_.stars_today
        description = $_.description
        url = "https://github.com/$repoName"
    }
    $rank++
}

$merged = @{
    count = $hnItems.Count + $ghRepos.Count
    sources = @(
        @{ count = $hnItems.Count; name = 'Hacker News'; path = 'items'; status = 'ok' }
        @{ count = $ghRepos.Count; name = 'GitHub Trending'; path = 'repos'; status = 'ok' }
    )
    items = $hnItems
    repos = $ghRepos
    timestamp = $now
}

$merged | ConvertTo-Json -Depth 10 | Set-Content 'C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\ai-news_latest.json' -Encoding UTF8
Write-Host "Merged JSON saved: $now"
Write-Host "HN items: $($hnItems.Count), GH repos: $($ghRepos.Count)"