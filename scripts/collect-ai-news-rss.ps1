# collect-ai-news-rss.ps1 - AI新闻多源RSS采集（支持RSS/Atom/RDF + CDATA）
$ErrorActionPreference = "SilentlyContinue"
$WorkDir = "C:\Users\Administrator\clawd\agents\workspace-gid"

# RSS源配置
# 2026-04-21: 扩展至8个源（新增Ars/TechRadar/Wired/Slashdot，Reddit/HN因GWF被屏蔽）
$sources = @(
    @{name="TechCrunch AI"; url="https://techcrunch.com/category/artificial-intelligence/feed/"},
    @{name="MIT Technology Review"; url="https://www.technologyreview.com/feed/"},
    @{name="VentureBeat AI"; url="https://venturebeat.com/category/ai/feed/"},
    @{name="The Verge"; url="https://www.theverge.com/rss/index.xml"},
    @{name="Ars Technica"; url="https://feeds.arstechnica.com/arstechnica/technology-lab"},
    @{name="TechRadar"; url="https://www.techradar.com/rss"},
    @{name="Wired Science"; url="https://www.wired.com/feed/category/science/latest/rss"},
    @{name="Slashdot"; url="https://rss.slashdot.org/Slashdot/slashdotMain"}
)

$allItems = @()
$sourceResults = @()

function Get-Text {
    param($obj)
    if ($null -eq $obj) { return "" }
    if ($obj -is [string]) { return $obj.Trim() }
    if ($obj.'#text') { return $obj.'#text'.Trim() }
    return [string]$obj
}

foreach ($src in $sources) {
    try {
        # 使用 [xml] + Invoke-WebRequest 而非 Invoke-RestMethod（更好处理CDATA）
        $raw = Invoke-WebRequest $src.url -TimeoutSec 15 -UseBasicParsing
        [xml]$xml = $raw.Content

        $items = $null
        $itemPath = "unknown"

        # Atom: <feed><entry>...</entry></feed>
        if ($xml.feed) {
            $items = $xml.feed.entry
            $itemPath = "feed.entry"
        }
        # RSS 2.0: <rss><channel><item>...</item></channel></rss>
        elseif ($xml.rss.channel.item) {
            $items = $xml.rss.channel.item
            $itemPath = "rss.channel.item"
        }
        # RSS/RDF direct items: <rss><item>...</item></rss> or <RDF><item>...</item></RDF>
        elseif ($xml.rss.item) {
            $items = $xml.rss.item
            $itemPath = "rss.item"
        }
        elseif ($xml.RDF -and $xml.RDF.Item) {
            $items = $xml.RDF.Item
            $itemPath = "RDF.Item"
        }
        # Fallback: try first property with items
        else {
            $firstProp = $xml.PSObject.Properties | Where-Object { $_.Value -is [System.Xml.XmlElement] -or $_.Value -is [System.Xml.XmlElement[]] } | Select-Object -First 1
            if ($firstProp -and ($firstProp.Value | Get-Member -MemberType Property).Count -gt 0) {
                $val = $firstProp.Value
                if ($val[0].LocalName -in @("item","entry")) {
                    $items = $val
                    $itemPath = $firstProp.Name
                }
            }
        }

        if ($items -and $items.Count -gt 0) {
            $count = 0
            foreach ($item in $items | Select-Object -First 10) {
                # Atom: title is attribute, link is attribute, summary
                # RSS: title, link, description
                $title = Get-Text $item.title
                $link = Get-Text $item.link
                $desc = (Get-Text $item.summary) ?? (Get-Text $item.description) ?? (Get-Text $item.content)
                $date = (Get-Text $item.updated) ?? (Get-Text $item.pubDate)
                # Handle link as attribute href for Atom
                if (-not $link -and $item.link.href) { $link = $item.link.href }
                if (-not $link -and $item.link -is [string] -and $item.link -match '^https?://') { $link = $item.link }
                if ($title -and $title -ne "" -and $title -ne "System.String[]") {
                    $allItems += @{
                        source = $src.name
                        title = $title
                        url = $link
                        date = $date
                        desc = $desc
                    }
                    $count++
                }
            }
            $sourceResults += @{name=$src.name; status="ok"; count=$count; path=$itemPath}
            Write-Host "[OK] $($src.name) [$itemPath]: $count 条"
        } else {
            $sourceResults += @{name=$src.name; status="parse_fail"; error="无法定位items"}
            Write-Host "[PARSE_FAIL] $($src.name)"
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
