$ErrorActionPreference = "SilentlyContinue"
$WorkDir = "C:\Users\Administrator\clawd\agents\workspace-gid"

# 尝试多个RSS源获取AI新闻
$sources = @(
    @{name="TechCrunch AI"; url="https://techcrunch.com/category/artificial-intelligence/feed/"},
    @{name="MIT Technology Review"; url="https://www.technologyreview.com/feed/"},
    @{name="VentureBeat AI"; url="https://venturebeat.com/category/ai/feed/"},
    @{name="The Verge AI"; url="https://www.theverge.com/rss/ai-artificial-intelligence/index.xml"}
)

$allItems = @()
$sourceResults = @()

foreach ($src in $sources) {
    try {
        $rss = Invoke-RestMethod $src.url -TimeoutSec 15
        if ($rss -and $rss.Count -gt 0) {
            $count = 0
            foreach ($item in $rss | Select-Object -First 10) {
                $allItems += @{
                    source = $src.name
                    title = $item.title
                    url = $item.link
                    date = $item.pubDate
                    desc = if ($item.description) { $item.description -replace '<[^>]+>', '' -replace '\s+', ' ' } else { "" }
                }
                $count++
            }
            $sourceResults += @{name=$src.name; status="ok"; count=$count}
            Write-Host "[OK] $($src.name): $($count)条"
        }
    } catch {
        $sourceResults += @{name=$src.name; status="fail"; error=$_.Exception.Message}
        Write-Host "[FAIL] $($src.name): $($_.Exception.Message)"
    }
}

# 保存结果
$output = @{
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    sources = $sourceResults
    count = $allItems.Count
    items = $allItems | Select-Object -First 50
}

$OutputFile = "$WorkDir\data\ai\ai-news_latest.json"
$output | ConvertTo-Json -Depth 5 | Out-File $OutputFile -Encoding UTF8

# 备份
$backup = "$WorkDir\data\ai\ai-news-$(Get-Date -Format 'yyyy-MM-dd').json"
Copy-Item $OutputFile $backup -Force

Write-Host "`n[OK] 共采集 $($allItems.Count) 条新闻"
Write-Host "[OK] 保存到 $OutputFile"