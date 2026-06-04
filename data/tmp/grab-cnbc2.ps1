$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Net.Http
$client = New-Object System.Net.Http.HttpClient
$client.DefaultRequestHeaders.Add('User-Agent','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36')
$client.Timeout = [TimeSpan]::FromSeconds(10)
$syms = @('MSFT','GOOGL','META','MSTR','COIN','IBIT','FBTC','TSLA','.SPX','.RUT','.VIX','NVDA','AAPL','AMZN','.NDX','.DJI','BTC-USD','ETH-USD')
$out = @()
foreach ($s in $syms) {
    try {
        $url = "https://www.cnbc.com/quotes/$s"
        $r = $client.GetAsync($url).GetAwaiter().GetResult()
        $html = $r.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $m = [regex]::Match($html, '<title>([^<]+)</title>')
        $title = $m.Groups[1].Value
        $out += "$s : $title"
    } catch {
        $out += "$s : ERR $($_.Exception.Message)"
    }
}
$out | ForEach-Object { Write-Output $_ }
