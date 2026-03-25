# collect-prices-simple.ps1 - 加密货币价格采集 v4 (多源降级 + 质量评分)
# 用途: BTC/ETH/SOL + VIX + 黄金 + 原油
# 降级路径: OKX/CryptoCompare API → Bing搜索摘要 → 国内财经网站
# 输出: data/market/prices_YYYY-MM-DD_HH-mm.json (带时间戳+置信度)
# ============================================================

param(
    [string]$OutputDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data\market",
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"
Add-Type -AssemblyName System.Web
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$DateStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$LogFile = "$OutputDir\collect-prices.log"
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $msg = "[$Level] $(Get-Date -Format 'HH:mm:ss') - $Message"
    Write-Host $msg
    Add-Content -Path $LogFile -Value $msg -Encoding UTF8
}

# ========== HTTP工具 ==========
function Invoke-SafeFetch {
    param([string]$Url, [int]$Timeout = 10, [string]$UA = "Mozilla/5.0")
    try {
        $headers = @{ "User-Agent" = $UA }
        $r = Invoke-WebRequest -Uri $Url -Headers $headers -TimeoutSec $Timeout -UseBasicParsing
        return @{ ok = $true; content = $r.Content; status = $r.StatusCode; len = $r.Content.Length }
    } catch {
        return @{ ok = $false; error = $_.Exception.Message.Substring(0, 80); status = 0 }
    }
}

# ========== 价格提取 (改进正则) ==========
function Extract-PriceValue {
    param([string]$Text, [string]$Symbol)
    # 优先找 "Symbol: $price" 或 "Symbol price: $price" 格式
    $patterns = @(
        "(?:$Symbol)[:\s]*\\$[\d,]+\.?\d*",
        "(?:price|cost|最新|当前)[:\s]*\\$?[\d,]+\.?\d*",
        "\\$[\d,]+\.?\d*",
        "USD[:\s]*[\d,]+\.?\d*",
        "[\d,]+\.?\d*\s*(?:USD|美元)"
    )
    foreach ($p in $patterns) {
        if ($Text -match $p) {
            $raw = $matches[0]
            $price = $raw -replace '[^\d.]', ''
            if ($price -and [double]$price -gt 0) {
                return [double]$price
            }
        }
    }
    return $null
}

# ========== API降级采集 ==========
function Get-CryptoPrice {
    param([string]$Symbol, [string]$Pair = "BTC-USDT")

    # --- 策略1: OKX API (最稳定) ---
    $okxUrls = @{
        "BTC" = "https://www.okx.com/api/v5/market/ticker?instId=BTC-USDT"
        "ETH" = "https://www.okx.com/api/v5/market/ticker?instId=ETH-USDT"
        "SOL" = "https://www.okx.com/api/v5/market/ticker?instId=SOL-USDT"
    }
    if ($okxUrls[$Symbol]) {
        $r = Invoke-SafeFetch -Url $okxUrls[$Symbol] -Timeout 8
        if ($r.ok) {
            try {
                $json = $r.content | ConvertFrom-Json
                if ($json.code -eq "0" -and $json.data[0].last) {
                    $price = [double]$json.data[0].last
                    return @{
                        price = $price; source = "OKX_API"; confidence = "high"
                        raw = $r.content.Substring(0, [Math]::Min(100, $r.content.Length))
                        timestamp = $DateStr
                    }
                }
            } catch { Write-Log "OKX $Symbol JSON解析失败" "WARN" }
        }
    }

    # --- 策略2: CryptoCompare API ---
    $ccUrls = @{
        "BTC" = "https://min-api.cryptocompare.com/data/price?fsym=BTC&tsyms=USD"
        "ETH" = "https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD"
        "SOL" = "https://min-api.cryptocompare.com/data/price?fsym=SOL&tsyms=USD"
    }
    if ($ccUrls[$Symbol]) {
        $r = Invoke-SafeFetch -Url $ccUrls[$Symbol] -Timeout 10
        if ($r.ok) {
            try {
                $json = $r.content | ConvertFrom-Json
                if ($json.USD) {
                    $price = [double]$json.USD
                    return @{
                        price = $price; source = "CryptoCompare_API"; confidence = "high"
                        raw = $r.content.Substring(0, [Math]::Min(60, $r.content.Length))
                        timestamp = $DateStr
                    }
                }
            } catch { Write-Log "CryptoCompare $Symbol 解析失败" "WARN" }
        }
    }

    # --- 策略3: Gate.io API ---
    $gateUrls = @{
        "BTC" = "https://api.gateio.ws/api/v4/spot/tickers?currency_pair=BTC_USDT"
        "ETH" = "https://api.gateio.ws/api/v4/spot/tickers?currency_pair=ETH_USDT"
        "SOL" = "https://api.gateio.ws/api/v4/spot/tickers?currency_pair=SOL_USDT"
    }
    if ($gateUrls[$Symbol]) {
        $r = Invoke-SafeFetch -Url $gateUrls[$Symbol] -Timeout 10
        if ($r.ok) {
            try {
                $json = $r.content | ConvertFrom-Json
                if ($json[0].last) {
                    $price = [double]$json[0].last
                    return @{
                        price = $price; source = "Gateio_API"; confidence = "high"
                        raw = $r.content.Substring(0, [Math]::Min(80, $r.content.Length))
                        timestamp = $DateStr
                    }
                }
            } catch { Write-Log "Gate.io $Symbol 解析失败" "WARN" }
        }
    }

    # --- 策略4: Bing搜索摘要 (最低置信度) ---
    Write-Log "  $Symbol API全部失败，降级到Bing搜索..." "WARN"
    $queries = @{
        "BTC" = "Bitcoin BTC price USD 今日最新"
        "ETH" = "Ethereum ETH 以太坊 价格 USD 今日"
        "SOL" = "Solana SOL 价格 USD 今日"
    }
    $encoded = [System.Web.HttpUtility]::UrlEncode($queries[$Symbol])
    $url = "https://cn.bing.com/search?q=$encoded"
    $r = Invoke-SafeFetch -Url $url -Timeout 12
    if ($r.ok) {
        $price = Extract-PriceValue -Text $r.content -Symbol $Symbol
        if ($price -and $price -gt 0) {
            # 保存原始搜索结果
            $rawFile = "$OutputDir\raw_search_${Symbol}_$Timestamp.txt"
            $r.content | Out-File -FilePath $rawFile -Encoding UTF8
            return @{
                price = $price; source = "cn.bing.com"; confidence = "low"
                raw_len = $r.len; raw_file = $rawFile; timestamp = $DateStr
            }
        }
    }

    return $null
}

# ========== VIX专项采集 (Yahoo Finance API) ==========
function Get-VIXPrice {
    # Yahoo Finance 非官方CSV接口
    $yahooUrl = "https://query1.finance.yahoo.com/v8/finance/chart/%5EVIX?interval=1d&range=1d"
    $r = Invoke-SafeFetch -Url $yahooUrl -Timeout 10
    if ($r.ok -and $r.status -eq 200) {
        try {
            $json = $r.content | ConvertFrom-Json
            $vixVal = $json.chart.result[0].meta.regularMarketPrice
            if ($vixVal -and [double]$vixVal -gt 0) {
                return @{
                    value = [double]$vixVal; source = "Yahoo_Finance_API"; confidence = "high"
                    raw = $r.content.Substring(0, [Math]::Min(100, $r.content.Length)); timestamp = $DateStr
                }
            }
        } catch { Write-Log "VIX Yahoo Finance JSON解析失败: $($_.Exception.Message.Substring(0,50))" "WARN" }
    }
    # 降级1: 查询2个替代代码
    foreach ($sym in @("^VIX", "^VIXN")) {
        $url2 = "https://query1.finance.yahoo.com/v8/finance/chart/$sym?interval=1d&range=1d"
        $r2 = Invoke-SafeFetch -Url $url2 -Timeout 10
        if ($r2.ok -and $r2.status -eq 200) {
            try {
                $json2 = $r2.content | ConvertFrom-Json
                $vixVal2 = $json2.chart.result[0].meta.regularMarketPrice
                if ($vixVal2 -and [double]$vixVal2 -gt 0) {
                    return @{
                        value = [double]$vixVal2; source = "Yahoo_Finance_API"; confidence = "high"
                        raw = $r2.content.Substring(0, [Math]::Min(100, $r2.content.Length)); timestamp = $DateStr
                    }
                }
            } catch {}
        }
    }
    # 降级2: CNN Fear & Greed
    $cnnR = Invoke-SafeFetch -Url "https://api.cnn.com/edge/v1/pulse/feargreed/indicator" -Timeout 10
    if ($cnnR.ok -and $cnnR.status -eq 200) {
        try {
            $cnnJson = $cnnR.content | ConvertFrom-Json
            if ($cnnJson.fearGreedScore -and [double]$cnnJson.fearGreedScore -gt 0) {
                return @{
                    value = [double]$cnnJson.fearGreedScore; source = "CNN_FearGreed"; confidence = "medium"
                    raw_len = $cnnR.len; timestamp = $DateStr
                }
            }
        } catch { Write-Log "CNN Fear&Greed解析失败" "WARN" }
    }
    # 降级3: Bing搜索兜底 (最低置信度)
    Write-Log "VIX API全部失败，降级到Bing搜索兜底..." "WARN"
    $bingR = Invoke-SafeFetch -Url "https://cn.bing.com/search?q=$( [System.Web.HttpUtility]::UrlEncode('VIX恐慌指数 今日') )" -Timeout 12
    if ($bingR.ok) {
        $price = Extract-PriceValue -Text $bingR.content -Symbol "VIX"
        if ($price -and $price -gt 0) {
            return @{
                value = $price; source = "cn.bing.com"; confidence = "low"
                raw_len = $bingR.len; timestamp = $DateStr
            }
        }
    }
    return $null
}

# ========== 宏观数据采集 (黄金/原油) ==========
function Get-MacroPrice {
    param([string]$Name, [string]$Query)

    $r = Invoke-SafeFetch -Url "https://cn.bing.com/search?q=$( [System.Web.HttpUtility]::UrlEncode($Query) )" -Timeout 12
    if ($r.ok) {
        $price = Extract-PriceValue -Text $r.content -Symbol $Name
        if ($price -and $price -gt 0) {
            return @{
                value = $price; source = "cn.bing.com"; confidence = "medium"
                raw_len = $r.len; timestamp = $DateStr
            }
        }
    }
    return $null
}

# ========== 数据质量评分 ==========
function Get-DataQualityScore {
    param([hashtable]$Data)
    $score = 0; $factors = @()
    # 来源权威性
    if ($Data.confidence -eq "high") { $score += 40; $factors += "API权威来源" }
    elseif ($Data.confidence -eq "medium") { $score += 25; $factors += "Bing摘要" }
    else { $score += 10; $factors += "Bing搜索(低置信)" }
    # 字段完整性
    if ($Data.price) { $score += 20; $factors += "价格字段" }
    if ($Data.source) { $score += 15; $factors += "来源标注" }
    if ($Data.timestamp) { $score += 10; $factors += "时间戳" }
    if ($Data.raw) { $score += 15; $factors += "原始数据" }
    # 标签
    $label = if ($score -ge 70) { "高" } elseif ($score -ge 40) { "中" } else { "低" }
    return @{ score = $score; label = $label; factors = $factors -join " + " }
}

# ========== 主程序 ==========
Write-Log "========== 价格采集开始 (v4 多源降级) =========="
Write-Log "时间: $DateStr"

$result = @{
    timestamp = $DateStr
    timestamp_iso = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    collection_version = "v4"
    crypto = @{}
    macro = @{}
    quality_report = @{}
    errors = @()
}

# --- 采集加密货币 ---
Write-Log ">> 采集加密货币 (BTC/ETH/SOL)..."
$symbols = @("BTC", "ETH", "SOL")
foreach ($sym in $symbols) {
    Write-Log "  采集 $sym ..."
    $data = Get-CryptoPrice -Symbol $sym
    if ($data) {
        $result.crypto[$sym] = $data
        $qs = Get-DataQualityScore -Data $data
        $result.quality_report[$sym] = $qs
        Write-Log "  $sym = \$$($data.price) [$( $data.source )] 质量:$( $qs.label )" "OK"
    } else {
        Write-Log "  $sym 采集失败" "ERROR"
        $result.errors += "$sym : all sources failed"
    }
}

# --- 采集宏观数据 ---
Write-Log ">> 采集VIX恐慌指数..."
$vix = Get-VIXPrice
if ($vix) {
    $result.macro["VIX"] = $vix
    $qs = Get-DataQualityScore -Data $vix
    $result.quality_report["VIX"] = $qs
    Write-Log "  VIX = $($vix.value) [$( $vix.source )] 质量:$( $qs.label )" "OK"
} else {
    Write-Log "  VIX采集失败" "ERROR"
    $result.errors += "VIX : failed"
}

Write-Log ">> 采集黄金价格..."
$gold = Get-MacroPrice -Name "GOLD" -Query "黄金价格 今日 USD 美元"
if ($gold) {
    $result.macro["GOLD"] = $gold
    $qs = Get-DataQualityScore -Data $gold
    $result.quality_report["GOLD"] = $qs
    Write-Log "  GOLD = \$$($gold.value) [$( $gold.source )] 质量:$( $qs.label )" "OK"
} else {
    Write-Log "  黄金采集失败" "ERROR"
    $result.errors += "GOLD : failed"
}

Write-Log ">> 采集原油价格..."
$oil = Get-MacroPrice -Name "OIL" -Query "WTI原油价格 今日 USD"
if ($oil) {
    $result.macro["OIL"] = $oil
    $qs = Get-DataQualityScore -Data $oil
    $result.quality_report["OIL"] = $qs
    Write-Log "  OIL = \$$($oil.value) [$( $oil.source )] 质量:$( $qs.label )" "OK"
} else {
    Write-Log "  原油采集失败" "ERROR"
    $result.errors += "OIL : failed"
}

# --- 总体质量评估 ---
$allScores = $result.quality_report.Values | Where-Object { $_ -ne $null } | ForEach-Object { $_.score }
$avgScore = if ($allScores.Count -gt 0) { [Math]::Round(($allScores | Measure-Object -Average).Average, 1) } else { 0 }
$result.quality_report["_overall"] = @{
    average_score = $avgScore
    label = if ($avgScore -ge 70) { "高" } elseif ($avgScore -ge 40) { "中" } else { "低" }
    total_items = $allScores.Count
}

# --- 保存结果 ---
$jsonFile = "$OutputDir\prices_$Timestamp.json"
$result | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonFile -Encoding UTF8

$latestFile = "$OutputDir\prices_latest.json"
$result | ConvertTo-Json -Depth 6 | Out-File -FilePath $latestFile -Encoding UTF8

Write-Log "========== 采集完成 =========="
Write-Log "输出: $jsonFile"
Write-Log "质量: $( $result.quality_report['_overall'].label ) (平均分 $avgScore)"
Write-Log "错误: $( $result.errors.Count ) 项"
if ($result.errors.Count -gt 0) {
    Write-Log "失败详情: $($result.errors -join ' | ')" "WARN"
}

exit $(if ($result.errors.Count -gt 3) { 1 } else { 0 })
