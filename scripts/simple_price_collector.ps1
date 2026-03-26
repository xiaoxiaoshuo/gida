# simple_price_collector.ps1 - 简单有效的价格采集脚本
# 使用Bing搜索作为主要数据源，验证数据采集功能

$ErrorActionPreference = 'SilentlyContinue'
$workDir = "C:\Users\Administrator\clawd\agents\workspace-gid"

$results = @{
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    timestamp_iso = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    crypto = @{}
    macro = @{}
    errors = @()
}

# 从Bing搜索结果中提取价格
function Extract-PriceFromBing {
    param([string]$Content, [string]$Symbol)
    
    # 清理HTML标签，保留文本内容
    $text = $Content -replace '<[^>]+>', ' '
    $text = $text -replace '\s+', ' '
    
    # 针对不同资产的价格提取模式
    $patterns = @{
        "BTC" = '\$([\d,]{2,})\.?\d*'
        "ETH" = '\$([\d,]{2,})\.?\d*'
        "SOL" = '\$?(\d{2,3}(?:\.\d{2})?)'
        "GOLD" = '\$?([45]\d{3}(?:\.\d{2})?)'
        "OIL" = '\$(\d{2,3}(?:\.\d{2})?)'
    }
    
    $pattern = $patterns[$Symbol]
    if ($pattern) {
        $matches = [regex]::Matches($text, $pattern)
        foreach ($match in $matches) {
            $priceStr = $match.Groups[1].Value -replace ',', ''
            try {
                $price = [double]$priceStr
                # 验证价格合理范围
                if ($Symbol -eq "BTC" -and $price -ge 50000 -and $price -le 100000) {
                    return $price
                }
                elseif ($Symbol -eq "ETH" -and $price -ge 1000 -and $price -le 5000) {
                    return $price
                }
                elseif ($Symbol -eq "SOL" -and $price -ge 50 -and $price -le 200) {
                    return $price
                }
                elseif ($Symbol -eq "GOLD" -and $price -ge 4000 -and $price -le 6000) {
                    return $price
                }
                elseif ($Symbol -eq "OIL" -and $price -ge 40 -and $price -le 200) {
                    return $price
                }
            }
            catch {
                continue
            }
        }
    }
    
    return $null
}

# 1. 采集加密货币价格
$cryptoQueries = @{
    "BTC" = "bitcoin btc price usd today"
    "ETH" = "ethereum eth price usd today" 
    "SOL" = "solana sol crypto price usd today"
}

foreach ($symbol in $cryptoQueries.Keys) {
    $query = $cryptoQueries[$symbol]
    $encodedQuery = [System.Web.HttpUtility]::UrlEncode($query)
    $url = "https://cn.bing.com/search?q=$encodedQuery"
    
    try {
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 15 -UseBasicParsing
        $price = Extract-PriceFromBing -Content $response.Content -Symbol $symbol
        
        if ($price) {
            $results.crypto[$symbol] = @{
                price = $price
                source = "Bing_Search"
                confidence = "medium"
            }
            Write-Host "✓ $symbol : `$$price (Bing Search)"
        }
        else {
            $results.errors += "$symbol : extraction failed"
            Write-Host "✗ $symbol : extraction failed"
        }
    }
    catch {
        $results.errors += "$symbol : $_"
        Write-Host "✗ $symbol : $_"
    }
}

# 2. Fear&Greed Index (使用API，因为页面提取已经工作)
try {
    $fgApiUrl = "https://api.alternative.me/fng/?limit=1"
    $fgData = Invoke-RestMethod -Uri $fgApiUrl -TimeoutSec 10
    $fgValue = [int]$fgData.data[0].value
    
    if ($fgValue -ge 0 -and $fgValue -le 100) {
        $classification = if ($fgValue -le 25) { "Extreme Fear" }
        elseif ($fgValue -le 45) { "Fear" }
        elseif ($fgValue -le 55) { "Neutral" }
        elseif ($fgValue -le 75) { "Greed" }
        else { "Extreme Greed" }
        
        $results.macro["FNG"] = @{
            value = $fgValue
            classification = $classification
            source = "alternative.me_API"
            confidence = "high"
        }
        Write-Host "✓ Fear&Greed : $fgValue ($classification)"
    }
}
catch {
    $results.errors += "FNG : $_"
    Write-Host "✗ Fear&Greed : $_"
}

# 3. 黄金价格
try {
    $goldQuery = "gold price usd today per ounce"
    $encodedQuery = [System.Web.HttpUtility]::UrlEncode($goldQuery)
    $url = "https://cn.bing.com/search?q=$encodedQuery"
    $response = Invoke-WebRequest -Uri $url -TimeoutSec 15 -UseBasicParsing
    $price = Extract-PriceFromBing -Content $response.Content -Symbol "GOLD"
    
    if ($price) {
        $results.macro["GOLD"] = @{
            value = $price
            source = "Bing_Search"
            unit = "USD/oz"
            confidence = "medium"
        }
        Write-Host "✓ GOLD : `$$price/oz (Bing Search)"
    }
    else {
        $results.errors += "GOLD : extraction failed"
        Write-Host "✗ GOLD : extraction failed"
    }
}
catch {
    $results.errors += "GOLD : $_"
    Write-Host "✗ GOLD : $_"
}

# 4. 原油价格
try {
    $oilQuery = "WTI crude oil price usd today"
    $encodedQuery = [System.Web.HttpUtility]::UrlEncode($oilQuery)
    $url = "https://cn.bing.com/search?q=$encodedQuery"
    $response = Invoke-WebRequest -Uri $url -TimeoutSec 15 -UseBasicParsing
    $price = Extract-PriceFromBing -Content $response.Content -Symbol "OIL"
    
    if ($price) {
        $results.macro["OIL"] = @{
            value = $price
            source = "Bing_Search"
            unit = "USD/barrel"
            confidence = "medium"
        }
        Write-Host "✓ OIL : `$$price/barrel (Bing Search)"
    }
    else {
        $results.errors += "OIL : extraction failed"
        Write-Host "✗ OIL : extraction failed"
    }
}
catch {
    $results.errors += "OIL : $_"
    Write-Host "✗ OIL : $_"
}

# 保存结果
$timeStr = Get-Date -Format 'yyyy-MM-dd_HH-mm'
$jsonFile = "$workDir\data\market\prices_simple_$timeStr.json"
$results | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonFile -Encoding UTF8

$latestFile = "$workDir\data\market\prices_simple_latest.json"
$results | ConvertTo-Json -Depth 5 | Out-File -FilePath $latestFile -Encoding UTF8

Write-Host "`n=== Summary ==="
Write-Host "Crypto collected: $($results.crypto.Count)"
Write-Host "Macro collected: $($results.macro.Count)"  
Write-Host "Errors: $($results.errors.Count)"
Write-Host "Output: $jsonFile"

if ($results.errors.Count > 3) { exit 1 } else { exit 0 }