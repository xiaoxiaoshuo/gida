$ErrorActionPreference = "Continue"
$rss = Invoke-RestMethod 'https://venturebeat.com/category/ai/feed/' -TimeoutSec 15
Write-Host "VB Type:" $rss.GetType().FullName
Write-Host "VB Count:" $rss.Count
if ($rss.channel) { Write-Host "has channel" }
if ($rss.item) { Write-Host "has item"; Write-Host "Item0:" ($rss.item | Select-Object -First 1 | ConvertTo-Json -Depth 2) }
if ($rss[0].PSObject.Properties.Name -contains 'item') { Write-Host "PS: has item" }
$rss[0].PSObject.Properties.Name | ForEach-Object { Write-Host "Prop: $_" }
