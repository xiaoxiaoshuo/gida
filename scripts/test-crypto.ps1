$ErrorActionPreference = "Continue"

# Test crypto prices
Write-Host "=== Crypto Prices ==="
$r = Invoke-WebRequest -Uri "https://min-api.cryptocompare.com/data/price?fsym=BTC&tsyms=USD" -TimeoutSec 10 -UseBasicParsing
Write-Host "CryptoCompare BTC:" $r.Content

$r2 = Invoke-WebRequest -Uri "https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD" -TimeoutSec 10 -UseBasicParsing
Write-Host "CryptoCompare ETH:" $r2.Content

$r3 = Invoke-WebRequest -Uri "https://min-api.cryptocompare.com/data/price?fsym=SOL&tsyms=USD" -TimeoutSec 10 -UseBasicParsing
Write-Host "CryptoCompare SOL:" $r3.Content

Write-Host ""
Write-Host "=== OKX ==="
$okx1 = Invoke-WebRequest -Uri "https://www.okx.com/api/v5/market/ticker?instId=BTC-USDT" -TimeoutSec 10 -UseBasicParsing
$j1 = $okx1.Content | ConvertFrom-Json
Write-Host "OKX BTC:" $j1.data[0].last

$okx2 = Invoke-WebRequest -Uri "https://www.okx.com/api/v5/market/ticker?instId=ETH-USDT" -TimeoutSec 10 -UseBasicParsing
$j2 = $okx2.Content | ConvertFrom-Json
Write-Host "OKX ETH:" $j2.data[0].last

$okx3 = Invoke-WebRequest -Uri "https://www.okx.com/api/v5/market/ticker?instId=SOL-USDT" -TimeoutSec 10 -UseBasicParsing
$j3 = $okx3.Content | ConvertFrom-Json
Write-Host "OKX SOL:" $j3.data[0].last

Write-Host ""
Write-Host "=== Fear & Greed ==="
$fng = Invoke-WebRequest -Uri "https://api.alternative.me/fng/" -TimeoutSec 10 -UseBasicParsing
$fngJson = $fng.Content | ConvertFrom-Json
Write-Host "FNG Value:" $fngJson.data[0].value
Write-Host "FNG Classification:" $fngJson.data[0].value_classification

Write-Host ""
Write-Host "=== GOLD ==="
$gold = Invoke-WebRequest -Uri "https://goldprice.org/" -TimeoutSec 15 -UseBasicParsing
Write-Host "Goldprice.org content length:" $gold.Content.Length

# Try extract gold price
if ($gold.Content -match 'data-price="([0-9]+\.[0-9]+)"') {
    Write-Host "Gold (data-price):" $matches[1]
}
if ($gold.Content -match 'last.*?([0-9]{3,4}\.[0-9]{2})') {
    Write-Host "Gold (last):" $matches[1]
}
if ($gold.Content -match '>([0-9]{4}\.[0-9]{2})<') {
    Write-Host "Gold (4xxx):" $matches[1]
}
