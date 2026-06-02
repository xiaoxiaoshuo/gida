try {
    $r = Invoke-WebRequest -Uri 'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,solana&vs_currencies=usd&include_24hr_change=true' -TimeoutSec 10 -UseBasicParsing
    Write-Host "CoinGecko_OK: $($r.Content)"
} catch {
    Write-Host "CoinGecko_FAILED: $($_.Exception.Message)"
}
