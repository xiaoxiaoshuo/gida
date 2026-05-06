$base = "C:\Users\Administrator\clawd\agents\workspace-gid"
$hn = Get-Content "$base\data\tech\hacker-news_latest.json" | ConvertFrom-Json
$github = Get-Content "$base\data\ai\github-trending-2026-05-06.json" | ConvertFrom-Json
$anthropic = Get-Content "$base\data\ai\anthropic-blog_latest.json" | ConvertFrom-Json
$existing = Get-Content "$base\data\ai\ai-news_latest.json" | ConvertFrom-Json

# Convert HN items
$hnItems = @()
foreach ($item in $hn.items) {
    $dateStr = [DateTimeOffset]::FromUnixTimeSeconds($item.time).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $hnItems += @{
        date = $dateStr
        source = "Hacker News"
        url = if ($item.url) { $item.url } else { "https://news.ycombinator.com/item?id=$($item.id)" }
        title = $item.title
        desc = ""
    }
}

# Convert GitHub trending to repos
$repos = @()
foreach ($r in $github) {
    $repos += @{
        rank = $r.rank
        repo = $r.repo
        description = $r.description
        stars = $r.stars
        forks = $r.forks
        today_stars = $r.today_stars
        url = $r.url
        built_by = $r.built_by
    }
}

# Convert Anthropic blog to sources format
$anthropicSource = @{
    name = "Anthropic Blog"
    url = "https://www.anthropic.com/news"
    posts = @()
}
foreach ($post in $anthropic) {
    $anthropicSource.posts += @{
        title = $post.title
        url = $post.url
        date = $post.date
        category = $post.category
        summary = $post.summary
    }
}

# Build new sources array (replace Slashdot with Anthropic)
$newSources = @()
foreach ($s in $existing.sources) {
    if ($s.name -ne "Slashdot") {
        $newSources += $s
    }
}
$newSources += $anthropicSource

# Total count
$totalCount = $hnItems.Count + $repos.Count

# Build final object
$newObj = @{
    timestamp = "2026-05-06T04:54:00Z"
    count = $totalCount
    items = $hnItems
    repos = $repos
    sources = $newSources
}

$newObj | ConvertTo-Json -Depth 20 | Set-Content "$base\data\ai\ai-news_latest.json" -Encoding UTF8
Write-Host "Done. Total items: $($hnItems.Count), repos: $($repos.Count)"
