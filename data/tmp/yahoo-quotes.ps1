$symbols = @('NVDA','AAPL','MSFT','GOOGL','META','AMZN','MSTR','COIN','IBIT','FBTC','^NDX','^DJI','^GSPC','^RUT','BTC-USD','ETH-USD')
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
foreach ($sym in $symbols) {
    try {
        $uri = "https://query1.finance.yahoo.com/v8/finance/chart/$([uri]::EscapeDataString($sym))?interval=5m&range=2d"
        $r = Invoke-RestMethod -Uri $uri -Headers @{'User-Agent'='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'} -TimeoutSec 15
        if ($r.chart.error) { Write-Output "$sym : ERR-API $($r.chart.error.code)"; continue }
        $m = $r.chart.result[0].meta
        $prev = [double]$m.chartPreviousClose
        $price = [double]$m.regularMarketPrice
        $chg = $price - $prev
        $pct = if ($prev -ne 0) { ($chg / $prev * 100) } else { 0 }
        $time = ([DateTime]'1970-01-01').AddSeconds([int64]$m.regularMarketTime).ToLocalTime().ToString('HH:mm')
        $state = $m.marketState
        $dayHigh = $m.regularMarketDayHigh
        $dayLow = $m.regularMarketDayLow
        Write-Output ("{0,-8} {1,10} {2,+8} {3,+7}% dayH={4} dayL={5} time={6} state={7}" -f $sym, $price, $chg, $pct, $dayHigh, $dayLow, $time, $state)
    } catch {
        Write-Output "$sym : EXC $($_.Exception.Message)"
    }
}
