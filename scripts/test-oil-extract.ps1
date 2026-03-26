$ErrorActionPreference = "Continue"
$content = Get-Content -Path "C:\Users\Administrator\clawd\agents\workspace-gid\data\market\oil-raw-test.txt" -Raw

# Find WTI price context
if ($content -match '.{200}WTI.{200}') {
    Write-Host "=== WTI Context ==="
    Write-Host $matches[0]
}

# Try JSON data extraction
if ($content -match 'var\s+.*?price.*?=.*?([0-9]{2,3}\.[0-9]{2})') {
    Write-Host "JS Price: $($matches[1])"
}

# Try data attributes
if ($content -match 'data-price="([0-9]+\.[0-9]+)"') {
    Write-Host "Data-price: $($matches[1])"
}

# Look for script with price data
if ($content -match 'price.*?(\d{2,3}\.\d{2})' -replace "`n", "") {
    Write-Host "Price in script: $($matches[1])"
}

# Try oilprice.com/oil-price-charts/ which was in the original script
Write-Host ""
Write-Host "=== Trying oilprice.com/oil-price-charts/ ==="
$r = Invoke-WebRequest -Uri "https://oilprice.com/oil-price-charts/" -TimeoutSec 15 -UseBasicParsing
Write-Host "Length:" $r.Content.Length

if ($r.Content -match 'WTI\s*Crude\s*\n\s*([0-9]+\.[0-9]{2})') {
    Write-Host "WTI Price:" $matches[1]
}
if ($r.Content -match 'WTI\s*Crude[^$]*?\$([0-9]{2,3}\.[0-9]{2})') {
    Write-Host "WTI Price v2:" $matches[1]
}

# Save raw for inspection
$r.Content | Out-File -FilePath "C:\Users\Administrator\clawd\agents\workspace-gid\data\market\oilcharts-raw.txt" -Encoding UTF8
Write-Host "Saved oilprice charts page"

# Try with more specific pattern
$oilContent = $r.Content
if ($oilContent -match 'WTI Crude[\s\S]{0,100}?(\d{2,3}\.\d{2})') {
    Write-Host "WTI within 100 chars:" $matches[1]
}
