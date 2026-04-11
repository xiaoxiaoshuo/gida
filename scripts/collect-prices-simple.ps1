# collect-prices-simple.ps1 - 加密货币价格采集 v8 (多源降级 + 质量评分 + 浏览器降级)
# v8修复: (1)OKX API因GFW SSL问题永远失败，移除作为主源，保留Gate.io作备用 (2)修复VIX采集逻辑
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
        # 强制TLS1.2（Fortinet SSL inspection环境兼容）
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $headers = @{ "User-Agent" = $UA }
        $r = Invoke-WebRequest -Uri $Url -Headers $headers -TimeoutSec $Timeout -UseBasicParsing
        return @{ ok = $true; content = $r.Content; status = $r.StatusCode; len = $r.Content.Length }
    } catch {
        $msg = $_.Exception.Message
        if ($msg.Length -gt 80) { $msg = $msg.Substring(0, 80) }
        return @{ ok = $false; error = $msg; status = 0 }
    }
}

# ========== 价格提取 (改进正则) ==========
function Extract-PriceValue {
    param([string]$Text, [string]$Symbol)
    # 优先找 "Symbol: $price" 或 "Symbol price: $price" 格式
    # 优先找 "Symbol: $price" 或 "Symbol price: $price" 格式
    $patterns = @(
        '(?i:' + $Symbol + ')[:\s]*\$[\d,]+\.?\d*',
        '(?:price|cost 最新|当前)[:\s]*\$?[\d,]+\.?\d*',
        '\$[\d,]+\.?\d*',
        '(?i)USD[:\s]*[\d,]+\.?\d*',
        '[\d,]+\.?\d*\s*(?:USD|美元)'
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

    # --- 策略1: CryptoCompare API (最稳定，GFW可访问) ---
    $ccUrls = @{
        "BTC" = "https://min-api.cryptocompare.com/data/price?fsym=BTC&tsyms=USD"
        "ETH" = "https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD"
        "SOL" = "https://min-api.cryptocompare.com/data/price?fsym=SOL&tsyms=USD"
    }
    if ($ccUrls[$Symbol]) {
        $r = Invoke-SafeFetch -Url $ccUrls[$Symbol] -Timeout 10
        if ($r.ok -and $r.len -gt 5) {
            try {
                $json = $r.content | ConvertFrom-Json
                if ($json.USD) {
                    $price = [double]$json.USD
                    $raw = if ($r.len -gt 0) { $r.content.Substring(0, [Math]::Min(60, $r.len)) } else { "" }
                    return @{
                        price = $price; source = "CryptoCompare_API"; confidence = "high"
                        raw = $raw; timestamp = $DateStr
                    }
                }
            } catch { Write-Log "CryptoCompare $Symbol 解析失败: $($_.Exception.Message.Substring(0,50))" "WARN" }
        }
    }

    # --- 策略2: Gate.io API (备用) ---
    $gateUrls = @{
        "BTC" = "https://api.gateio.ws/api/v4/spot/tickers?currency_pair=BTC_USDT"
        "ETH" = "https://api.gateio.ws/api/v4/spot/tickers?currency_pair=ETH_USDT"
        "SOL" = "https://api.gateio.ws/api/v4/spot/tickers?currency_pair=SOL_USDT"
    }
    if ($gateUrls[$Symbol]) {
        $r = Invoke-SafeFetch -Url $gateUrls[$Symbol] -Timeout 10
        if ($r.ok -and $r.len -gt 10) {
            try {
                $json = $r.content | ConvertFrom-Json
                if ($json[0].last) {
                    $price = [double]$json[0].last
                    $raw = if ($r.len -gt 0) { $r.content.Substring(0, [Math]::Min(80, $r.len)) } else { "" }
                    return @{
                        price = $price; source = "Gateio_API"; confidence = "high"
                        raw = $raw; timestamp = $DateStr
                    }
                }
            } catch { Write-Log "Gate.io $Symbol 解析失败: $($_.Exception.Message.Substring(0,50))" "WARN" }
        }
    }

    # --- 策略3: Bing搜索摘要 (最低置信度) ---
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
# 注意: VIX和Fear&Greed是不同指标，不要混淆
# VIX正常范围: 10-80 (恐慌指数)
# F&G范围: 0-100 (加密市场情绪)
function Get-VIXPrice {
    # 策略1: Yahoo Finance VIX API
    $yahooUrl = "https://query1.finance.yahoo.com/v8/finance/chart/%5EVIX?interval=1d&range=1d"
    $r = Invoke-SafeFetch -Url $yahooUrl -Timeout 10
    if ($r.ok -and $r.status -eq 200) {
        try {
            $json = $r.content | ConvertFrom-Json
            $vixVal = $json.chart.result[0].meta.regularMarketPrice
            if ($vixVal -and [double]$vixVal -gt 0) {
                $raw = if ($r.len -gt 0) { $r.content.Substring(0, [Math]::Min(100, $r.len)) } else { "" }
                return @{
                    value = [double]$vixVal; source = "Yahoo_Finance_VIX"; confidence = "high"
                    raw = $raw; timestamp = $DateStr
                }
            }
        } catch { Write-Log "VIX Yahoo Finance JSON解析失败: $($_.Exception.Message.Substring(0,50))" "WARN" }
    }
    # 降级1: Yahoo Finance ^VIXN (VIX短期期权指数)
    foreach ($sym in @("^VIX", "^VIXN")) {
        $url2 = "https://query1.finance.yahoo.com/v8/finance/chart/$sym?interval=1d&range=1d"
        $r2 = Invoke-SafeFetch -Url $url2 -Timeout 10
        if ($r2.ok -and $r2.status -eq 200) {
            try {
                $json2 = $r2.content | ConvertFrom-Json
                $vixVal2 = $json2.chart.result[0].meta.regularMarketPrice
                if ($vixVal2 -and [double]$vixVal2 -gt 0) {
                    $raw = if ($r2.len -gt 0) { $r2.content.Substring(0, [Math]::Min(100, $r2.len)) } else { "" }
                    return @{
                        value = [double]$vixVal2; source = "Yahoo_Finance_VIX"; confidence = "high"
                        raw = $raw; timestamp = $DateStr
                    }
                }
            } catch {}
        }
    }
    # 降级3: alternative.me Fear&Greed (这是F&G不是VIX! F&G:0-100, VIX:10-80)
    # 注意: 仅当VIX(Yahoo Finance)全部失败时降级到F&G作为替代情绪指标
    Write-Log "VIX Yahoo Finance API全部失败，降级到F&G(alternative.me)..." "WARN"
    $fngR = Invoke-SafeFetch -Url "https://api.alternative.me/fng/" -Timeout 10
    if ($fngR.ok -and $fngR.status -eq 200) {
        try {
            $fngJson = $fngR.content | ConvertFrom-Json
            if ($fngJson.data[0].value) {
                $fngVal = [int]$fngJson.data[0].value
                $fngClass = $fngJson.data[0].value_classification
                $raw = if ($fngR.len -gt 0) { $fngR.content.Substring(0, [Math]::Min(100, $fngR.len)) } else { "" }
                Write-Log "  F&G = $fngVal ($fngClass) [alternative.me 降级替代VIX]" "WARN"
                return @{
                    value = $fngVal; source = "alternative.me_FNG"; confidence = "medium"
                    raw = $raw; timestamp = $DateStr
                    note = "降级: VIX(Yahoo Finance)失败，采集F&G作为替代情绪指标"
                    value_classification = $fngClass
                }
            }
        } catch { Write-Log "alternative.me FNG解析失败" "WARN" }
    }
    return $null
}

# ========== 宏观数据采集 (黄金/原油) ==========
function Get-MacroPrice {
    param([string]$Name, [string]$Query)

    # ---- 黄金：优先 Kitco (有明确的Bid价格) ----
    if ($Name -eq "GOLD") {
        # 策略1: Kitco Charts - raw HTML 格式
        # 实际HTML: <div class="mr-0.5 text-[19px] font-normal">4,520.30</div>
        # 价格为 4,xxx.xx 格式（USD/oz），需要合理性验证
        $kitcoUrls = @(
            "https://www.kitco.com/charts/gold",
            "https://www.kitco.com/charts/livegold.html"
        )
        foreach ($kitcoUrl in $kitcoUrls) {
            $r = Invoke-SafeFetch -Url $kitcoUrl -Timeout 15
            if ($r.ok) {
                # 匹配原始HTML中的黄金现货价格：4,520.30 格式
                # 先尝试 oz/ounce 附近的 4,xxx 价格
                if ($r.content -match '(?:oz|ounce)[^<]*?([0-9],[0-9]{3}\.[0-9]{2})') {
                    $priceStr = $matches[1] -replace ',', ''
                    $price = [double]$priceStr
                    if ($price -gt 1500 -and $price -lt 10000) {
                        Write-Log "  GOLD Kitco oz附近正则成功: $price (URL: $kitcoUrl)" "INFO"
                        return @{
                            value = $price; source = "kitco.com"; confidence = "high"
                            unit = "USD/oz"; raw_len = $r.len; timestamp = $DateStr
                        }
                    }
                }
                # 备用：匹配 text-[19px] font-normal 样式中的价格（Kitco页面主价格）
                if ($r.content -match 'font-normal">([0-9],[0-9]{3}\.[0-9]{2})</div>') {
                    $priceStr = $matches[1] -replace ',', ''
                    $price = [double]$priceStr
                    if ($price -gt 1500 -and $price -lt 10000) {
                        Write-Log "  GOLD Kitco字体样式正则成功: $price" "INFO"
                        return @{
                            value = $price; source = "kitco.com"; confidence = "high"
                            unit = "USD/oz"; raw_len = $r.len; timestamp = $DateStr
                        }
                    }
                }
                # 备用：匹配 4,xxx.xx 格式的大数字（oz价格范围 $1500-$9999）
                if ($r.content -match '>([4-9],[0-9]{3}\.[0-9]{2})<') {
                    $priceStr = $matches[1] -replace ',', ''
                    $price = [double]$priceStr
                    if ($price -gt 1500 -and $price -lt 10000) {
                        Write-Log "  GOLD Kitco 4xxx范围正则成功: $price" "INFO"
                        return @{
                            value = $price; source = "kitco.com"; confidence = "medium"
                            unit = "USD/oz"; raw_len = $r.len; timestamp = $DateStr
                        }
                    }
                }
            }
        }
        Write-Log "  GOLD Kitco解析失败，尝试goldprice.org..." "WARN"

        # 策略2: goldprice.org JSON API
        $r2 = Invoke-SafeFetch -Url "https://goldprice.org/gold-price-hong-kong.html" -Timeout 15
        if ($r2.ok) {
            if ($r2.content -match 'Spot Gold Price:\s*USD\s*([0-9,]+\.?[0-9]*)') {
                $priceStr = $matches[1] -replace ',', ''
                $price = [double]$priceStr
                if ($price -gt 500) {
                    Write-Log "  GOLD goldprice.org抓取成功: $price" "INFO"
                    return @{
                        value = $price; source = "goldprice.org"; confidence = "high"
                        unit = "USD/oz"; raw_len = $r2.len; timestamp = $DateStr
                    }
                }
            }
        }
        Write-Log "  GOLD 所有专业网站失败，降级到Bing..." "WARN"
    }

    # ---- 原油：多源降级采集 ----
    if ($Name -eq "OIL") {
        # --- 策略1: TradingEconomics (最可靠，内容明确) ---
        $r = Invoke-SafeFetch -Url "https://tradingeconomics.com/commodity/crude-oil" -Timeout 15
        if ($r.ok -and $r.content) {
            # 匹配格式: "Crude Oil rose to 91.88 USD/Bbl" 或 "XXX USD/Bbl"
            if ($r.content -match 'Crude Oil[^$]*?(\d+\.\d{2})\s*USD/Bbl') {
                $price = [double]$matches[1]
                if ($price -gt 40 -and $price -lt 200) {
                    Write-Log "  OIL TradingEconomics抓取成功: $price" "INFO"
                    return @{
                        value = $price; source = "tradingeconomics.com"; confidence = "high"
                        unit = "USD/barrel (WTI)"; raw_len = $r.len; timestamp = $DateStr
                    }
                }
            }
            # 备用: 直接找 "USD/Bbl" 前的数字
            if ($r.content -match '(\d+\.\d{2})\s*USD/Bbl') {
                $price = [double]$matches[1]
                if ($price -gt 40 -and $price -lt 200) {
                    Write-Log "  OIL TradingEconomics备用抓取成功: $price" "INFO"
                    return @{
                        value = $price; source = "tradingeconomics.com"; confidence = "high"
                        unit = "USD/barrel (WTI)"; raw_len = $r.len; timestamp = $DateStr
                    }
                }
            }
        }

        # --- 策略2: EIA API (官方数据，DEMO_KEY有频率限制) ---
        $eiaUrl = "https://api.eia.gov/v2/petroleum/pri/spt/data/?api_key=DEMO_KEY&frequency=daily&data[0]=value&facets[product][]=EPCWTI&sort[0][column]=period&sort[0][direction]=desc&length=1"
        $eia = Invoke-SafeFetch -Url $eiaUrl -Timeout 15
        if ($eia.ok) {
            try {
                $eiaJson = $eia.content | ConvertFrom-Json
                if ($eiaJson.response.data.Count -gt 0) {
                    $price = [double]$eiaJson.response.data[0].value
                    if ($price -gt 40 -and $price -lt 200) {
                        Write-Log "  OIL EIA官方API抓取成功: $price" "INFO"
                        return @{
                            value = $price; source = "EIA_API"; confidence = "high"
                            unit = "USD/barrel (WTI)"; raw_len = $eia.len; timestamp = $DateStr
                        }
                    }
                }
            } catch { Write-Log "  OIL EIA JSON解析失败" "WARN" }
        }

        # --- 策略3: oilprice.com (保留但加强合理性检查) ---
        $r = Invoke-SafeFetch -Url "https://oilprice.com/oil-price-charts/" -Timeout 15
        if ($r.ok) {
            # oilprice.com格式: "WTI Crude\n 91.13-1.22-1.32%" 或 "WTI Crude 91.13"
            $wtiPatterns = @(
                'WTI Crude[\s\n]+([0-9]+\.[0-9]{2})',
                'WTI\s*Crude[^0-9]*([0-9]{2,3}\.[0-9]{2})',
                'value">([0-9]{2,3}\.[0-9]{2})'
            )
            foreach ($pat in $wtiPatterns) {
                if ($r.content -match $pat) {
                    $price = [double]$matches[1]
                    # 合理性检查: WTI应该在 $40-$200 之间
                    if ($price -gt 40 -and $price -lt 200) {
                        Write-Log "  OIL oilprice.com抓取成功: $price (正则: $pat)" "INFO"
                        return @{
                            value = $price; source = "oilprice.com"; confidence = "high"
                            unit = "USD/barrel (WTI)"; raw_len = $r.len; timestamp = $DateStr
                        }
                    } else {
                        Write-Log "  OIL oilprice.com值 $price 超出合理范围($40-$200)，跳过" "WARN"
                    }
                }
            }
        }
        Write-Log "  OIL 所有源失败，降级到Bing..." "WARN"
    }

    # Bing搜索降级（添加合理性检查）
    $minReasonable = if ($Name -eq "GOLD") { 1500 } elseif ($Name -eq "OIL") { 40 } else { 1 }
    $r = Invoke-SafeFetch -Url "https://cn.bing.com/search?q=$( [System.Web.HttpUtility]::UrlEncode($Query) )" -Timeout 12
    if ($r.ok) {
        $price = Extract-PriceValue -Text $r.content -Symbol $Name
        if ($price -and $price -gt 0) {
            if ($price -lt $minReasonable) {
                Write-Log "  $Name 提取值 $price 低于合理阈值 ${minReasonable}，标记为失败" "WARN"
                return @{
                    value = $null; source = "cn.bing.com"; confidence = "low"
                    raw_len = $r.len; timestamp = $DateStr
                    status = "unavailable"; reason = "price_below_threshold"
                }
            }
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
Write-Log "========== 价格采集开始 (v8 多源降级) =========="
Write-Log "时间: $DateStr"

$result = @{
    timestamp = $DateStr
    timestamp_iso = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    collection_version = "v8"
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
        Write-Log "  $sym = $($data.price) [$( $data.source )] 质量:$( $qs.label )" "OK"
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
    Write-Log "  GOLD = $($gold.value) [$( $gold.source )] 质量:$( $qs.label )" "OK"
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
    Write-Log "  OIL = $($oil.value) [$( $oil.source )] 质量:$( $qs.label )" "OK"
} else {
    Write-Log "  原油采集失败" "ERROR"
    $result.errors += "OIL : failed"
}

# ========== 宏观数据浏览器降级采集 (JS渲染网站专用) ==========
# 如果黄金/原油/VIX采集失败，调用Playwright浏览器采集
# 注意：先保存当前采集结果，再运行浏览器降级（浏览器脚本会合并更新 prices_latest.json）
$macroFailed = @()
if (-not $gold -or $gold.value -eq $null) { $macroFailed += "GOLD" }
if (-not $oil -or $oil.value -eq $null) { $macroFailed += "OIL" }
if (-not $vix -or $vix.value -eq $null) { $macroFailed += "VIX" }

if ($macroFailed.Count -gt 0) {
    # 先保存当前采集结果（crypto和已成功的macro）
    $jsonFile = "$OutputDir\prices_$Timestamp.json"
    $result | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonFile -Encoding UTF8
    $latestFile = "$OutputDir\prices_latest.json"
    $result | ConvertTo-Json -Depth 6 | Out-File -FilePath $latestFile -Encoding UTF8
    Write-Log "  [中间保存] crypto+partial macro 已写入 prices_latest.json" "INFO"

    Write-Log ">> 宏观数据浏览器降级采集 (失败项: $($macroFailed -join ', '))..." "WARN"
    try {
        $macroScript = "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\collect-macro-playwright.ps1"
        if (Test-Path $macroScript) {
            $macroResult = & $macroScript 2>&1
            $macroResult | ForEach-Object { Write-Log "  [Playwright] $_" "INFO" }
            Write-Log "  浏览器降级采集完成" "OK"
        } else {
            Write-Log "  collect-macro-playwright.ps1 不存在，跳过浏览器降级" "WARN"
        }
    } catch {
        $errMsg = $_.Exception.Message
        if ($errMsg.Length -gt 80) { $errMsg = $errMsg.Substring(0, 80) }
        Write-Log "  浏览器降级采集异常: $errMsg" "WARN"
    }

    # 读取浏览器更新后的 prices_latest.json 用于后续质量评估
    if (Test-Path $latestFile) {
        try {
            $updated = Get-Content $latestFile -Raw | ConvertFrom-Json
            if ($updated.macro) {
                $macroKeys = @($updated.macro.PSObject.Properties | ForEach-Object { $_.Name })
                Write-Log "  [合并] 浏览器采集的macro数据: $($macroKeys -join ', ')" "INFO"
                $result.macro = $updated.macro
                Write-Log "  [合并] 浏览器采集的macro数据已合并到结果" "INFO"
            } else {
                Write-Log "  [合并] 浏览器未返回macro数据" "WARN"
            }
        } catch {
            Write-Log "  [合并] 读取更新后的prices_latest.json失败: $($_.Exception.Message.Substring(0,80))" "WARN"
        }
    } else {
        Write-Log "  [合并] prices_latest.json不存在" "WARN"
    }
} else {
    # 没有失败项，直接保存
    $jsonFile = "$OutputDir\prices_$Timestamp.json"
    $result | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonFile -Encoding UTF8
    $latestFile = "$OutputDir\prices_latest.json"
    $result | ConvertTo-Json -Depth 6 | Out-File -FilePath $latestFile -Encoding UTF8
}

# --- 总体质量评估 ---
$allScores = $result.quality_report.Values | Where-Object { $_ -ne $null } | ForEach-Object { $_.score }
$avgScore = if ($allScores.Count -gt 0) { [Math]::Round(($allScores | Measure-Object -Average).Average, 1) } else { 0 }
$result.quality_report["_overall"] = @{
    average_score = $avgScore
    label = if ($avgScore -ge 70) { "高" } elseif ($avgScore -ge 40) { "中" } else { "低" }
    total_items = $allScores.Count
}

Write-Log "========== 采集完成 =========="
Write-Log "输出: $jsonFile"
Write-Log "质量: $( $result.quality_report['_overall'].label ) (平均分 $avgScore)"
Write-Log "错误: $( $result.errors.Count ) 项"
if ($result.errors.Count -gt 0) {
    Write-Log "失败详情: $($result.errors -join ' | ')" "WARN"
}

exit $(if ($result.errors.Count -gt 3) { 1 } else { 0 })
