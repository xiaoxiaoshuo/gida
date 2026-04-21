$ErrorActionPreference = "Continue"

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

# VentureBeat
Write-Host "=== VentureBeat ==="
$rss = Invoke-RestMethod 'https://venturebeat.com/category/ai/feed/' -TimeoutSec 15
Write-Host "Count:" $rss.Count
Write-Host "rss[0] name:" $rss[0].LocalName
if ($rss[0].item) { Write-Host "rss[0].item exists, count:" $rss[0].item.Count }
if ($rss.channel) { Write-Host "rss.channel exists, count:" $rss.channel.item.Count }
if ($rss.channel.item) {
    $items = $rss.channel.item | Select-Object -First 3
    foreach ($i in $items) {
        Write-Host "Title:" (Get-SafeTitle $i)
    }
}

# The Verge (Atom)
Write-Host "=== The Verge ==="
$rss2 = Invoke-RestMethod 'https://www.theverge.com/rss/index.xml' -TimeoutSec 15
Write-Host "Count:" $rss2.Count
Write-Host "rss2[0] name:" $rss2[0].LocalName
if ($rss2.entry) { Write-Host "rss2.entry exists, count:" $rss2.entry.Count }
if ($rss2[0].entry) { Write-Host "rss2[0].entry exists, count:" $rss2[0].entry.Count }
if ($rss2.channel) { Write-Host "rss2.channel exists" }

# Slashdot
Write-Host "=== Slashdot ==="
$rss3 = Invoke-RestMethod 'https://rss.slashdot.org/Slashdot/slashdotMain' -TimeoutSec 15
Write-Host "Count:" $rss3.Count
Write-Host "rss3[0] name:" $rss3[0].LocalName
if ($rss3.item) { Write-Host "rss3.item exists, count:" $rss3.item.Count }
if ($rss3.channel) { Write-Host "rss3.channel exists" }
