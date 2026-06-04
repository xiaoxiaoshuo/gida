function get-Title {
    param($url)
    $r = Invoke-WebRequest -Uri $url -Headers @{'User-Agent'='Mozilla/5.0'} -TimeoutSec 8 -UseBasicParsing
    if ($r.Content -match '<title>([^<]+)</title>') { return $Matches[1] }
    return 'NO TITLE'
}
$syms = @('MSFT','GOOGL','META','MSTR','COIN','IBIT','FBTC','TSLA','.SPX','.RUT','.VIX')
foreach ($s in $syms) {
    try {
        $t = get-Title "https://www.cnbc.com/quotes/$s"
        Write-Output "$s : $t"
    } catch {
        Write-Output "$s : ERR $($_.Exception.Message)"
    }
}
