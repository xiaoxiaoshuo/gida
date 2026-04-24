# macro-data-collector.ps1 - 宏观数据专用采集脚本
# 采集: 黄金(金衡盎司)、原油(WTI/Brent)、Fear&Greed指数
# 方法: Brave Browser CDP (goldprice.org/oilprice.com JS渲染) + alternative.me API + EIA API
# 降级: 新浪财经 / 估算值
# 输出: data/market/gold_latest.json, oil_latest.json, fear-greed_latest.json
# ============================================================

param(
    [string]$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid",
    [switch]$NoBrowser   # 仅使用API降级，不启动浏览器
)

$ErrorActionPreference = "Continue"
$DateStr = Get-Date -Format "yyyy-MM-dd"
$Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
$LogFile = "$RepoRoot\memory\$DateStr.md"

if (-not (Test-Path "$RepoRoot\data\market")) {
    New-Item -ItemType Directory -Path "$RepoRoot\data\market" -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Level] $(Get-Date -Format 'HH:mm:ss') - $Message"
    Write-Host $entry
    Add-Content -Path $LogFile -Value "  - $entry" -Encoding UTF8
}

function Invoke-SafeFetch {
    param([string]$Url, [int]$Timeout = 12, [string]$UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $headers = @{ "User-Agent" = $UA }
        $r = Invoke-WebRequest -Uri $Url -Headers $headers -TimeoutSec $Timeout -UseBasicParsing
        return @{ ok = $true; content = $r.Content; status = $r.StatusCode }
    } catch {
        return @{ ok = $false; error = if ($_.Exception.Message.Length -gt 80) { $_.Exception.Message.Substring(0, 80) } else { $_.Exception.Message }; status = 0 }
    }
}

# Fear & Greed (alternative.me API)
function Get-FearGreed {
    Write-Log ">> 采集 Fear & Greed Index..."
    $r = Invoke-SafeFetch -Url "https://api.alternative.me/fng/" -Timeout 12
    if ($r.ok -and $r.status -eq 200) {
        try {
            $json = $r.content | ConvertFrom-Json
            if ($json.data[0].value) {
                $val = [int]$json.data[0].value
                $valClass = $json.data[0].value_classification
                $ts = [DateTimeOffset]::FromUnixTimeSeconds([int]$json.data[0].timestamp).ToString("yyyy-MM-ddTHH:mm:ssZ")
                $result = @{
                    timestamp = $ts; source = "alternative.me"; index = $val; value = $valClass
                    yesterday = if ($json.data[1]) { [int]$json.data[1].value } else { $null }
                    yesterday_value = if ($json.data[1]) { $json.data[1].value_classification } else { $null }
                    last_week = if ($json.data[6]) { [int]$json.data[6].value } else { $null }
                    last_week_value = if ($json.data[6]) { $json.data[6].value_classification } else { $null }
                    last_month = if ($json.data[29]) { [int]$json.data[29].value } else { $null }
                    last_month_value = if ($json.data[29]) { $json.data[29].value_classification } else { $null }
                    collection_time = $Timestamp
                }
                Write-Log "  F&G = $val ($valClass) [alternative.me API]" "OK"
                return $result
            }
        } catch { $e = $_.Exception.Message; $errMsg = if ($e.Length -le 60) { $e } else { $e.Substring(0, 60) }; Write-Log "  F&G JSON解析失败: $errMsg" "WARN" }
    }
    Write-Log "  F&G API失败，降级到Bing..." "WARN"
    $bingR = Invoke-SafeFetch -Url "https://cn.bing.com/search?q=$( [System.Web.HttpUtility]::UrlEncode('Fear and Greed Index') )" -Timeout 12
    if ($bingR.ok -and $bingR.content -match '(\d{1,3})[^0-9]{0,20}(Extreme Fear|Fear|Neutral|Greed|Extreme Greed)') {
        $val = [int]$matches[1]; $valClass = $matches[2]
        Write-Log "  F&G = $val ($valClass) [cn.bing.com]" "OK"
        return @{ timestamp = $Timestamp; source = "cn.bing.com (降级)"; index = $val; value = $valClass; collection_time = $Timestamp }
    }
    return $null
}

# 黄金 (web_fetch + HTTP fallback)
function Get-GoldPrice-Browser {
    Write-Log ">> 采集黄金 (web_fetch kitco.com)..."
    # web_fetch 内部实现了JS渲染，能获取真实数据
    try {
        $headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" }
        $r = Invoke-WebRequest -Uri "https://www.kitco.com/charts/livegold.html" -Headers $headers -TimeoutSec 15 -UseBasicParsing
        $content = $r.Content
        # kitco.com 实时价格: Bid ### 4,682.40 -9.40 (-0.20%)
        $price = $null; $change = $null; $changePct = $null
        if ($content -match 'Bid\s+[\n\r\s]*###\s*([0-9,]+\.[0-9]+)') {
            $price = [double]($matches[1] -replace ',', '')
        } elseif ($content -match 'data-price="([0-9.]+)"') {
            $price = [double]$matches[1]
        }
        if (-not $price -and $content -match '>([45]\d{3}\.[0-9]{2})<') {
            $price = [double]$matches[1]
        }
        if ($price -and $price -gt 1500 -and $price -lt 10000) {
            if ($content -match '\(([+-]?[0-9.]+)%\)\s*$') {
                $changePct = [double]($matches[1] -replace '%', '')
            } elseif ($content -match '\(([+-][0-9.]+)%\)') {
                $changePct = [double]($matches[1] -replace '%', '')
            }
            if ($content -match '([+-]?[0-9,]+\.[0-9]+)\s*\([+-]?[0-9.]+%\)') {
                $change = [double]($matches[1] -replace ',', '')
            }
            $nyTime = "$(Get-Date -Format 'MMM dd, yyyy'), $(Get-Date -Format 'hh:mm:ss') NY time"
            $result = @{
                timestamp = $Timestamp; source = "kitco.com/charts/livegold.html (fetch)"
                price_per_oz = $price; change = $change; change_pct = $changePct
                price_per_gram = [Math]::Round($price / 31.1035, 2)
                price_per_kg = [Math]::Round($price / 31.1035 * 1000, 2)
                currency = "USD"; time_ny = $nyTime; collection_time = $Timestamp
            }
            Write-Log "  GOLD = $$price/oz [kitco.com]" "OK"
            return $result
        }
        Write-Log "  kitco.com正则匹配失败，降级..." "WARN"
    } catch {
        $eMsg = $_.Exception.Message
        if ($eMsg.Length -gt 80) { $eMsg = $eMsg.Substring(0, 80) }
        Write-Log "  GOLD web_fetch失败: $eMsg" "WARN"
    }
    return $null
}

# 原油 (直接HTTP抓取 oilprice.com HTML - JS渲染数据在data-price属性中)
function Get-OilPrice-Browser {
    Write-Log ">> 采集WTI原油 (oilprice.com fetch)..."
    try {
        $headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
        $r = Invoke-WebRequest -Uri "https://oilprice.com/oil-price-charts/" -Headers $headers -TimeoutSec 15 -UseBasicParsing
        $content = $r.Content
        
        # HTML结构: <td class='last_price' data-price='96.34'>96.34</td>...<td class='change_up...>+0.49</td>...<td class='change_up_percent...>+0.51%...
        # WTI在Brent之前，同一正则匹配第一个last_price即为WTI
        # WTI: find "WTI Crude" section, extract price from that row
        $wtiSection = if ($content -match '(WTI Crude[^<]*?<td[^>]*last_price[^>]*data-price=''([0-9.]+)''[^>]*>([0-9.]+)<)') { $matches[0] } else { $content }
        if ($wtiSection -match "last_price'[^>]*data-price='([0-9.]+)'[^>]*>([0-9.]+)<.*?change_up[^>]*>([+-]?[0-9.]+)<.*?percent_change_cell[^>]*>([+-]?[0-9.]+)%") {
            $wtiPrice = [double]$matches[2]; $wtiChange = [double]$matches[3]; $wtiChangePct = [double]$matches[4]
        }
        # Brent: find "Brent Crude" section specifically (after "Brent Crude" marker)
        $brentPos = $content.IndexOf("Brent Crude")
        if ($brentPos -gt 0) {
            $brentSection = $content.Substring($brentPos, [Math]::Min(800, $content.Length - $brentPos))
            if ($brentSection -match "last_price'[^>]*data-price='([0-9.]+)'[^>]*>([0-9.]+)<.*?change_up[^>]*>([+-]?[0-9.]+)<.*?percent_change_cell[^>]*>([+-]?[0-9.]+)%") {
                $brentPrice = [double]$matches[2]; $brentChange = [double]$matches[3]; $brentChangePct = [double]$matches[4]
            }
        }
        
        if ($wtiMatch) {
            $wtiPrice = [double]$matches[2]
            $wtiChange = [double]$matches[3]
            $wtiChangePct = [double]$matches[4]
            $brentPrice = if ($brentMatch) { [double]$matches[2] } else { $null }
            $brentChange = if ($brentMatch) { [double]$matches[3] } else { $null }
            $brentChangePct = if ($brentMatch) { [double]$matches[4] } else { $null }
            if ($wtiPrice -gt 40 -and $wtiPrice -lt 200) {
                $result = @{
                    timestamp = $Timestamp; source = "oilprice.com (fetch)"
                    prices = @{ WTI_Crude = @{ price = $wtiPrice; change = $wtiChange; change_pct = $wtiChangePct } }
                    collection_time = $Timestamp
                }
                if ($brentPrice) {
                    $result.prices["Brent_Crude"] = @{ price = $brentPrice; change = $brentChange; change_pct = $brentChangePct }
                }
                Write-Log "  WTI = $$wtiPrice [oilprice.com]" "OK"
                if ($brentPrice) { Write-Log "  Brent = $$brentPrice [oilprice.com]" "OK" }
                return $result
            }
        }
        Write-Log "  oilprice.com正则匹配失败" "WARN"
    } catch {
        $eMsg = $_.Exception.Message
        if ($eMsg.Length -gt 80) { $eMsg = $eMsg.Substring(0, 80) }
        Write-Log "  OIL 浏览器失败: $eMsg" "WARN"
    }
    return $null
}

# API降级: 黄金
function Get-GoldPrice-API {
    Write-Log ">> 采集黄金 (API降级)..."
    $r = Invoke-SafeFetch -Url "https://goldprice.org/gold-price-hong-kong.html" -Timeout 12
    if ($r.ok -and $r.content -match 'Spot Gold Price:\s*USD\s*([0-9,]+\.?[0-9]*)') {
        $price = [double]($matches[1] -replace ',', '')
        if ($price -gt 1500 -and $price -lt 10000) {
            Write-Log "  GOLD = $$price [goldprice.org]" "OK"
            return @{ timestamp = $Timestamp; source = "goldprice.org"; price_per_oz = $price; currency = "USD"; collection_time = $Timestamp }
        }
    }
    $sinaR = Invoke-SafeFetch -Url "https://hq.sinajs.cn/rn=ajson&list=hf_GC" -Timeout 12
    if ($sinaR.ok -and $sinaR.content -match '"([^"]+)"') {
        $parts = $matches[1] -split ','
        if ($parts.Count -ge 2 -and [double]$parts[0] -gt 1500 -and [double]$parts[0] -lt 10000) {
            Write-Log "  GOLD = $$($parts[0]) [sina.com.cn]" "OK"
            return @{ timestamp = $Timestamp; source = "sina.com.cn"; price_per_oz = [double]$parts[0]; currency = "USD"; collection_time = $Timestamp }
        }
    }
    $lastFile = "$RepoRoot\data\market\gold_latest.json"
    if (Test-Path $lastFile) {
        try {
            $last = Get-Content $lastFile -Raw | ConvertFrom-Json
            $estPrice = [Math]::Round($last.price_per_oz * 0.998, 2)
            Write-Log "  GOLD = $$estPrice (估算)" "WARN"
            return @{ timestamp = $Timestamp; source = "estimated_from_last"; price_per_oz = $estPrice; currency = "USD"; note = "估算值"; collection_time = $Timestamp }
        } catch {}
    }
    Write-Log "  GOLD 全部降级失败" "ERROR"
    return $null
}

# API降级: 原油
function Get-OilPrice-API {
    Write-Log ">> 采集WTI原油 (API降级)..."
    $eiaUrl = "https://api.eia.gov/v2/petroleum/pri/spt/data/?api_key=DEMO_KEY&frequency=daily&data[0]=value&facets[product][]=EPCWTI&sort[0][column]=period&sort[0][direction]=desc&length=1"
    $eia = Invoke-SafeFetch -Url $eiaUrl -Timeout 15
    if ($eia.ok) {
        try {
            $eiaJson = $eia.content | ConvertFrom-Json
            if ($eiaJson.response.data.Count -gt 0) {
                $price = [double]$eiaJson.response.data[0].value
                if ($price -gt 40 -and $price -lt 200) {
                    Write-Log "  WTI = $$price [EIA_API]" "OK"
                    return @{ timestamp = $Timestamp; source = "EIA_API"; prices = @{ WTI_Crude = @{ price = $price; change = $null; change_pct = $null } }; collection_time = $Timestamp }
                }
            }
        } catch { Write-Log "  EIA JSON解析失败" "WARN" }
    }
    $sinaR = Invoke-SafeFetch -Url "https://hq.sinajs.cn/rn=ajson&list=hf_CL" -Timeout 12
    if ($sinaR.ok -and $sinaR.content -match '"([^"]+)"') {
        $parts = $matches[1] -split ','
        if ($parts.Count -ge 2 -and [double]$parts[0] -gt 40 -and [double]$parts[0] -lt 200) {
            Write-Log "  WTI = $$($parts[0]) [sina.com.cn]" "OK"
            return @{ timestamp = $Timestamp; source = "sina.com.cn"; prices = @{ WTI_Crude = @{ price = [double]$parts[0]; change = $null; change_pct = $null } }; collection_time = $Timestamp }
        }
    }
    $lastFile = "$RepoRoot\data\market\oil_latest.json"
    if (Test-Path $lastFile) {
        try {
            $last = Get-Content $lastFile -Raw | ConvertFrom-Json
            $lastPrice = $last.prices.WTI_Crude.price
            $estPrice = [Math]::Round($lastPrice * 0.999, 2)
            Write-Log "  WTI = $$estPrice (估算)" "WARN"
            return @{ timestamp = $Timestamp; source = "estimated_from_last"; prices = @{ WTI_Crude = @{ price = $estPrice; change = $null; change_pct = $null } }; note = "估算值"; collection_time = $Timestamp }
        } catch {}
    }
    Write-Log "  WTI 全部降级失败" "ERROR"
    return $null
}

# ========== 主程序 ==========
Write-Log "========== 宏观数据采集 | $(Get-Date -Format 'HH:mm:ss') =========="

# 1. Fear & Greed (always API)
$fgData = Get-FearGreed
if ($fgData) {
    $fgData | ConvertTo-Json -Depth 4 | Out-File -FilePath "$RepoRoot\data\market\fear-greed_latest.json" -Encoding UTF8
    Write-Log "  fear-greed_latest.json 已更新" "OK"
} else {
    Write-Log "  F&G 采集失败，跳过" "ERROR"
}

# 2. 黄金
if ($NoBrowser) {
    $goldData = Get-GoldPrice-API
} else {
    $goldData = Get-GoldPrice-Browser
    if (-not $goldData) {
        Write-Log "  浏览器采集失败，降级到API..." "WARN"
        $goldData = Get-GoldPrice-API
    }
}
if ($goldData) {
    $goldData | ConvertTo-Json -Depth 4 | Out-File -FilePath "$RepoRoot\data\market\gold_latest.json" -Encoding UTF8
    Write-Log "  gold_latest.json 已更新" "OK"
} else {
    Write-Log "  黄金 采集失败，跳过" "ERROR"
}

# 3. 原油
if ($NoBrowser) {
    $oilData = Get-OilPrice-API
} else {
    $oilData = Get-OilPrice-Browser
    if (-not $oilData) {
        Write-Log "  浏览器采集失败，降级到API..." "WARN"
        $oilData = Get-OilPrice-API
    }
}
if ($oilData) {
    $oilData | ConvertTo-Json -Depth 4 | Out-File -FilePath "$RepoRoot\data\market\oil_latest.json" -Encoding UTF8
    Write-Log "  oil_latest.json 已更新" "OK"
} else {
    Write-Log "  原油 采集失败，跳过" "ERROR"
}

Write-Log "========== 宏观数据采集完成 =========="
