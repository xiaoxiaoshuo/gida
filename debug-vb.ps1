$ErrorActionPreference = "Continue"
$rss = Invoke-RestMethod 'https://venturebeat.com/category/ai/feed/' -TimeoutSec 15
Write-Host "=== VentureBeat Debug ==="
Write-Host "rss.Count:" $rss.Count
Write-Host "rss[0].LocalName:" $rss[0].LocalName
Write-Host "rss.channel.item.Count:" $rss.channel.item.Count
$items = $rss.channel.item | Select-Object -First 3
foreach ($item in $items) {
    Write-Host "--- item ---"
    Write-Host "item.LocalName:" $item.LocalName
    Write-Host "item.title type:" $item.title.GetType().FullName
    Write-Host "item.title value:" $item.title
    Write-Host "item.title[0]:" $item.title[0]
    Write-Host "item.link:" $item.link
    Write-Host "item.pubDate:" $item.pubDate
    Write-Host "item.description length:" $item.description.Length
}
