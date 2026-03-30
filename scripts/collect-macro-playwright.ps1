# collect-macro-playwright.ps1 - 宏观数据采集 (Playwright浏览器)
# 用途: 黄金/原油/VIX (JS渲染网站专用)
# 依赖: Playwright MCP / npx @playwright/mcp
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

Write-Log "========== 宏观数据采集 (Playwright) =========="

$result = @{
    timestamp = $DateStr
    source = "playwright-browser"
}

# ========== 黄金 ==========
Write-Log ">> 采集黄金 (goldprice.org)..."
try {
    # 使用 Brave 浏览器直接访问
    $ie = New-Object -ComObject InternetExplorer.Application
    $ie.Visible = $false
    $ie.Silent = $true
    $ie.Navigate("https://goldprice.org")
    Start-Sleep -Seconds 5
    
    if ($ie.Document) {
        $doc = $ie.Document
        $spans = $doc.getElementsByTagName("span")
        $goldPrice = $null
        foreach ($s in $spans) {
            $t = $s.innerText.Trim()
            if ($t -match '^[\d,]+\.\d{2}$') {
                $num = [double]($t -replace ',', '')
                if ($num -gt 1500 -and $num -lt 10000) {
                    $goldPrice = $num
                    break
                }
            }
        }
        if ($goldPrice) {
            $result.GOLD = @{
                value = $goldPrice
                source = "goldprice.org (IE COM)"
                unit = "USD/oz"
                confidence = "high"
                timestamp = $DateStr
            }
            Write-Log "  GOLD = $goldPrice [goldprice.org] OK" "OK"
        }
    }
    $ie.Quit()
} catch {
    Write-Log "  GOLD 采集失败: $($_.Exception.Message.Substring(0,80))" "WARN"
}

# ========== 原油 ==========
Write-Log ">> 采集WTI原油 (oilprice.com)..."
try {
    $ie2 = New-Object -ComObject InternetExplorer.Application
    $ie2.Visible = $false
    $ie2.Silent = $true
    $ie2.Navigate("https://oilprice.com")
    Start-Sleep -Seconds 5
    
    if ($ie2.Document) {
        $doc2 = $ie2.Document
        $bodyText = $doc2.body.innerText
        # oilprice.com格式: "WTI CRUDE\n104.6 +1.74" 或 "WTI CRUDE\n  91.13"
        if ($bodyText -match 'WTI\s*CRUDE[^0-9]*([0-9]{2,3}\.[0-9]{2})') {
            $oilPrice = [double]$matches[1]
            if ($oilPrice -gt 40 -and $oilPrice -lt 200) {
                $result.OIL = @{
                    value = $oilPrice
                    source = "oilprice.com (IE COM)"
                    unit = "USD/barrel (WTI)"
                    confidence = "high"
                    timestamp = $DateStr
                }
                Write-Log "  OIL = $oilPrice [oilprice.com] OK" "OK"
            }
        }
    }
    $ie2.Quit()
} catch {
    Write-Log "  OIL 采集失败: $($_.Exception.Message.Substring(0,80))" "WARN"
}

# ========== VIX (CBOE) ==========
Write-Log ">> 采集VIX (CBOE.com)..."
try {
    $ie3 = New-Object -ComObject InternetExplorer.Application
    $ie3.Visible = $false
    $ie3.Silent = $true
    $ie3.Navigate("https://www.cboe.com/tradable_products/vix")
    Start-Sleep -Seconds 5
    
    if ($ie3.Document) {
        $doc3 = $ie3.Document
        $bodyText = $doc3.body.innerText
        # CBOE格式: "VIX SPOT PRICE\n$30.61\n-1.42%"
        if ($bodyText -match 'VIX[^$]*?\$(\d{1,2}\.\d{2})') {
            $vixPrice = [double]$matches[1]
            if ($vixPrice -gt 5 -and $vixPrice -lt 100) {
                $result.VIX = @{
                    value = $vixPrice
                    source = "CBOE.com (IE COM)"
                    confidence = "high"
                    timestamp = $DateStr
                }
                Write-Log "  VIX = $vixPrice [CBOE.com] OK" "OK"
            }
        }
    }
    $ie3.Quit()
} catch {
    Write-Log "  VIX 采集失败: $($_.Exception.Message.Substring(0,80))" "WARN"
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
        # 合并已有的 macro 数据（新数据覆盖旧数据）
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

Write-Log "========== 采集完成 =========="
Write-Log "输出: $latestFile"

exit 0
