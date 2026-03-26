# browser-price-collector.ps1
# 修复版：OKX API + 黄金/原油/F&G 采集
# 2026-03-26 | 修复：alternative.me API 404，改用页面抓取

$ErrorActionPreference = 'SilentlyContinue'
$workDir = "C:\Users\Administrator\clawd\agents\workspace-gid"

$results = @{
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    timestamp_iso = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    crypto = @{}
    macro = @{}
    errors = @()
}

# ========== 1. OKX API (BTC/ETH/SOL) ==========
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
        $results.errors += "OKX_API_FAILED: $($_.Exception.Message.Substring(0, [Math]::Min(100, $_.Exception.Message.Length)))"
    }
} finally {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $certPolicy
}

# ========== 2. Fear&Greed Index (alternative.me 页面抓取) ==========
# 2026-03-26: 修复正则 - Now/分类/值在三个独立元素中
try {
    $fgPage = Invoke-WebRequest 'https://alternative.me/crypto/fear-and-greed-index/' -TimeoutSec 10 -UseBasicParsing
    $html = $fgPage.Content
    # 匹配 Now → 分类 → 数值（三元素结构）
    if ($html -match '(?s)Now.{0,200}?(Extreme\s+Fear|Extreme\s+Greed|Fear|Greed|Neutral).{0,50}?<[^>]+>(\d{1,3})<') {
        $fgClass = $matches[1].Trim()
        $fgValue = [int]$matches[2]
        $results.macro.FNG = @{
            value = $fgValue
            classification = $fgClass
            source = "alternative.me_page"
            confidence = "medium"
        }
    } elseif ($html -match '(?s)Now.{0,200}?(\d{1,3}).{0,50}?(Extreme\s+Fear|Extreme\s+Greed|Fear|Greed|Neutral)') {
        # 备选：数值在前
        $fgValue = [int]$matches[1]
        $fgClass = $matches[2].Trim()
        $results.macro.FNG = @{
            value = $fgValue
            classification = $fgClass
            source = "alternative.me_page"
            confidence = "medium"
        }
    } elseif ($html -match '>Now<.*?>(\d+)<') {
        # 最简匹配：找>Now<之后的第一个数字
        $fgValue = [int]$matches[1]
        $results.macro.FNG = @{
            value = $fgValue
            classification = "Unknown"
            source = "alternative.me_page"
            confidence = "low"
        }
    }
} catch {
    $results.errors += "FNG_FAILED: $($_.Exception.Message.Substring(0,50))"
}

# ========== 3. 黄金价格 (goldprice.org) ==========
try {
    $goldPage = Invoke-WebRequest 'https://goldprice.org/' -TimeoutSec 10 -UseBasicParsing
    if ($goldPage.Content -match 'spotPrice[^>]*>[\$]?([0-9,]+\.?\d*)') {
        $g = [double]($matches[1] -replace ',', '')
        if ($g -gt 1000) { $results.macro.GOLD = @{ value = $g; source = "goldprice.org"; unit = "USD/oz" } }
    } elseif ($goldPage.Content -match '(\d{1,3}(?:,\d{3})*(?:\.\d+)?)\s*(?:USD|oz|dollar)') {
        $g = [double]($matches[1] -replace ',', '')
        if ($g -gt 1000) { $results.macro.GOLD = @{ value = $g; source = "goldprice.org"; unit = "USD/oz" } }
    }
} catch {
    $results.errors += "GOLD_FAILED"
}

# ========== 4. 原油价格 (oilprice.com) ==========
try {
    $oilPage = Invoke-WebRequest 'https://oilprice.com/' -TimeoutSec 10 -UseBasicParsing
    if ($oilPage.Content -match '(\d{1,3}(?:\.\d+)?)\s*(?:USD|WTI|Brent|Oil|barrel)') {
        $o = [double]$matches[1]
        if ($o -gt 20 -and $o -lt 200) { $results.macro.OIL = @{ value = $o; source = "oilprice.com"; unit = "USD/barrel" } }
    }
} catch {
    $results.errors += "OIL_FAILED"
}

# ========== 保存 ==========
$jsonStr = $results | ConvertTo-Json -Depth 5
$timeStr = Get-Date -Format 'yyyy-MM-dd_HH-mm'
$jsonStr | Set-Content "$workDir\data\market\prices_$timeStr.json" -Encoding UTF8
$jsonStr | Set-Content "$workDir\data\market\prices_latest.json" -Encoding UTF8

Write-Host "=== browser-price-collector | $(Get-Date -Format 'HH:mm:ss') ==="
Write-Host "BTC: $($results.crypto.BTC.price) | ETH: $($results.crypto.ETH.price) | SOL: $($results.crypto.SOL.price)"
Write-Host "F&G: $($results.macro.FNG.value) ($($results.macro.FNG.classification))"
Write-Host "GOLD: $($results.macro.GOLD.value) | OIL: $($results.macro.OIL.value)"
Write-Host "Errors: $($results.errors.Count) - $($results.errors -join ', ')"
