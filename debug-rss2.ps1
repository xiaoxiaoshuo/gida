# Test Get-Text with real RSS data
[xml]$vb = (Invoke-WebRequest 'https://venturebeat.com/category/ai/feed/' -TimeoutSec 15 -UseBasicParsing).Content
$item = $vb.rss.channel.item[0]

Write-Host "=== Testing Get-Text ==="
Write-Host "title.InnerText: [$($item.title.InnerText)]"
Write-Host "link href: [$($item.link.href)]"
Write-Host "link.'#text': [$($item.link.'#text')]"
Write-Host "description.InnerText (first 100): [$($item.description.InnerText.Substring(0, [Math]::Min(100, $item.description.InnerText.Length)))]"

Write-Host ""
Write-Host "=== Testing Get-Text function ==="
function Get-Text {
    param($obj)
    if ($null -eq $obj) { return "" }
    if ($obj -is [string]) { return $obj.Trim() }
    if ($obj -is [System.Xml.XmlElement]) {
        if ($obj.InnerText) { return $obj.InnerText.Trim() }
        if ($obj.FirstChild -and $obj.FirstChild.'#text') { return $obj.FirstChild.'#text'.Trim() }
        if ($obj.FirstChild -and $obj.FirstChild.Value) { return $obj.FirstChild.Value.Trim() }
        return ""
    }
    if ($obj.'#text') { return $obj.'#text'.Trim() }
    return [string]$obj
}

Write-Host "Get-Text title: [$($item | Get-Text)]"
Write-Host "Get-Text link: [$($item.link | Get-Text)]"
Write-Host "Get-Text description (first 100): [$($item.description | Get-Text | Substring(0, 100))]"
