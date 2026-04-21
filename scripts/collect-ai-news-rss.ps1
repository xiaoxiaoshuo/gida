# collect-ai-news-rss.ps1 - AI新闻多源RSS采集（修复版）
$ErrorActionPreference = "SilentlyContinue"
$WorkDir = "C:\Users\Administrator\clawd\agents\workspace-gid"

# RSS源配置
$sources = @(
    @{name="TechCrunch AI"; url="https://techcrunch.com/category/artificial-intelligence/feed/"},
    @{name="MIT Technology Review"; url="https://www.technologyreview.com/feed/"},
    @{name="VentureBeat AI"; url="https://venturebeat.com/category/ai/feed/"},
    @{name="The Verge AI"; url="https://www.theverge.com/rss/ai-artificial-intelligence/index.xml"}
)

$allItems = @()
$sourceResults = @()

function Get-SafeTitle {
    param($item)
    $title = $item.title
    if ($title -is [array]) { return $title[0] }
    if ($title -is [System.Xml.XmlElement]) { return $title.'#text' }
    return [string]$title
}

function Get-SafeLink {
    param($item)
    $link = $item.link
    if ($link -is [array]) { return $link[0] }
    if ($link -is [System.Xml.XmlElement]) { return $link.'#text' }
    return [string]$link
}

foreach ($src in $sources) {
    try {
        $rss = Invoke-RestMethod $src.url -TimeoutSec 15
        if ($rss -and $rss.Count -gt 0) {
            $count = 0
            foreach ($item in $rss | Select-Object -First 10) {
                $title = Get-SafeTitle $item
                $link = Get-SafeLink $item
                $desc = ""
                if ($item.description) {
                    if ($item.description -is [string]) {
                        $desc = $item.description -replace '<[^>]+>', '' -replace '\s+', ' '
                    } elseif ($item.description.'#text') {
                        $desc = $item.description.'#text' -replace '<[^>]+>', '' -replace '\s+', ' '
                    }
                }
                if ($title -and $title -ne "" -and $title -ne "System.String[]") {
                    $allItems += @{
                        source = $src.name
                        title = $title
                        url = $link
                        date = $item.pubDate
                        desc = $desc
                    }
                    $count++
                }
            }
            $sourceResults += @{name=$src.name; status="ok"; count=$count}
            Write-Host "[OK] $($src.name): $count 条"
        }
    } catch {
        $sourceResults += @{name=$src.name; status="fail"; error=$_.Exception.Message}
        Write-Host "[FAIL] $($src.name): $($_.Exception.Message)"
    }
}

$output = @{
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    sources = $sourceResults
    count = $allItems.Count
    items = $allItems | Select-Object -First 50
}

$OutputFile = "$WorkDir\data\ai\ai-news_latest.json"
$BackupFile = "$WorkDir\data\ai\ai-news-$(Get-Date -Format 'yyyy-MM-dd').json"
$output | ConvertTo-Json -Depth 5 | Out-File $OutputFile -Encoding UTF8
Copy-Item $OutputFile $BackupFile -Force

# 同步markdown版本
& "$WorkDir\scripts\sync-ai-news-md.ps1"

Write-Host "[OK] 共 $($allItems.Count) 条新闻已保存"
exit 0