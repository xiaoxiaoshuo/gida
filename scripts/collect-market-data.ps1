# collect-market-data.ps1 - 市场数据采集脚本 v2
# 用途: 采集加密货币价格、VIX指数、黄金原油价格
# 数据源: cn.bing.com 搜索聚合 + 国内可用API
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

# 加载System.Web（用于URL编码）
try {
    Add-Type -AssemblyName System.Web 2>$null
} catch {}

# 确保输出目录存在
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# 日志函数
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $msg = "[$Level] $(Get-Date -Format 'HH:mm:ss') - $Message"
    Write-Host $msg
    Add-Content -Path "$OutputDir\collect-market.log" -Value $msg -Encoding UTF8
}

# ========== 数据采集函数 ==========
function Invoke-BingSearch {
    param([string]$Query, [int]$MaxChars = 3000)
    try {
        $encoded = [System.Web.HttpUtility]::UrlEncode($Query)
        $url = "https://cn.bing.com/search?q=$encoded"
        $headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        }
        $response = Invoke-WebRequest -Uri $url -Headers $headers -TimeoutSec 10 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            $content = $response.Content
            # 截断到指定长度
            if ($content.Length -gt $MaxChars) {
                $content = $content.Substring(0, $MaxChars)
            }
            return $content
        }
    } catch {
        Write-Log "Bing搜索失败: $($_.Exception.Message)" "ERROR"
    }
    return $null
}

function Extract-Price {
    # 从文本中提取价格数字
    param([string]$Text, [string]$Symbol)
    $patterns = @(
        '\$[\d,]+\.?\d*',      # $123,456.78
        '[\d,]+\.?\d*\s*(?:USD|美元)',  # 123456.78 USD
        '(?:price|cost|价格)[:\s]*[\$¥]?[\d,]+\.?\d*',
        '(?:BTC|ETH|SOL)[:\s]*[\$¥]?[\d,]+\.?\d*'
    )
    foreach ($p in $patterns) {
        if ($Text -match $p) {
            $match = $matches[0]
            # 清理数字
            $price = $match -replace '[^\d.]', ''
            return [double]$price
        }
    }
    return $null
}

# ========== 主程序 ==========
Write-Log "========== 市场数据采集开始 =========="
Write-Log "采集时间: $DateStr"

$result = @{
    timestamp = $DateStr
    crypto = @{}
    macro = @{}
    errors = @()
}

# 1. 采集加密货币价格
Write-Log ">> 采集加密货币价格 (BTC/ETH/SOL)..."

$cryptoQueries = @{
    "BTC" = "Bitcoin BTC 价格 今日 USD"
    "ETH" = "Ethereum ETH 以太坊 价格 今日"
    "SOL" = "Solana SOL 价格 今日"
}

foreach ($symbol in $cryptoQueries.Keys) {
    Write-Log "  查询: $($cryptoQueries[$symbol])..."
    $content = Invoke-BingSearch -Query $cryptoQueries[$symbol]
    if ($content) {
        $price = Extract-Price -Text $content -Symbol $symbol
        if ($price -and $price -gt 0) {
            $result.crypto[$symbol] = @{
                price = $price
                source = "cn.bing.com"
                query = $cryptoQueries[$symbol]
            }
            Write-Log "  $symbol -> \$$price" "OK"
        } else {
            Write-Log "  $symbol 价格提取失败" "WARN"
            $result.errors += "$symbol 价格提取失败"
        }
    } else {
        Write-Log "  $symbol 查询失败" "ERROR"
        $result.errors += "$symbol 查询失败"
    }
}

# 2. 采集VIX恐慌指数
Write-Log ">> 采集VIX恐慌指数..."
$content = Invoke-BingSearch -Query "VIX恐慌指数 今日"
if ($content) {
    $vix = Extract-Price -Text $content -Symbol "VIX"
    if ($vix -and $vix -gt 0) {
        $result.macro["VIX"] = @{
            value = $vix
            source = "cn.bing.com"
        }
        Write-Log "  VIX -> $vix" "OK"
    }
} else {
    Write-Log "  VIX采集失败" "ERROR"
    $result.errors += "VIX采集失败"
}

# 3. 采集黄金价格
Write-Log ">> 采集黄金价格..."
$content = Invoke-BingSearch -Query "黄金价格 今日 USD"
if ($content) {
    $gold = Extract-Price -Text $content -Symbol "GOLD"
    if ($gold -and $gold -gt 0) {
        $result.macro["GOLD"] = @{
            value = $gold
            source = "cn.bing.com"
        }
        Write-Log "  GOLD -> \$$gold" "OK"
    }
} else {
    Write-Log "  黄金数据采集失败" "ERROR"
    $result.errors += "黄金采集失败"
}

# 4. 采集原油价格
Write-Log ">> 采集原油价格..."
$content = Invoke-BingSearch -Query "原油价格 WTI 今日"
if ($content) {
    $oil = Extract-Price -Text $content -Symbol "OIL"
    if ($oil -and $oil -gt 0) {
        $result.macro["OIL"] = @{
            value = $oil
            source = "cn.bing.com"
        }
        Write-Log "  OIL -> \$$oil" "OK"
    }
} else {
    Write-Log "  原油数据采集失败" "ERROR"
    $result.errors += "原油采集失败"
}

# ========== 保存结果 ==========
Write-Log "========== 采集完成 =========="
$jsonFile = "$OutputDir\market-data_$Timestamp.json"
$result | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonFile -Encoding UTF8
Write-Log "数据文件: $jsonFile"

if ($result.errors.Count -gt 0) {
    Write-Log "错误数量: $($result.errors.Count)" "WARN"
    Write-Log "错误详情: $($result.errors -join '; ')"
} else {
    Write-Log "全部采集成功!" "OK"
}

exit $(if ($result.errors.Count -gt 0) { 1 } else { 0 })
