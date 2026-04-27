# Debug VentureBeat RSS
[xml]$xml = (Invoke-WebRequest 'https://venturebeat.com/category/ai/feed/' -TimeoutSec 15 -UseBasicParsing).Content
$item = $xml.rss.channel.item[0]
Write-Host '=== VentureBeat item[0] properties ==='
$item.PSObject.Properties | ForEach-Object { Write-Host "$($_.Name): [$($_.Value)]" }
Write-Host ''
Write-Host '--- title type: ' $item.title.GetType().FullName
Write-Host '--- title value: ' $item.title

# Debug The Verge RSS
[xml]$xml2 = (Invoke-WebRequest 'https://www.theverge.com/rss/index.xml' -TimeoutSec 15 -UseBasicParsing).Content
$entry = $xml2.feed.entry[0]
Write-Host ''
Write-Host '=== The Verge entry[0] properties ==='
$entry.PSObject.Properties | ForEach-Object { Write-Host "$($_.Name): [$($_.Value)]" }
Write-Host ''
Write-Host '--- title type: ' $entry.title.GetType().FullName
Write-Host '--- title value: ' $entry.title
Write-Host '--- link type: ' $entry.link.GetType().FullName
Write-Host '--- link href: ' $entry.link.href
