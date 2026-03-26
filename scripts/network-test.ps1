$ErrorActionPreference = "Continue"
$results = @{}

# Test various APIs
$tests = @(
    @{ name = "Binance Vision"; url = "https://data.binance.vision/api/v3/ticker/price?symbol=BTCUSDT" },
    @{ name = "CryptoCompare"; url = "https://min-api.cryptocompare.com/data/price?fsym=BTC&tsyms=USD" },
    @{ name = "OKX"; url = "https://www.okx.com/api/v5/market/ticker?instId=BTC-USDT" },
    @{ name = "Goldprice.org"; url = "https://goldprice.org/" },
    @{ name = "Oilprice.com"; url = "https://oilprice.com/" },
    @{ name = "Alternative.me FNG"; url = "https://api.alternative.me/fng/" },
    @{ name = "Yahoo Finance VIX"; url = "https://query1.finance.yahoo.com/v8/finance/chart/%5EVIX?interval=1d&range=1d" },
    @{ name = "Github API"; url = "https://api.github.com/search/repositories?q=stars:%3E1000&per_page=3" }
)

foreach ($t in $tests) {
    try {
        $r = Invoke-WebRequest -Uri $t.url -TimeoutSec 10 -UseBasicParsing
        $results[$t.name] = "OK ($($r.StatusCode), $($r.Content.Length) bytes)"
    } catch {
        $msg = $_.Exception.Message
        if ($msg.Length -gt 100) { $msg = $msg.Substring(0, 100) }
        $results[$t.name] = "FAIL: $msg"
    }
}

$results | ConvertTo-Json -Depth 3
