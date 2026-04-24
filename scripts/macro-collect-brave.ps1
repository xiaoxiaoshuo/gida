# macro-collect-brave.ps1 - 宏观数据采集 (Brave Browser + CDP)
# 采集: 黄金(goldprice.org) + 原油(oilprice.com)
# 方法: Brave Browser remote debugging (CDP port 9222)
# 降级: EIA API / 估算值
# 输出: data/market/gold_latest.json, oil_latest.json

param(
    [string]$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid",
    [string]$BravePort = "9222",
    [switch]$NoBrowser
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

function Get-CdpJson {
    param([string]$Endpoint, [int]$Timeout = 10)
    try {
        $r = Invoke-RestMethod -Uri "http://127.0.0.1:$BravePort$Endpoint" -TimeoutSec $Timeout
        return @{ ok = $true; data = $r }
    } catch {
        return @{ ok = $false; error = $_.Exception.Message.Substring(0, 80) }
    }
}

function Invoke-SafeFetch {
    param([string]$Url, [int]$Timeout = 12)
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" }
        $r = Invoke-WebRequest -Uri $Url -Headers $headers -TimeoutSec $Timeout -UseBasicParsing
        return @{ ok = $true; content = $r.Content; status = $r.StatusCode }
    } catch {
        return @{ ok = $false; error = $_.Exception.Message.Substring(0, 80); status = 0 }
    }
}

# 确保 Brave 在运行并开启 remote debugging
function Start-BraveRemoteDebug {
    $bravePath = "C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe"
    $userDataDir = "$env:APPDATA\..\Local\BraveSoftware\Brave-Browser\User Data"
    
    # 检查 CDP 是否可用
    $cdp = Get-CdpJson -Endpoint "/json/version"
    if ($cdp.ok) {
        Write-Log "  Brave CDP 已连接: $($cdp.data.Browser)" "OK"
        return $true
    }
    
    Write-Log "  启动 Brave Browser (remote debugging port $BravePort)..."
    try {
        Start-Process $bravePath -ArgumentList "--remote-debugging-port=$BravePort","--user-data-dir=`"$userDataDir`"","--no-first-run" -WindowStyle Hidden
        Start-Sleep -Seconds 5
        $cdp2 = Get-CdpJson -Endpoint "/json/version" -Timeout 15
        if ($cdp2.ok) {
            Write-Log "  Brave 启动成功" "OK"
            return $true
        }
    } catch {
        Write-Log "  Brave 启动失败: $($_.Exception.Message.Substring(0,80))" "WARN"
    }
    return $false
}

# 通过 CDP 执行 JS
function Invoke-CdpEvaluate {
    param([string]$TabId, [string]$Script, [int]$Timeout = 20)
    try {
        $body = @{ expression = $Script } | ConvertTo-Json
        $r = Invoke-RestMethod -Method POST -Uri "http://127.0.0.1:$BravePort/json/runtime/evaluate" `
            -Body $body -ContentType "application/json" -TimeoutSec $Timeout
        return @{ ok = $true; result = $r.result }
    } catch {
        return @{ ok = $false; error = $_.Exception.Message.Substring(0, 80) }
    }
}

# 获取或激活标签页
function Get-or-Create-Tab {
    param([string]$Url)
    $tabs = Get-CdpJson -Endpoint "/json/tabs"
    if (-not $tabs.ok) { return $null }
    
    $targetHost = ($Url -split '/')[2]
    
    foreach ($tab in $tabs.data) {
        if ($tab.url -match [regex]::Escape($targetHost)) {
            try {
                Invoke-RestMethod -Method POST -Uri "http://127.0.0.1:$BravePort/json/activate/$($tab.id)" -TimeoutSec 5
            } catch {}
            return $tab
        }
    }
    
    try {
        $newTab = Invoke-RestMethod -Method POST -Uri "http://127.0.0.1:$BravePort/json/new?$Url" -TimeoutSec 10
        Start-Sleep -Seconds 3
        return $newTab
    } catch {
        return $null
    }
}

# ========== 主程序 ==========
Write-Log "========== 宏观数据采集 (Brave CDP) | $(Get-Date -Format 'HH:mm:ss') =========="

$braveReady = Start-BraveRemoteDebug

# ---- 黄金 ----
Write-Log ">> 采集黄金 (goldprice.org)..."
$goldResult = $null

if ($braveReady) {
    $tab = Get-or-Create-Tab -Url "https://goldprice.org/"
    if ($tab) {
        Start-Sleep -Seconds 4
        try {
            $eval = Invoke-CdpEvaluate -TabId $tab.id -Script @"
(function(){
    const el = document.querySelector('.price-value') || document.querySelector('[data-price]') || document.querySelector('#spottprice');
    if (!el) return JSON.stringify({error: 'no price element', texts: Array.from(document.querySelectorAll('span[class*="price"]')).slice(0,5).map(e=>e.className+':'+e.textContent)});
    return JSON.stringify({price: el.textContent.trim(), all: Array.from(document.querySelectorAll('*')).filter(e=>e.childNodes.length===1&&/[0-9,]+\.[0-9]{2}/.test(e.textContent.trim())).slice(0,10).map(e=>e.textContent.trim())});
})()
"@
            if ($eval.ok -and $eval.result.value) {
                $data = $eval.result.value | ConvertFrom-Json
                if ($data.price -and $data.price -match '[0-9,]+\.[0-9]{2}') {
                    $price = [double]($data.price -replace ',', '')
                    if ($price -gt 1500 -and $price -lt 10000) {
                        $goldResult = @{
                            timestamp = $Timestamp; source = "goldprice.org (Brave CDP)"
                            price_per_oz = $price
                            price_per_gram = [Math]::Round($price / 31.1035, 2)
                            price_per_kg = [Math]::Round($price / 31.1035 * 1000, 2)
                            currency = "USD"; collection_time = $Timestamp
                        }
                        Write-Log "  GOLD = $$price/oz [Brave CDP]" "OK"
                    }
                }
                if (-not $goldResult -and $data.all) {
                    foreach ($txt in $data.all) {
                        if ($txt -match '^([0-9,]+\.[0-9]{2})$') {
                            $price = [double]($txt -replace ',', '')
                            if ($price -gt 1500 -and $price -lt 10000) {
                                $goldResult = @{
                                    timestamp = $Timestamp; source = "goldprice.org (Brave CDP)"
                                    price_per_oz = $price
                                    price_per_gram = [Math]::Round($price / 31.1035, 2)
                                    price_per_kg = [Math]::Round($price / 31.1035 * 1000, 2)
                                    currency = "USD"; collection_time = $Timestamp
                                }
                                Write-Log "  GOLD = $$price/oz [Brave CDP alt]" "OK"
                                break
                            }
                        }
                    }
                }
            }
        } catch {
            Write-Log "  CDP evaluate 失败: $($_.Exception.Message.Substring(0,80))" "WARN"
        }
    }
}

# 降级: 直接 web_fetch (已知被 403 但尝试一次)
if (-not $goldResult) {
    Write-Log "  降级到 web_fetch..." "WARN"
    $wf = Invoke-SafeFetch -Url "https://goldprice.org/" -Timeout 15
    if ($wf.ok -and $wf.content -match '>([0-9,]+\.[0-9]{2})<' -and $wf.content.Length -lt 50000) {
        $price = [double]($matches[1] -replace ',', '')
        if ($price -gt 1500 -and $price -lt 10000) {
            $goldResult = @{
                timestamp = $Timestamp; source = "goldprice.org (fetch)"
                price_per_oz = $price
                price_per_gram = [Math]::Round($price / 31.1035, 2)
                price_per_kg = [Math]::Round($price / 31.1035 * 1000, 2)
                currency = "USD"; collection_time = $Timestamp
            }
            Write-Log "  GOLD = $$price/oz [web_fetch]" "OK"
        }
    }
}

# 最终降级
if (-not $goldResult) {
    $lastFile = "$RepoRoot\data\market\gold_latest.json"
    if (Test-Path $lastFile) {
        try {
            $last = Get-Content $lastFile -Raw | ConvertFrom-Json
            if ($last.price_per_oz -and $last.price_per_oz -gt 0) {
                $estPrice = [Math]::Round($last.price_per_oz * 0.998, 2)
                $goldResult = @{
                    timestamp = $Timestamp; source = "estimated_from_last"
                    price_per_oz = $estPrice; currency = "USD"; note = "估算值"; collection_time = $Timestamp
                }
                Write-Log "  GOLD = $$estPrice (估算)" "WARN"
            }
        } catch {}
    }
}

if ($goldResult) {
    $goldResult | ConvertTo-Json -Depth 4 | Out-File -FilePath "$RepoRoot\data\market\gold_latest.json" -Encoding UTF8
    Write-Log "  gold_latest.json 已更新" "OK"
}

# ---- 原油 ----
Write-Log ">> 采集WTI原油 (oilprice.com)..."
$oilResult = $null

if ($braveReady) {
    $tab = Get-or-Create-Tab -Url "https://oilprice.com/oil-price-charts/"
    if ($tab) {
        Start-Sleep -Seconds 4
        try {
            $eval = Invoke-CdpEvaluate -TabId $tab.id -Script @"
(function(){
    const t = document.body.innerText;
    const w = t.match(/WTI Crude\t([0-9,]+\.[0-9]{2})\t([+-]?[0-9,]+\.[0-9]{2})\t([+-]?[0-9.]+%)/);
    const b = t.match(/Brent Crude\t([0-9,]+\.[0-9]{2})\t([+-]?[0-9,]+\.[0-9]{2})\t([+-]?[0-9.]+%)/);
    return JSON.stringify({
        wti: w ? {p: w[1], c: w[2], cp: w[3]} : null,
        brent: b ? {p: b[1], c: b[2], cp: b[3]} : null,
        first200: t.substring(0, 200)
    });
})()
"@
            if ($eval.ok -and $eval.result.value) {
                $data = $eval.result.value | ConvertFrom-Json
                if ($data.wti) {
                    $wtiPrice = [double]($data.wti.p -replace ',', '')
                    $wtiChange = [double]($data.wti.c -replace ',', '')
                    $wtiChangePct = [double]($data.wti.cp -replace '%', '')
                    if ($wtiPrice -gt 40 -and $wtiPrice -lt 200) {
                        $oilResult = @{
                            timestamp = $Timestamp; source = "oilprice.com (Brave CDP)"
                            prices = @{ WTI_Crude = @{ price = $wtiPrice; change = $wtiChange; change_pct = $wtiChangePct } }
                            collection_time = $Timestamp
                        }
                        if ($data.brent) {
                            $brentPrice = [double]($data.brent.p -replace ',', '')
                            $brentChange = [double]($data.brent.c -replace ',', '')
                            $brentChangePct = [double]($data.brent.cp -replace '%', '')
                            $oilResult.prices["Brent_Crude"] = @{ price = $brentPrice; change = $brentChange; change_pct = $brentChangePct }
                        }
                        Write-Log "  WTI = $$wtiPrice [Brave CDP]" "OK"
                        if ($data.brent) { Write-Log "  Brent = $$brentPrice [Brave CDP]" "OK" }
                    }
                }
            }
        } catch {
            Write-Log "  CDP evaluate 失败: $($_.Exception.Message.Substring(0,80))" "WARN"
        }
    }
}

# 降级: 直接抓取
if (-not $oilResult) {
    Write-Log "  降级到直接抓取..." "WARN"
    $wf = Invoke-SafeFetch -Url "https://oilprice.com/oil-price-charts/" -Timeout 15
    if ($wf.ok -and $wf.content -match 'WTI Crude\s+([0-9,]+\.[0-9]{2})\s+([+-]?[0-9,]+\.[0-9]{2})\s+([+-]?[0-9.]+%)') {
        $wtiPrice = [double]($matches[1] -replace ',', '')
        $wtiChange = [double]($matches[2] -replace ',', '')
        $wtiChangePct = [double]($matches[3] -replace '%', '')
        if ($wtiPrice -gt 40 -and $wtiPrice -lt 200) {
            $oilResult = @{
                timestamp = $Timestamp; source = "oilprice.com (fetch)"
                prices = @{ WTI_Crude = @{ price = $wtiPrice; change = $wtiChange; change_pct = $wtiChangePct } }
                collection_time = $Timestamp
            }
            Write-Log "  WTI = $$wtiPrice [oilprice.com fetch]" "OK"
        }
    }
}

# 最终降级: EIA API
if (-not $oilResult) {
    Write-Log "  降级到EIA API..." "WARN"
    $eiaUrl = "https://api.eia.gov/v2/petroleum/pri/spt/data/?api_key=DEMO_KEY&frequency=daily&data[0]=value&facets[product][]=EPCWTI&sort[0][column]=period&sort[0][direction]=desc&length=1"
    $eia = Invoke-SafeFetch -Url $eiaUrl -Timeout 15
    if ($eia.ok) {
        try {
            $eiaJson = $eia.content | ConvertFrom-Json
            if ($eiaJson.response.data.Count -gt 0) {
                $price = [double]$eiaJson.response.data[0].value
                if ($price -gt 40 -and $price -lt 200) {
                    $oilResult = @{
                        timestamp = $Timestamp; source = "EIA_API"
                        prices = @{ WTI_Crude = @{ price = $price; change = $null; change_pct = $null } }
                        collection_time = $Timestamp
                    }
                    Write-Log "  WTI = $$price [EIA_API]" "OK"
                }
            }
        } catch {}
    }
}

if (-not $oilResult) {
    $lastFile = "$RepoRoot\data\market\oil_latest.json"
    if (Test-Path $lastFile) {
        try {
            $last = Get-Content $lastFile -Raw | ConvertFrom-Json
            $lastPrice = $last.prices.WTI_Crude.price
            $estPrice = [Math]::Round($lastPrice * 0.999, 2)
            $oilResult = @{
                timestamp = $Timestamp; source = "estimated_from_last"
                prices = @{ WTI_Crude = @{ price = $estPrice; change = $null; change_pct = $null } }
                note = "估算值"; collection_time = $Timestamp
            }
            Write-Log "  WTI = $$estPrice (估算)" "WARN"
        } catch {}
    }
}

if ($oilResult) {
    $oilResult | ConvertTo-Json -Depth 4 | Out-File -FilePath "$RepoRoot\data\market\oil_latest.json" -Encoding UTF8
    Write-Log "  oil_latest.json 已更新" "OK"
}

Write-Log "========== 宏观数据采集完成 =========="
