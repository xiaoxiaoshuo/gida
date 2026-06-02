try {
    $r = Invoke-WebRequest -Uri 'https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT' -TimeoutSec 8 -UseBasicParsing
    Write-Host "Binance_BTC: $($r.Content)"
    $r2 = Invoke-WebRequest -Uri 'https://api.binance.com/api/v3/ticker/price?symbol=ETHUSDT' -TimeoutSec 8 -UseBasicParsing
    Write-Host "Binance_ETH: $($r2.Content)"
    $r3 = Invoke-WebRequest -Uri 'https://api.binance.com/api/v3/ticker/price?symbol=SOLUSDT' -TimeoutSec 8 -UseBasicParsing
    Write-Host "Binance_SOL: $($r3.Content)"
} catch {
    Write-Host "Binance_FAILED: $($_.Exception.Message)"
}
