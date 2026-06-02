try {
    $r = Invoke-WebRequest -Uri 'https://api.alternative.me/fng/?limit=1&format=json' -TimeoutSec 10 -UseBasicParsing
    Write-Host "FNG_OK: $($r.Content)"
} catch {
    Write-Host "FNG_FAILED: $($_.Exception.Message)"
}
