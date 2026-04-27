# Test Get-Text with real RSS data
[xml]$vb = Invoke-WebRequest 'https://venturebeat.com/category/ai/feed/' -TimeoutSec 15 -UseBasicParsing
$item = $vb.rss.channel.item[0]

Write-Host "=== Testing Get-Text ==="
Write-Host "title type from property: " $item.title.GetType().FullName
Write-Host "title.PSObject.BaseObject type: " $item.title.PSObject.BaseObject.GetType().FullName
Write-Host "title direct .InnerText: [" $item.title.InnerText "]"
Write-Host "title via PSObject.BaseObject.InnerText: [" $item.title.PSObject.BaseObject.InnerText "]"

# What does the script actually see?
$titleObj = $item.title
Write-Host ""
Write-Host "After `$titleObj = `$item.title"
Write-Host "type: " $titleObj.GetType().FullName
Write-Host "Is XmlElement? " ($titleObj -is [System.Xml.XmlElement])
Write-Host "Is PSObject? " ($titleObj -is [System.Management.Automation.PSObject])

# What does [string] do?
Write-Host ""
Write-Host "string: [" + [string]$titleObj + "]"
Write-Host "[string] type: " ([string]$titleObj).GetType().FullName

Write-Host ""
Write-Host "=== Testing function directly ==="
function Get-Text {
    param($obj)
    if ($null -eq $obj) { return "NULL" }
    if ($obj -is [string]) { return "STRING: [$($obj.Trim())]" }
    if ($obj -is [System.Xml.XmlElement]) {
        if ($obj.InnerText) { return "XMLELEMENT: [$($obj.InnerText.Trim())]" }
        return "XMLELEMENT_EMPTY"
    }
    if ($obj.'#text') { return "HASHTEXT: [$($obj.'#text'.Trim())]" }
    return "OTHER: [$($obj.ToString())]"
}

Write-Host "Get-Text title: " (Get-Text $item.title)
Write-Host "Get-Text link: " (Get-Text $item.link)
Write-Host "Get-Text description: " (Get-Text $item.description)

Write-Host ""
Write-Host "=== Testing what script sees (assign to var first) ==="
$titleVar = $item.title
$linkVar = $item.link
$descVar = $item.description
Write-Host "title type after assignment: " $titleVar.GetType().FullName
Write-Host "Get-Text titleVar: " (Get-Text $titleVar)
Write-Host "Get-Text linkVar: " (Get-Text $linkVar)
Write-Host "Get-Text descVar: " (Get-Text $descVar)
