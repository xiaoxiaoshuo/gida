# Test API connectivity
$ErrorActionPreference = "Continue"
Add-Type -AssemblyName System.Web

function Invoke-SafeFetch {
    param([string]$Url, [int]$Timeout = 10)
    try {
        $headers = @{ "User-Agent" = "Mozilla/5.0" }
        $r = Invoke-WebRequest -Uri $Url -Headers $headers -TimeoutSec $Timeout -UseBasicParsing -AllowInsecureRedirect
        return @{ ok = $true; content = $r.Content; status = $r.StatusCode }
    } catch {
        return @{ ok = $false; error = $_.Exception.Message.Substring(0,80); status = 0 }
    }
}

Write-Host "=== Gate.io BTC ==="
$r = Invoke-SafeFetch -Url "https://api.gateio.ws/api/v4/spot/tickers?currency_pair=BTC_USDT"
if ($r.ok) {
    $j = $r.content | ConvertFrom-Json
    Write-Host ("LAST:" + $j[0].last)
} else { Write-Host "FAIL" }

Write-Host "=== OKX BTC ==="
$r2 = Invoke-SafeFetch -Url "https://www.okx.com/api/v5/market/ticker?instId=BTC-USDT"
if ($r2.ok) {
    $j2 = $r2.content | ConvertFrom-Json
    Write-Host ("LAST:" + $j2.data[0].last)
} else { Write-Host "FAIL" }

Write-Host "=== alternative.me FNG ==="
$r3 = Invoke-SafeFetch -Url "https://api.alternative.me/fng/"
if ($r3.ok) {
    Write-Host $r3.content
} else { Write-Host "FAIL" }
