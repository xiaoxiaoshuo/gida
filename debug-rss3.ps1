$ErrorActionPreference = "Continue"
[xml]$xml = Invoke-WebRequest 'https://venturebeat.com/category/ai/feed/' -TimeoutSec 15 | Select-Object -ExpandProperty Content
Write-Host "Channel title:" $xml.rss.channel.title
Write-Host "Channel item count:" $xml.rss.channel.item.Count
foreach ($i in $xml.rss.channel.item) {
    Write-Host "Item title:" $i.title
    Write-Host "Item link:" $i.link
    Write-Host "Item pubDate:" $i.pubDate
}
