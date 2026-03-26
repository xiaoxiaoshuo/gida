$ErrorActionPreference = "Continue"

Write-Host "=== GOLD (goldprice.org) ==="
$gold = Invoke-WebRequest -Uri "https://goldprice.org/" -TimeoutSec 15 -UseBasicParsing
$content = $gold.Content

# Show relevant snippets
Write-Host "Length:" $content.Length

# Try various patterns
$patterns = @(
    'data-price="([0-9]+\.[0-9]+)"',
    'price.*?([0-9]{4}\.[0-9]{2})',
    '([0-9]{4}\.[0-9]{2})\s*USD',
    'USD.*?([0-9]{4}\.[0-9]{2})',
    'gold.*?price.*?([0-9]{4}\.[0-9]{2})',
    'Last\s*([0-9]{4}\.[0-9]{2})',
    '>([0-9]{4}\.[0-9]{2})<'
)

foreach ($p in $patterns) {
    if ($content -match $p) {
        Write-Host "Pattern '$p' matched: $($matches[1])"
    }
}

# Look for specific section
if ($content -match 'spot-gold-price[^>]*>([^<]+)<') {
    Write-Host "Spot gold: $($matches[1])"
}
if ($content -match 'Gold Price\s*USD\s*([0-9,]+\.[0-9]+)') {
    Write-Host "Gold Price USD: $($matches[1])"
}
if ($content -match 'current gold price[^0-9]*([0-9]{4}\.[0-9]{2})') {
    Write-Host "Current gold: $($matches[1])"
}

# Try Kitco
Write-Host ""
Write-Host "=== GOLD (Kitco) ==="
$kitco = Invoke-WebRequest -Uri "https://www.kitco.com/charts/livegold.html" -TimeoutSec 15 -UseBasicParsing
$kc = $kitco.Content
Write-Host "Kitco Length:" $kc.Length

if ($kc -match 'font-normal">([0-9],[0-9]{3}\.[0-9]{2})') {
    $price = $matches[1] -replace ',',''
    Write-Host "Kitco Gold: $price"
}

Write-Host ""
Write-Host "=== OIL (oilprice.com) ==="
$oil = Invoke-WebRequest -Uri "https://oilprice.com/" -TimeoutSec 15 -UseBasicParsing
$oc = $oil.Content
Write-Host "Oil Length:" $oc.Length

# Look for WTI crude price
if ($oc -match 'WTI\s*Crude[^$]*?\$?([0-9]{2,3}\.[0-9]{2})') {
    Write-Host "WTI (pattern 1): $($matches[1])"
}
if ($oc -match '\$([0-9]{2,3}\.[0-9]{2}).*?WTI') {
    Write-Host "WTI (pattern 2): $($matches[1])"
}
if ($oc -match 'Crude\s*Oil[^$]*?([0-9]{2,3}\.[0-9]{2})') {
    Write-Host "Crude (pattern 3): $($matches[1])"
}
if ($oc -match '>([0-9]{2,3}\.[0-9]{2})<\/a>.*?WTI') {
    Write-Host "WTI (pattern 4): $($matches[1])"
}
if ($oc -match 'WTI\s*Crude[^<]*<[^>]*>([0-9]{2,3}\.[0-9]{2})') {
    Write-Host "WTI (pattern 5): $($matches[1])"
}
if ($oc -match 'class="oilPrice"[^>]*>([^<]+)<') {
    Write-Host "Oil price class: $($matches[1])"
}

# Save raw content for inspection
$oc | Out-File -FilePath "C:\Users\Administrator\clawd\agents\workspace-gid\data\market\oil-raw-test.txt" -Encoding UTF8
$content | Out-File -FilePath "C:\Users\Administrator\clawd\agents\workspace-gid\data\market\gold-raw-test.txt" -Encoding UTF8
Write-Host "Saved raw content for inspection"
