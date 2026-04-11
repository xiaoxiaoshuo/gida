# collect-macro-playwright.ps1 - 宏观数据采集 (IE COM浏览器)
# 用途: 黄金/原油/VIX — 注意: IE COM无法获取JS渲染内容，本脚本仅供参考记录
# 重要: 已由 collect-prices-simple.ps1 (v8) 接管所有采集，本脚本保留用于回退
# 依赖: Internet Explorer COM / Playwright MCP
# 输出: data/market/prices_latest.json (更新macro字段)

param(
    [string]$OutputDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data\market"
)

$ErrorActionPreference = "Continue"
$DateStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"

$LogFile = "$OutputDir\macro-collect.log"
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $msg = "[$Level] $(Get-Date -Format 'HH:mm:ss') - $Message"
    Write-Host $msg
    Add-Content -Path $LogFile -Value $msg -Encoding UTF8
}

Write-Log "========== 宏观数据采集 (IE COM) =========="

$result = @{
    timestamp = $DateStr
    source = "IE-COM-browser"
}

function Invoke-SafeFetch {
    param([string]$Url, [int]$Timeout = 12)
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" }
        $r = Invoke-WebRequest -Uri $Url -Headers $headers -TimeoutSec $Timeout -UseBasicParsing
        return @{ ok = $true; content = $r.Content; status = $r.StatusCode; len = $r.Content.Length }
    } catch {
        return @{ ok = $false; error = $_.Exception.Message.Substring(0, 80); status = 0 }
    }
}

# ========== 黄金 (Kitco + goldprice.org) ==========
Write-Log ">> 采集黄金 (Kitco/goldprice.org)..."
$gotGold = $false

# Kitco Charts - 可靠正则: font-normal">4,749.20
$r = Invoke-SafeFetch -Url "https://www.kitco.com/charts/livegold.html" -Timeout 15
if ($r.ok) {
    if ($r.content -match 'font-normal">([0-9],[0-9]{3}\.[0-9]{2})</div>') {
        $priceStr = $matches[1] -replace ',', ''
        $goldPrice = [double]$priceStr
        if ($goldPrice -gt 1500 -and $goldPrice -lt 10000) {
            $result.GOLD = @{
                value = $goldPrice
                source = "kitco.com (fetch)"
                unit = "USD/oz"
                confidence = "high"
                timestamp = $DateStr
            }
            Write-Log "  GOLD = $goldPrice [kitco.com] OK" "OK"
            $gotGold = $true
        }
    }
}

# goldprice.org 备用
if (-not $gotGold) {
    $r2 = Invoke-SafeFetch -Url "https://goldprice.org/" -Timeout 15
    if ($r2.ok -and $r2.content -match '>([0-9],[0-9]{3}\.[0-9]{2})<') {
        $priceStr = $matches[1] -replace ',', ''
        $goldPrice = [double]$priceStr
        if ($goldPrice -gt 1500 -and $goldPrice -lt 10000) {
            $result.GOLD = @{
                value = $goldPrice
                source = "goldprice.org (fetch)"
                unit = "USD/oz"
                confidence = "high"
                timestamp = $DateStr
            }
            Write-Log "  GOLD = $goldPrice [goldprice.org fallback] OK" "OK"
            $gotGold = $true
        }
    }
}

if (-not $gotGold) {
    Write-Log "  GOLD 采集失败，尝试IE浏览器..." "WARN"
    try {
        $ie = New-Object -ComObject InternetExplorer.Application
        $ie.Visible = $false; $ie.Silent = $true
        $ie.Navigate("https://www.kitco.com/charts/livegold.html")
        Start-Sleep -Seconds 6
        if ($ie.ReadyState -eq 4 -and $null -ne $ie.Document) {
            $bodyText = $ie.Document.body.innerText
            if ($bodyText -match 'Bid\s*\n\s*([0-9,]+\.[0-9]{2})\s*\n\s*USD') {
                $goldPrice = [double]($matches[1] -replace ',', '')
                if ($goldPrice -gt 1500 -and $goldPrice -lt 10000) {
                    $result.GOLD = @{
                        value = $goldPrice
                        source = "kitco.com (IE COM)"
                        unit = "USD/oz"
                        confidence = "high"
                        timestamp = $DateStr
                    }
                    Write-Log "  GOLD = $goldPrice [kitco.com IE] OK" "OK"
                    $gotGold = $true
                }
            }
        }
        $ie.Quit()
    } catch {
        Write-Log "  GOLD IE采集失败: $($_.Exception.Message.Substring(0,80))" "WARN"
        try { $ie.Quit() } catch {}
    }
}

if (-not $gotGold) {
    Write-Log "  GOLD 所有方法失败" "WARN"
}

# ========== 原油 (TradingEconomics + oilprice.com) ==========
Write-Log ">> 采集WTI原油 (TradingEconomics/oilprice.com)..."
$gotOil = $false

# TradingEconomics - 最可靠
$r = Invoke-SafeFetch -Url "https://tradingeconomics.com/commodity/crude-oil" -Timeout 15
if ($r.ok -and $r.content -match 'Crude Oil[^$]*?(\d+\.\d{2})\s*USD/Bbl') {
    $oilPrice = [double]$matches[1]
    if ($oilPrice -gt 40 -and $oilPrice -lt 200) {
        $result.OIL = @{
            value = $oilPrice
            source = "tradingeconomics.com (fetch)"
            unit = "USD/barrel (WTI)"
            confidence = "high"
            timestamp = $DateStr
        }
        Write-Log "  OIL = $oilPrice [tradingeconomics.com] OK" "OK"
        $gotOil = $true
    }
}

# oilprice.com 备用
if (-not $gotOil) {
    $r2 = Invoke-SafeFetch -Url "https://oilprice.com/" -Timeout 15
    if ($r2.ok) {
        if ($r2.content -match 'WTI Crude[\s\S]{1,200}?value">([0-9]+\.[0-9]{2})') {
            $oilPrice = [double]$matches[1]
            if ($oilPrice -gt 20 -and $oilPrice -lt 200) {
                $result.OIL = @{
                    value = $oilPrice
                    source = "oilprice.com (fetch)"
                    unit = "USD/barrel (WTI)"
                    confidence = "high"
                    timestamp = $DateStr
                }
                Write-Log "  OIL = $oilPrice [oilprice.com fallback] OK" "OK"
                $gotOil = $true
            }
        }
        # 备用: value标签
        if (-not $gotOil -and $r2.content -match 'value">([0-9]{2,3}\.[0-9]{2})') {
            $oilPrice = [double]$matches[1]
            if ($oilPrice -gt 40 -and $oilPrice -lt 200) {
                $result.OIL = @{
                    value = $oilPrice
                    source = "oilprice.com (fetch value-tag)"
                    unit = "USD/barrel (WTI)"
                    confidence = "high"
                    timestamp = $DateStr
                }
                Write-Log "  OIL = $oilPrice [oilprice.com value-tag] OK" "OK"
                $gotOil = $true
            }
        }
    }
}

if (-not $gotOil) {
    Write-Log "  OIL 采集失败" "WARN"
}

# ========== VIX (CBOE / Yahoo Finance) ==========
Write-Log ">> 采集VIX恐慌指数..."
$gotVix = $false

# CBOE 官方
$r = Invoke-SafeFetch -Url "https://www.cboe.com/tradable_products/vix" -Timeout 12
if ($r.ok -and $r.content -match 'VIX[^$]*?\$(\d{1,2}\.\d{2})') {
    $vixPrice = [double]$matches[1]
    if ($vixPrice -gt 5 -and $vixPrice -lt 100) {
        $result.VIX = @{
            value = $vixPrice
            source = "CBOE.com (fetch)"
            confidence = "high"
            timestamp = $DateStr
        }
        Write-Log "  VIX = $vixPrice [CBOE.com] OK" "OK"
        $gotVix = $true
    }
}

# Yahoo Finance VIX备用
if (-not $gotVix) {
    $yUrl = "https://query1.finance.yahoo.com/v8/finance/chart/%5EVIX?interval=1d&range=1d"
    $r2 = Invoke-SafeFetch -Url $yUrl -Timeout 10
    if ($r2.ok) {
        try {
            $json = $r2.content | ConvertFrom-Json
            $vixVal = $json.chart.result[0].meta.regularMarketPrice
            if ($vixVal -and [double]$vixVal -gt 0) {
                $result.VIX = @{
                    value = [double]$vixVal
                    source = "Yahoo_Finance_VIX (fetch)"
                    confidence = "high"
                    timestamp = $DateStr
                }
                Write-Log "  VIX = $vixVal [Yahoo Finance] OK" "OK"
                $gotVix = $true
            }
        } catch {}
    }
}

# alternative.me F&G 作为降级 (注意: 这是F&G不是VIX)
if (-not $gotVix) {
    $fgUrl = "https://api.alternative.me/fng/"
    $r3 = Invoke-SafeFetch -Url $fgUrl -Timeout 10
    if ($r3.ok) {
        try {
            $fgJson = $r3.content | ConvertFrom-Json
            if ($fgJson.data[0].value) {
                $fngVal = [int]$fgJson.data[0].value
                $result.VIX = @{
                    value = $fngVal
                    value_classification = $fgJson.data[0].value_classification
                    source = "alternative.me (F&G降级)"
                    confidence = "medium"
                    timestamp = $DateStr
                    note = "实际采集的是Fear&Greed指数，不是VIX"
                }
                Write-Log "  VIX = $fngVal (Extreme Fear分类) [alternative.me F&G 降级] 注意：这是F&G不是VIX" "WARN"
                $gotVix = $true
            }
        } catch {}
    }
}

if (-not $gotVix) {
    Write-Log "  VIX 采集失败" "WARN"
}

# ========== 更新 prices_latest.json（合并模式） ==========
$latestFile = "$OutputDir\prices_latest.json"

# 构建新的 macro 数据（只包含本次采集到的有效数据）
$newMacroData = @{}
foreach ($key in @("GOLD", "OIL", "VIX")) {
    if ($result.ContainsKey($key)) {
        $newMacroData[$key] = $result[$key]
    }
}

# 如果本次没有采集到任何有效macro数据，跳过更新以保留已有数据
if ($newMacroData.Count -eq 0) {
    Write-Log "  本次无有效宏观数据采集，跳过 prices_latest.json 更新（保留已有数据）" "WARN"
} else {
    # 读取现有数据并合并
    $finalData = @{
        timestamp = $DateStr
        collection_version = "macro-playwright-v2"
        crypto = @{}
        macro = $newMacroData
    }
    if (Test-Path $latestFile) {
        try {
            $existingJson = Get-Content $latestFile -Raw | ConvertFrom-Json
            # 保留现有的 crypto 数据
            if ($existingJson.crypto) {
                $finalData.crypto = @{}
                $existingJson.crypto.PSObject.Properties | ForEach-Object {
                    $finalData.crypto[$_.Name] = $_.Value
                }
            }
            # 合并已有的 macro 数据（新数据覆盖旧数据，但只针对成功采集的项）
            if ($existingJson.macro) {
                $existingJson.macro.PSObject.Properties | ForEach-Object {
                    if (-not $finalData.macro.ContainsKey($_.Name)) {
                        $finalData.macro[$_.Name] = $_.Value
                    }
                }
            }
            Write-Log "  合并已有数据: crypto保留 $($finalData.crypto.Count) 项, macro合并 $($finalData.macro.Count) 项" "INFO"
        } catch {
            Write-Log "  读取 prices_latest.json 失败，将创建新文件: $($_.Exception.Message.Substring(0,80))" "WARN"
        }
    }

    $json = $finalData | ConvertTo-Json -Depth 6
    $json | Out-File -FilePath $latestFile -Encoding UTF8
    Write-Log "  prices_latest.json 已更新" "INFO"
}

Write-Log "========== 采集完成 =========="
Write-Log "输出: $latestFile"

exit 0
