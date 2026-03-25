# ============================================================
# collect-market-data.ps1 - 市场数据采集脚本
# 用途: 采集加密货币价格、VIX指数、黄金原油价格
# 数据源: cn.bing.com 搜索聚合 (中国可访问)
# 频率: 每日执行 (建议北京时间 09:00 / 21:00)
# ============================================================

param(
    [string]$OutputDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data\market",
    [switch]$Verbose
)

# ========== 基础配置 ==========
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$DateStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# 确保输出目录存在
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# 日志函数
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $msg = "[$Level] $(Get-Date -Format 'HH:mm:ss') - $Message"
    Write-Host $msg
    Add-Content -Path "$OutputDir\collect-market.log" -Value $msg
}

# ========== 数据采集函数 ==========
function Invoke-BingSearch {
    param([string]$Query, [int]$MaxChars = 3000)
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

function Extract-Price {
    # 从搜索结果文本中尝试提取价格数字
    param([string]$Text, [string]$Symbol)
    # 简单正则：匹配 $数字 或 数字 USD 等格式
    $patterns = @(
        "(?i)$Symbol[^\d]*(\d{1,3}(?:,\d{3})*(?:\.\d+)?)",
        "(?i)(\d{1,3}(?:,\d{3})*(?:\.\d+)?)\s*$Symbol",
        "(?i)(?:price|cost|val)[^\d]*(\d{1,3}(?:,\d{3})*(?:\.\d+)?)"
    )
    foreach ($p in $patterns) {
        if ($Text -match $p) {
            return $matches[1] -replace ",", ""
        }
    }
    return $null
}

# ========== 主采集流程 ==========
Write-Log "========== 市场数据采集开始 =========="
Write-Log "采集时间: $DateStr"

$report = @{
    timestamp = $DateStr
    data = @{}
    errors = @()
}

# ---------- 1. 加密货币价格 ----------
Write-Log ">> 采集加密货币价格 (BTC/ETH/SOL)..."

$cryptoQueries = @{
    "BTC 比特币价格 今日" = "BTC"
    "ETH 以太坊价格 今日" = "ETH"
    "SOL Solana 价格 今日" = "SOL"
}

$cryptoData = @()
foreach ($query in $cryptoQueries.GetEnumerator()) {
    Write-Log "  查询: $($query.Key)"
    $content = Invoke-BingSearch -Query $query.Key -MaxChars 4000
    if ($content) {
        $price = Extract-Price -Text $content -Symbol $query.Value
        $cryptoData += @{
            symbol = $query.Value
            query = $query.Key
            price_extracted = $price
            raw_length = $content.Length
        }
        if ($price) {
            Write-Log "  $($query.Value): $price [提取成功]"
        } else {
            Write-Log "  $($query.Value): 价格未提取成功 (原始数据长度: $($content.Length))" "WARN"
        }
    } else {
        Write-Log "  $($query.Key) 查询失败" "ERROR"
        $report.errors += "Crypto query failed: $($query.Key)"
    }
    Start-Sleep -Seconds 2  # 避免请求过快
}
$report.data.crypto = $cryptoData

# ---------- 2. VIX 恐慌指数 ----------
Write-Log ">> 采集VIX恐慌指数..."
$vixContent = Invoke-BingSearch -Query "VIX恐慌指数 今日 2026" -MaxChars 3000
if ($vixContent) {
    $report.data.vix = @{
        query = "VIX恐慌指数 今日 2026"
        raw_length = $vixContent.Length
        # VIX通常在10-30范围，尝试提取
        raw_snippet = $vixContent.Substring(0, [Math]::Min(500, $vixContent.Length))
    }
    Write-Log "  VIX数据已采集 (长度: $($vixContent.Length))"
} else {
    Write-Log "  VIX采集失败" "ERROR"
    $report.errors += "VIX query failed"
}

# ---------- 3. 黄金价格 ----------
Write-Log ">> 采集黄金价格..."
$goldContent = Invoke-BingSearch -Query "gold price today 2026" -MaxChars 3000
if ($goldContent) {
    $report.data.gold = @{
        query = "gold price today 2026"
        raw_length = $goldContent.Length
        raw_snippet = $goldContent.Substring(0, [Math]::Min(500, $goldContent.Length))
    }
    Write-Log "  黄金数据已采集 (长度: $($goldContent.Length))"
} else {
    Write-Log "  黄金数据采集失败" "ERROR"
    $report.errors += "Gold query failed"
}

# ---------- 4. 原油价格 ----------
Write-Log ">> 采集原油价格..."
$oilContent = Invoke-BingSearch -Query "crude oil price today 2026" -MaxChars 3000
if ($oilContent) {
    $report.data.oil = @{
        query = "crude oil price today 2026"
        raw_length = $oilContent.Length
        raw_snippet = $oilContent.Substring(0, [Math]::Min(500, $oilContent.Length))
    }
    Write-Log "  原油数据已采集 (长度: $($oilContent.Length))"
} else {
    Write-Log "  原油数据采集失败" "ERROR"
    $report.errors += "Oil query failed"
}

# ---------- 5. 加密货币市场情绪 (通过知乎) ----------
Write-Log ">> 采集加密货币市场情绪..."
$sentimentContent = Invoke-BingSearch -Query "比特币 BTC 市场分析 2026年3月" -MaxChars 3000
if ($sentimentContent) {
    $report.data.sentiment = @{
        query = "比特币 BTC 市场分析 2026年3月"
        raw_length = $sentimentContent.Length
    }
    Write-Log "  市场情绪数据已采集"
} else {
    Write-Log "  市场情绪采集失败" "ERROR"
}

# ========== 保存结果 ==========
$jsonPath = "$OutputDir\market-data_$Timestamp.json"
$report | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonPath -Encoding UTF8

# 保存最新数据的软链接/副本
$latestPath = "$OutputDir\market-data_latest.json"
$report | ConvertTo-Json -Depth 5 | Out-File -FilePath $latestPath -Encoding UTF8

Write-Log "========== 采集完成 =========="
Write-Log "数据文件: $jsonPath"
Write-Log "错误数量: $($report.errors.Count)"

if ($report.errors.Count -gt 0) {
    Write-Log "错误详情: $($report.errors -join '; ')" "WARN"
}
