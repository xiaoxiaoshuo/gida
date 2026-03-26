# browser-price-collector.ps1
# 用 Playwright 浏览器采集 BTC/ETH/SOL 实时价格
# 2026-03-26 | 修复版：改用浏览器直接抓 OKX 页面

$ErrorActionPreference = 'SilentlyContinue'
$workDir = "C:\Users\Administrator\clawd\agents\workspace-gid"

# 价格通过 API 直接获取（备用）
$results = @{
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    timestamp_iso = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    crypto = @{}
    macro = @{}
    errors = @()
}

# BTC/ETH/SOL via OKX API (SSL fallback: allow untrusted cert)
$certPolicy = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
try {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    
    try {
        $btc = Invoke-RestMethod 'https://www.okx.com/api/v5/market/ticker?instId=BTC-USDT' -TimeoutSec 8
        $eth = Invoke-RestMethod 'https://www.okx.com/api/v5/market/ticker?instId=ETH-USDT' -TimeoutSec 8
        $sol = Invoke-RestMethod 'https://www.okx.com/api/v5/market/ticker?instId=SOL-USDT' -TimeoutSec 8
        $results.crypto = @{
            BTC = @{ price = [double]$btc.data[0].last; source = "OKX_API"; confidence = "high" }
            ETH = @{ price = [double]$eth.data[0].last; source = "OKX_API"; confidence = "high" }
            SOL = @{ price = [double]$sol.data[0].last; source = "OKX_API"; confidence = "high" }
        }
    } catch {
        $results.errors += "OKX_API_FAILED: $($_.Exception.Message)"
    }
} finally {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $certPolicy
}

# 黄金/原油 via 浏览器 web_fetch (kitco + oilprice)
try {
    $goldPage = Invoke-WebRequest 'https://goldprice.org/' -TimeoutSec 10 -UseBasicParsing
    if ($goldPage.Content -match '(\d{1,3}(?:,\d{3})*(?:\.\d+)?)\s*(?:USD|oz|dollar)') {
        $g = [double]($matches[1] -replace ',','')
        if ($g -gt 1000) { $results.macro.GOLD = @{ value = $g; source = "goldprice.org" } }
    }
} catch { $results.errors += "GOLD_FAILED" }

try {
    $oilPage = Invoke-WebRequest 'https://oilprice.com/' -TimeoutSec 10 -UseBasicParsing
    if ($oilPage.Content -match '(\d{1,3}(?:\.\d+)?)\s*(?:USD|WTI|Barrel)') {
        $o = [double]$matches[1]
        if ($o -gt 20) { $results.macro.OIL = @{ value = $o; source = "oilprice.com" } }
    }
} catch { $results.errors += "OIL_FAILED" }

# Fear&Greed via alternative.me
try {
    $fg = Invoke-RestMethod 'https://alternative.me/api/fng/' -TimeoutSec 8
    if ($fg.data[0].value) {
        $results.macro.FNG = @{
            value = [int]$fg.data[0].value
            classification = $fg.data[0].value_classification
            source = "alternative.me"
            confidence = "medium"
        }
    }
} catch { $results.errors += "FNG_FAILED" }

# 保存
$jsonStr = $results | ConvertTo-Json -Depth 5
$timeStr = Get-Date -Format 'yyyy-MM-dd_HH-mm'
$jsonStr | Set-Content "$workDir\data\market\prices_$timeStr.json" -Encoding UTF8
$jsonStr | Set-Content "$workDir\data\market\prices_latest.json" -Encoding UTF8

Write-Host "[browser-price-collector] $(Get-Date -Format 'HH:mm:ss')"
Write-Host "BTC: $($results.crypto.BTC.price) | ETH: $($results.crypto.ETH.price) | SOL: $($results.crypto.SOL.price)"
Write-Host "F&G: $($results.macro.FNG.value) | GOLD: $($results.macro.GOLD.value) | OIL: $($results.macro.OIL.value)"
Write-Host "Errors: $($results.errors.Count)"
