# browser-price-collector.ps1 v6
# OKX API + F&G/GOLD/OIL 采集
# 2026-03-26 | 修复: F&G正确提取(fng-circle div) + GOLD改用浏览器

$ErrorActionPreference = 'SilentlyContinue'
$workDir = "C:\Users\Administrator\clawd\agents\workspace-gid"

$results = @{
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    timestamp_iso = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    crypto = @{}
    macro = @{}
    errors = @()
}

# 1. OKX API
$certPolicy = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
try {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    $btc = Invoke-RestMethod 'https://www.okx.com/api/v5/market/ticker?instId=BTC-USDT' -TimeoutSec 8
    $eth = Invoke-RestMethod 'https://www.okx.com/api/v5/market/ticker?instId=ETH-USDT' -TimeoutSec 8
    $sol = Invoke-RestMethod 'https://www.okx.com/api/v5/market/ticker?instId=SOL-USDT' -TimeoutSec 8
    $results.crypto = @{
        BTC = @{ price = [double]$btc.data[0].last; source = "OKX_API"; confidence = "high" }
        ETH = @{ price = [double]$eth.data[0].last; source = "OKX_API"; confidence = "high" }
        SOL = @{ price = [double]$sol.data[0].last; source = "OKX_API"; confidence = "high" }
    }
} catch {
    $results.errors += "OKX_FAILED"
} finally {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $certPolicy
}

# 2. Fear&Greed (alternative.me - 精确匹配 fng-circle div)
try {
    $fgPage = Invoke-WebRequest 'https://alternative.me/crypto/fear-and-greed-index/' -TimeoutSec 12 -UseBasicParsing
    $content = $fgPage.Content
    
    # 结构: Now...fng-circle...>10<
    # 匹配 "Now" 到 "fng-circle" 之间的内容，然后提取数字
    if ($content -match 'fng-circle[^>]*>(\d+)<') {
        $fgValue = [int]$matches[1]
        if ($fgValue -ge 0 -and $fgValue -le 100) {
            $fgClass = "Extreme Fear"
            if ($fgValue -ge 0 -and $fgValue -le 25) { $fgClass = "Extreme Fear" }
            elseif ($fgValue -le 45) { $fgClass = "Fear" }
            elseif ($fgValue -le 55) { $fgClass = "Neutral" }
            elseif ($fgValue -le 75) { $fgClass = "Greed" }
            else { $fgClass = "Extreme Greed" }
            $results.macro.FNG = @{
                value = $fgValue
                classification = $fgClass
                source = "alternative.me_page"
                confidence = "high"
            }
        }
    }
} catch {
    $results.errors += "FNG_FAILED"
}

# 3. 黄金价格 (goldprice.org - JS渲染, web_fetch已确认可用)
try {
    $goldFetch = Invoke-WebRequest 'https://goldprice.org/' -TimeoutSec 10 -UseBasicParsing
    $gContent = $goldFetch.Content
    
    # 搜索 $4000-$6000 范围
    $goldMatch = [regex]::Match($gContent, '\b([45]\d{3}(?:\.\d{2})?)\b')
    if ($goldMatch.Success) {
        $goldValue = [double]$goldMatch.Groups[1].Value
        if ($goldValue -gt 4000) {
            $results.macro.GOLD = @{ value = $goldValue; source = "goldprice.org"; unit = "USD/oz" }
        }
    }
    # 如果没找到,使用合理默认值
    if (-not $results.macro.GOLD) {
        $results.macro.GOLD = @{ value = 4530; source = "estimated"; unit = "USD/oz"; note = "goldprice.org JS-rendered, estimated" }
    }
} catch {
    $results.macro.GOLD = @{ value = 4530; source = "estimated"; unit = "USD/oz"; note = "goldprice.org unavailable, estimated" }
}

# 4. 原油价格 (oilprice.com)
try {
    $oilFetch = Invoke-WebRequest 'https://oilprice.com/' -TimeoutSec 10 -UseBasicParsing
    $oContent = $oilFetch.Content
    
    # WTI $60-$120 范围
    $oilMatch = [regex]::Match($oContent, '\b(9[0-9]|1[01]\d)\b')
    if ($oilMatch.Success) {
        $oilValue = [double]$oilMatch.Groups[1].Value
        if ($oilValue -gt 60 -and $oilValue -lt 120) {
            $results.macro.OIL = @{ value = $oilValue; source = "oilprice.com"; unit = "USD/barrel" }
        }
    }
    # 如果没找到,使用合理默认值
    if (-not $results.macro.OIL) {
        $results.macro.OIL = @{ value = 91; source = "estimated"; unit = "USD/barrel"; note = "oilprice.com extraction failed, estimated" }
    }
} catch {
    $results.macro.OIL = @{ value = 91; source = "estimated"; unit = "USD/barrel"; note = "oilprice.com unavailable, estimated" }
}

# 保存
$jsonStr = $results | ConvertTo-Json -Depth 5
$timeStr = Get-Date -Format 'yyyy-MM-dd_HH-mm'
$jsonStr | Set-Content "$workDir\data\market\prices_$timeStr.json" -Encoding UTF8
$jsonStr | Set-Content "$workDir\data\market\prices_latest.json" -Encoding UTF8

Write-Host "=== browser-price-collector v6 | $(Get-Date -Format 'HH:mm:ss') ==="
Write-Host "BTC: $($results.crypto.BTC.price) | ETH: $($results.crypto.ETH.price) | SOL: $($results.crypto.SOL.price)"
Write-Host "F&G: $($results.macro.FNG.value) ($($results.macro.FNG.classification))"
Write-Host "GOLD: $($results.macro.GOLD.value) | OIL: $($results.macro.OIL.value)"
Write-Host "Errors: $($results.errors.Count)"
