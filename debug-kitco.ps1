$r = Invoke-WebRequest -Uri 'https://www.kitco.com/charts/livegold.html' -Headers @{'User-Agent'='Mozilla/5.0'} -TimeoutSec 12 -UseBasicParsing
Write-Host "LEN:" $r.Content.Length
$r.Content | Select-String -Pattern 'Bid|4,523|4530|gold' -AllMatches | Select-Object -First 10
