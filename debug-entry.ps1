$ErrorActionPreference = "Continue"

# The Verge - check entry structure
Write-Host "=== The Verge ==="
$rss = Invoke-RestMethod 'https://www.theverge.com/rss/index.xml' -TimeoutSec 15
Write-Host "Count:" $rss.Count
Write-Host "First entry LocalName:" $rss[0].LocalName
Write-Host "Has entry:" ($rss.entry -ne $null)
Write-Host "entry count:" $rss.entry.Count
Write-Host "First entry title type:" $rss.entry[0].title.GetType().FullName
Write-Host "First entry title value:" $rss.entry[0].title
Write-Host "First entry link:" $rss.entry[0].link
Write-Host "First entry updated:" $rss.entry[0].updated
Write-Host "First entry summary:" $rss.entry[0].summary

# Slashdot
Write-Host "=== Slashdot ==="
[xml]$slash = Invoke-WebRequest 'https://rss.slashdot.org/Slashdot/slashdotMain' -TimeoutSec 15 | Select-Object -ExpandProperty Content
Write-Host "Slashdot item count:" $slash.RDF.Item.Count
if ($slash.RDF.Item) {
    Write-Host "First title:" $slash.RDF.Item[0].title
    Write-Host "First link:" $slash.RDF.Item[0].link.'#text'
}
