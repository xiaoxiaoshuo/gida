# ============================================================
# collect-policy.ps1 - 政策动态采集脚本
# 用途: 美联储FOMC、中国央行政策、芯片出口管制
# 数据源:
#   - federalreserve.gov (FOMC会议日程/纪要)
#   - cn.bing.com (中国央行政策、芯片出口管制)
# 频率: 每日执行 (建议北京时间 08:30 / 20:30)
# ============================================================

param(
    [string]$OutputDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data\policy",
    [switch]$Verbose
)

# ========== 基础配置 ==========
$ErrorActionPreference = "Continue"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$DateStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $msg = "[$Level] $(Get-Date -Format 'HH:mm:ss') - $Message"
    Write-Host $msg
    Add-Content -Path "$OutputDir\collect-policy.log" -Value $msg
}

function Invoke-WebFetch {
    param([string]$Url, [int]$MaxChars = 5000)
    try {
        $result = web-fetch --url $Url --maxChars $MaxChars 2>$null
        if ($result -and $result.status -eq 200) {
            return $result.text
        }
    } catch {
        Write-Log "Fetch失败: $Url" "ERROR"
    }
    return $null
}

function Invoke-BingSearch {
    param([string]$Query, [int]$MaxChars = 5000)
    $encoded = [System.Web.HttpUtility]::UrlEncode($Query)
    $url = "https://cn.bing.com/search?q=$encoded"
    try {
        $result = web-fetch --url $url --maxChars $MaxChars 2>$null
        if ($result -and $result.status -eq 200) {
            return $result.text
        }
    } catch {}
    return $null
}

# ========== 主采集流程 ==========
Write-Log "========== 政策动态采集开始 =========="
Write-Log "采集时间: $DateStr"

$report = @{
    timestamp = $DateStr
    data = @{}
    errors = @()
}

# ---------- 1. 美联储FOMC ----------
Write-Log ">> 采集美联储FOMC..."

# FOMC会议日程 (官方直连)
Write-Log "  FOMC日程页..."
$fomcCal = Invoke-WebFetch -Url "https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm" -MaxChars 8000
if ($fomcCal) {
    $report.data.fomc_calendar = @{
        url = "https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm"
        raw_length = $fomcCal.Length
        raw_snippet = $fomcCal.Substring(0, [Math]::Min(2000, $fomcCal.Length))
    }
    Write-Log "  FOMC日程采集成功 (长度: $($fomcCal.Length))"
} else {
    Write-Log "  FOMC日程采集失败" "ERROR"
    $report.errors += "FOMC calendar fetch failed"
}

# FOMC最新声明
Write-Log "  FOMC最新动态..."
$fomcNews = Invoke-BingSearch -Query "Federal Reserve FOMC statement 2026" -MaxChars 5000
if ($fomcNews) {
    $report.data.fomc_news = @{
        source = "cn.bing.com"
        raw_length = $fomcNews.Length
        snippet = $fomcNews.Substring(0, [Math]::Min(1000, $fomcNews.Length))
    }
    Write-Log "  FOMC动态采集成功"
} else {
    Write-Log "  FOMC动态采集失败" "ERROR"
    $report.errors += "FOMC news search failed"
}

# 美联储利率决议
Write-Log "  美联储利率决议..."
$fedRate = Invoke-BingSearch -Query "Federal Reserve interest rate decision March 2026" -MaxChars 5000
if ($fedRate) {
    $report.data.fed_rate = @{
        source = "cn.bing.com"
        raw_length = $fedRate.Length
    }
    Write-Log "  利率决议数据采集成功"
}

# ---------- 2. 中国央行政策 ----------
Write-Log ">> 采集中国央行政策..."
$pbocQueries = @(
    "中国人民银行 货币政策 2026",
    "PBOC monetary policy 2026",
    "LPR 贷款市场报价利率 2026",
    "央行 降准 降息 2026"
)

$pbocData = @()
foreach ($q in $pbocQueries) {
    Write-Log "  查询: $q"
    $content = Invoke-BingSearch -Query $q -MaxChars 4000
    if ($content) {
        $pbocData += @{
            query = $q
            raw_length = $content.Length
            snippet = $content.Substring(0, [Math]::Min(500, $content.Length))
        }
        Write-Log "  成功 (长度: $($content.Length))"
    } else {
        Write-Log "  失败: $q" "ERROR"
    }
    Start-Sleep -Seconds 2
}
$report.data.pboc = $pbocData

# ---------- 3. 芯片出口管制 ----------
Write-Log ">> 采集芯片出口管制动态..."
$exportControlQueries = @(
    "chip semiconductor export control US China 2026",
    "美国芯片出口管制 2026",
    "NVIDIA AMD chip ban China 2026",
    "半导体设备出口许可 2026"
)

$exportControlData = @()
foreach ($q in $exportControlQueries) {
    Write-Log "  查询: $q"
    $content = Invoke-BingSearch -Query $q -MaxChars 4000
    if ($content) {
        $exportControlData += @{
            query = $q
            raw_length = $content.Length
            snippet = $content.Substring(0, [Math]::Min(500, $content.Length))
        }
        Write-Log "  成功 (长度: $($content.Length))"
    } else {
        Write-Log "  失败: $q" "ERROR"
    }
    Start-Sleep -Seconds 2
}
$report.data.export_control = $exportControlData

# ---------- 4. 地缘政治新闻 ----------
Write-Log ">> 采集地缘政治新闻..."
$geoQueries = @(
    "US China trade war tariff 2026",
    "geopolitical news March 2026",
    "中美关系 最新动态 2026"
)

$geoData = @()
foreach ($q in $geoQueries) {
    Write-Log "  查询: $q"
    $content = Invoke-BingSearch -Query $q -MaxChars 4000
    if ($content) {
        $geoData += @{
            query = $q
            raw_length = $content.Length
            snippet = $content.Substring(0, [Math]::Min(500, $content.Length))
        }
        Write-Log "  成功"
    }
    Start-Sleep -Seconds 2
}
$report.data.geopolitics = $geoData

# ---------- 5. 宏观经济指标 ----------
Write-Log ">> 采集宏观经济指标..."
$macroQueries = @(
    "US CPI inflation February 2026",
    "非农就业 失业率 2026年3月",
    "GDP growth forecast 2026"
)

$macroData = @()
foreach ($q in $macroQueries) {
    Write-Log "  查询: $q"
    $content = Invoke-BingSearch -Query $q -MaxChars 4000
    if ($content) {
        $macroData += @{
            query = $q
            raw_length = $content.Length
            snippet = $content.Substring(0, [Math]::Min(500, $content.Length))
        }
        Write-Log "  成功"
    }
    Start-Sleep -Seconds 2
}
$report.data.macro = $macroData

# ========== 保存结果 ==========
$jsonPath = "$OutputDir\policy-data_$Timestamp.json"
$report | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonPath -Encoding UTF8

$latestPath = "$OutputDir\policy-data_latest.json"
$report | ConvertTo-Json -Depth 5 | Out-File -FilePath $latestPath -Encoding UTF8

Write-Log "========== 采集完成 =========="
Write-Log "数据文件: $jsonPath"
Write-Log "错误数量: $($report.errors.Count)"
