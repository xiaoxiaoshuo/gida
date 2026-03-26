# ============================================================
# collect-optimized-v2.ps1 - 优化版数据采集脚本
# 改进: 修复价格采集，替换失败的API和数据源
# - BTC/ETH/SOL: CryptoCompare (OKX备用)
# - GOLD: Kitco (goldprice.org正则失效)
# - OIL: oilprice.com
# - F&G: alternative.me
# ============================================================

param(
    [string]$OutputDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data\market",
    [string]$TechOutputDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data\tech",
    [string]$WatchlistDir = "C:\Users\Administrator\clawd\agents\workspace-gid\WATCHLIST"
)

$ErrorActionPreference = "Continue"
$DateStr = Get-Date -Format "yyyy-MM-dd"
$DateTimeStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"

if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
if (-not (Test-Path $TechOutputDir)) { New-Item -ItemType Directory -Path $TechOutputDir -Force | Out-Null }

$LogFile = "$OutputDir\collect-prices.log"
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $msg = "[$Level] $(Get-Date -Format 'HH:mm:ss') - $Message"
    Write-Host $msg
    Add-Content -Path $LogFile -Value $msg -Encoding UTF8
}

function Invoke-SafeFetch {
    param([string]$Url, [int]$Timeout = 10, [string]$UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
    try {
        $headers = @{ "User-Agent" = $UA }
        $r = Invoke-WebRequest -Uri $Url -Headers $headers -TimeoutSec $Timeout -UseBasicParsing
        return @{ ok = $true; content = $r.Content; status = $r.StatusCode; len = $r.Content.Length }
    } catch {
        $msg = $_.Exception.Message
        if ($msg.Length -gt 100) { $msg = $msg.Substring(0, 100) }
        return @{ ok = $false; error = $msg }
    }
}

# ========== Crypto Prices ==========
function Get-CryptoPrices {
    $result = @{}
    
    # Primary: CryptoCompare
    $apis = @{
        "BTC" = "https://min-api.cryptocompare.com/data/price?fsym=BTC&tsyms=USD"
        "ETH" = "https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD"
        "SOL" = "https://min-api.cryptocompare.com/data/price?fsym=SOL&tsyms=USD"
    }
    
    foreach ($sym in @("BTC", "ETH", "SOL")) {
        $r = Invoke-SafeFetch -Url $apis[$sym] -Timeout 10
        if ($r.ok) {
            try {
                $json = $r.content | ConvertFrom-Json
                $price = [double]$json.USD
                if ($price -gt 0) {
                    $result[$sym] = @{
                        price = $price
                        source = "CryptoCompare_API"
                        confidence = "high"
                        raw = $r.content.Substring(0, [Math]::Min(60, $r.content.Length))
                        timestamp = $DateTimeStr
                    }
                    Write-Log "  $sym = $price [CryptoCompare]"
                    continue
                }
            } catch { }
        }
        
        # Fallback: OKX
        $okxPair = if ($sym -eq "BTC") { "BTC-USDT" } elseif ($sym -eq "ETH") { "ETH-USDT" } else { "SOL-USDT" }
        $okxUrl = "https://www.okx.com/api/v5/market/ticker?instId=$okxPair"
        $r2 = Invoke-SafeFetch -Url $okxUrl -Timeout 10
        if ($r2.ok) {
            try {
                $j2 = $r2.content | ConvertFrom-Json
                $price2 = [double]$j2.data[0].last
                if ($price2 -gt 0) {
                    $result[$sym] = @{
                        price = $price2
                        source = "OKX_API"
                        confidence = "high"
                        raw = $r2.content.Substring(0, [Math]::Min(80, $r2.content.Length))
                        timestamp = $DateTimeStr
                    }
                    Write-Log "  $sym = $price2 [OKX fallback]"
                    continue
                }
            } catch { }
        }
        
        Write-Log "  $sym 采集失败" "ERROR"
    }
    
    return $result
}

# ========== Fear & Greed ==========
# 2026-03-26: API端点 /fng/ 返回404，改用页面抓取
function Get-FearGreed {
    $r = Invoke-SafeFetch -Url "https://alternative.me/crypto/fear-and-greed-index/" -Timeout 15
    if ($r.ok) {
        try {
            $html = $r.content
            # 三元素结构：Now → 分类 → 数值
            if ($html -match '(?s)Now.{0,200}?(Extreme\s+Fear|Extreme\s+Greed|Fear|Greed|Neutral).{0,80}?<[^>]+>(\d{1,3})<') {
                $class = $matches[1].Trim()
                $val = [int]$matches[2]
                return @{
                    value = $val
                    value_classification = $class
                    source = "alternative.me_page"
                    confidence = "medium"
                    raw = "$class $val"
                    timestamp = $DateTimeStr
                }
            } elseif ($html -match '>Now<.*?>(\d{1,3})<') {
                # 最简：>Now<后的第一个数字
                $val = [int]$matches[1]
                return @{
                    value = $val
                    value_classification = "Unknown"
                    source = "alternative.me_page"
                    confidence = "low"
                    raw = "value=$val"
                    timestamp = $DateTimeStr
                }
            }
        } catch { }
    }
    return $null
}

# ========== Gold (Kitco优先) ==========
function Get-GoldPrice {
    # Kitco - 可靠的正则: font-normal">4,519.70
    $r = Invoke-SafeFetch -Url "https://www.kitco.com/charts/livegold.html" -Timeout 15
    if ($r.ok) {
        if ($r.content -match 'font-normal">([0-9],[0-9]{3}\.[0-9]{2})</div>') {
            $priceStr = $matches[1] -replace ',', ''
            $price = [double]$priceStr
            if ($price -gt 1000 -and $price -lt 10000) {
                Write-Log "  GOLD = $price [Kitco]"
                return @{
                    value = $price; source = "kitco.com"; confidence = "high"
                    unit = "USD/oz"; raw_len = $r.len; timestamp = $DateTimeStr
                }
            }
        }
    }
    
    # Fallback: goldprice.org
    $r2 = Invoke-SafeFetch -Url "https://goldprice.org/" -Timeout 15
    if ($r2.ok) {
        # goldprice.org 格式: >4,519.70< 或 4,519 USD
        if ($r2.content -match '>([0-9],[0-9]{3}\.[0-9]{2})<') {
            $priceStr = $matches[1] -replace ',', ''
            $price = [double]$priceStr
            if ($price -gt 1000) {
                Write-Log "  GOLD = $price [goldprice.org fallback]"
                return @{
                    value = $price; source = "goldprice.org"; confidence = "high"
                    unit = "USD/oz"; raw_len = $r2.len; timestamp = $DateTimeStr
                }
            }
        }
    }
    
    Write-Log "  GOLD 采集失败" "ERROR"
    return $null
}

# ========== Oil (oilprice.com) ==========
function Get-OilPrice {
    $r = Invoke-SafeFetch -Url "https://oilprice.com/" -Timeout 15
    if ($r.ok) {
        # oilprice.com: <td class="value">91.31</td> 格式
        if ($r.content -match 'WTI Crude[\s\S]{1,200}?value">([0-9]+\.[0-9]{2})') {
            $price = [double]$matches[1]
            if ($price -gt 20) {
                Write-Log "  OIL = $price [oilprice.com]"
                return @{
                    value = $price; source = "oilprice.com"; confidence = "high"
                    unit = "USD/barrel (WTI)"; raw_len = $r.len; timestamp = $DateTimeStr
                }
            }
        }
        # 备用: 直接匹配value标签
        if ($r.content -match 'value">([0-9]{2,3}\.[0-9]{2})\s*<') {
            $price = [double]$matches[1]
            if ($price -gt 20 -and $price -lt 200) {
                Write-Log "  OIL = $price [oilprice.com value tag]"
                return @{
                    value = $price; source = "oilprice.com"; confidence = "high"
                    unit = "USD/barrel (WTI)"; raw_len = $r.len; timestamp = $DateTimeStr
                }
            }
        }
    }
    
    # Fallback: oilprice.com/oil-price-charts/
    Write-Log "  OIL oilprice.com主页解析失败，尝试charts页..." "WARN"
    $r2 = Invoke-SafeFetch -Url "https://oilprice.com/oil-price-charts/" -Timeout 15
    if ($r2.ok) {
        if ($r2.content -match 'value">([0-9]{2,3}\.[0-9]{2})') {
            $price = [double]$matches[1]
            if ($price -gt 20) {
                Write-Log "  OIL = $price [oilprice.com/charts]"
                return @{
                    value = $price; source = "oilprice.com/charts"; confidence = "high"
                    unit = "USD/barrel (WTI)"; raw_len = $r2.len; timestamp = $DateTimeStr
                }
            }
        }
    }
    
    Write-Log "  OIL 采集失败" "ERROR"
    return $null
}

# ========== Data Quality ==========
function Get-DataQualityScore {
    param([string]$type, [hashtable]$Data)
    $score = 0; $factors = @()
    
    if ($Data.confidence -eq "high") { $score += 40; $factors += "API权威来源" }
    elseif ($Data.confidence -eq "medium") { $score += 25; $factors += "Bing摘要" }
    else { $score += 10 }
    
    if ($Data.price -or $Data.value) { $score += 20; $factors += "价格字段" }
    if ($Data.source) { $score += 15; $factors += "来源标注" }
    if ($Data.timestamp) { $score += 10; $factors += "时间戳" }
    if ($Data.raw -or $Data.raw_len) { $score += 15; $factors += "原始数据" }
    
    $label = if ($score -ge 70) { "高" } elseif ($score -ge 40) { "中" } else { "低" }
    return @{ score = $score; label = $label; factors = $factors -join " + " }
}

# ========== Main Collection ==========
Write-Log "========== 优化版数据采集开始 =========="
Write-Log "时间: $DateTimeStr"

$result = @{
    timestamp = $DateTimeStr
    timestamp_iso = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    collection_version = "v5-optimized"
    crypto = @{}
    macro = @{}
    quality_report = @{}
    errors = @()
}

# Crypto
Write-Log ">> 采集加密货币..."
$cryptoData = Get-CryptoPrices
foreach ($sym in $cryptoData.Keys) {
    $result.crypto[$sym] = $cryptoData[$sym]
    $result.quality_report[$sym] = Get-DataQualityScore -type "crypto" -Data $cryptoData[$sym]
}

# F&G
Write-Log ">> 采集Fear&Greed指数..."
$fng = Get-FearGreed
if ($fng) {
    $result.macro["FNG"] = $fng
    $result.quality_report["FNG"] = Get-DataQualityScore -type "macro" -Data $fng
} else {
    $result.errors += "FNG : failed"
}

# Gold
Write-Log ">> 采集黄金价格..."
$gold = Get-GoldPrice
if ($gold) {
    $result.macro["GOLD"] = $gold
    $result.quality_report["GOLD"] = Get-DataQualityScore -type "macro" -Data $gold
} else {
    $result.errors += "GOLD : failed"
}

# Oil
Write-Log ">> 采集原油价格..."
$oil = Get-OilPrice
if ($oil) {
    $result.macro["OIL"] = $oil
    $result.quality_report["OIL"] = Get-DataQualityScore -type "macro" -Data $oil
} else {
    $result.errors += "OIL : failed"
}

# Overall quality
$allScores = $result.quality_report.Values | Where-Object { $_ -ne $null } | ForEach-Object { $_.score }
$avgScore = if ($allScores.Count -gt 0) { [Math]::Round(($allScores | Measure-Object -Average).Average, 1) } else { 0 }
$result.quality_report["_overall"] = @{
    average_score = $avgScore
    label = if ($avgScore -ge 70) { "高" } elseif ($avgScore -ge 40) { "中" } else { "低" }
    total_items = $allScores.Count
}

# Save
$jsonFile = "$OutputDir\prices_$Timestamp.json"
$result | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonFile -Encoding UTF8

$latestFile = "$OutputDir\prices_latest.json"
$result | ConvertTo-Json -Depth 6 | Out-File -FilePath $latestFile -Encoding UTF8

Write-Log "========== 采集完成 =========="
Write-Log "输出: $jsonFile"
Write-Log "质量: $( $result.quality_report['_overall'].label ) (平均分 $avgScore)"
Write-Log "错误: $( $result.errors.Count ) 项"
if ($result.errors.Count -gt 0) {
    Write-Log "失败: $($result.errors -join ' | ')" "WARN"
}

# Return for further processing
return $result
