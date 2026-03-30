Add-Type -AssemblyName System.Web
function Invoke-SafeFetch {
    param([string]$Url, [int]$Timeout = 10)
    try {
        $headers = @{ "User-Agent" = "Mozilla/5.0" }
        $r = Invoke-WebRequest -Uri $Url -Headers $headers -TimeoutSec $Timeout -UseBasicParsing
        return @{ ok = $true; content = $r.Content; len = $r.Content.Length }
    } catch {
        return @{ ok = $false; error = $_.Exception.Message }
    }
}

# Test GoldAPI.io (free tier, no key)
$r = Invoke-SafeFetch -Url "https://www.goldapi.io/api/XAU/USD" -Timeout 15
Write-Host "GoldAPI: ok=$($r.ok) len=$($r.len)"
if ($r.ok) { Write-Host $r.content.Substring(0, [Math]::Min(200, $r.content.Length)) }

# Test metals-api.com free endpoint
$r2 = Invoke-SafeFetch -Url "https://metals-api.com/api/latest?access_key=free&base=USD&symbols=gold" -Timeout 15
Write-Host "metals-api: ok=$($r2.ok) len=$($r2.len)"
if ($r2.ok) { Write-Host $r2.content.Substring(0, [Math]::Min(200, $r2.content.Length)) }

# Test Goldprice.org API endpoint
$r3 = Invoke-SafeFetch -Url "https://data.goldprice.org/dbXRates" -Timeout 15
Write-Host "Goldprice.org API: ok=$($r3.ok) len=$($r3.len)"
if ($r3.ok) { Write-Host $r3.content.Substring(0, [Math]::Min(300, $r3.content.Length)) }
