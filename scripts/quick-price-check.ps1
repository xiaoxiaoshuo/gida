# quick-price-check.ps1
$ErrorActionPreference = "Continue"
$results = @()

try {
    $btc = Invoke-RestMethod -Uri "https://min-api.cryptocompare.com/data/price?fsym=BTC&tsyms=USD" -TimeoutSec 10
    $results += "BTC:$($btc.USD)"
} catch {
    $results += "BTC:FAILED"
}

try {
    $eth = Invoke-RestMethod -Uri "https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD" -TimeoutSec 10
    $results += "ETH:$($eth.USD)"
} catch {
    $results += "ETH:FAILED"
}

try {
    $sol = Invoke-RestMethod -Uri "https://min-api.cryptocompare.com/data/price?fsym=SOL&tsyms=USD" -TimeoutSec 10
    $results += "SOL:$($sol.USD)"
} catch {
    $results += "SOL:FAILED"
}

$results | ForEach-Object { Write-Host $_ }
