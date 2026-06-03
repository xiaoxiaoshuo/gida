# GFW Diagnostic Tool - 2026-06-04 02:27
$results = @()

# Test 1: PowerShell Invoke-WebRequest to api.github.com
$start = Get-Date
try {
    $r = Invoke-WebRequest -Uri 'https://api.github.com/rate_limit' -UseBasicParsing -TimeoutSec 10
    $elapsed = (Get-Date) - $start
    $results += [PSCustomObject]@{
        Test = "PS api.github.com"
        Status = $r.StatusCode
        Time = "$([math]::Round($elapsed.TotalMilliseconds))ms"
        Note = "WinHTTP stack"
    }
} catch {
    $results += [PSCustomObject]@{
        Test = "PS api.github.com"
        Status = "FAIL"
        Time = "-"
        Note = $_.Exception.Message.Substring(0, [Math]::Min(80, $_.Exception.Message.Length))
    }
}

# Test 2: PowerShell to github.com web
$start = Get-Date
try {
    $r = Invoke-WebRequest -Uri 'https://github.com/xiaoxiaoshuo/gida' -UseBasicParsing -TimeoutSec 10 -Method Head
    $elapsed = (Get-Date) - $start
    $results += [PSCustomObject]@{
        Test = "PS github.com web"
        Status = $r.StatusCode
        Time = "$([math]::Round($elapsed.TotalMilliseconds))ms"
        Note = "WinHTTP HEAD"
    }
} catch {
    $results += [PSCustomObject]@{
        Test = "PS github.com web"
        Status = "FAIL"
        Time = "-"
        Note = $_.Exception.Message.Substring(0, [Math]::Min(80, $_.Exception.Message.Length))
    }
}

# Test 3: curl.exe api.github.com
$start = Get-Date
$curlOut = & curl.exe -sS -o NUL -w "HTTP_CODE:%{http_code} TIME:%{time_total}s" --max-time 10 https://api.github.com/rate_limit 2>&1
$elapsed = (Get-Date) - $start
$results += [PSCustomObject]@{
    Test = "curl api.github.com"
    Status = if ($curlOut -match "HTTP_CODE:(\d+)") { $matches[1] } else { "FAIL" }
    Time = "$([math]::Round($elapsed.TotalMilliseconds))ms"
    Note = "schannel/curl stack"
}

# Test 4: git.exe via http.https.proxy (using simple ls-remote)
$start = Get-Date
$gitOut = git ls-remote https://github.com/xiaoxiaoshuo/gida.git HEAD 2>&1
$elapsed = (Get-Date) - $start
$results += [PSCustomObject]@{
    Test = "git ls-remote (OpenSSL)"
    Status = if ($gitOut -match "^[a-f0-9]{40}") { "OK" } else { "FAIL" }
    Time = "$([math]::Round($elapsed.TotalMilliseconds))ms"
    Note = "git.exe OpenSSL TLS"
}

$results | Format-Table -AutoSize | Out-String | Write-Host
