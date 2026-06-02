# etf-monitor.ps1 - 美股 BTC ETF 资金流监控
# 用途: 在关键时间窗口（每日 04:00 GMT+8 = 20:00 UTC 前日）监控 ETF 资金流
# 数据源: Coinglass / Farside Investors (公开页面)
# 输出: data/etf-flow-YYYY-MM-DD.json
# 触发: 手动 / 04:00-04:30 GMT+8 窗口

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"
Set-Location $RepoRoot

$DateStr = Get-Date -Format "yyyy-MM-dd"
$TimeStr = Get-Date -Format "HH:mm:ss"
$LogFile = "$RepoRoot\memory\$DateStr.md"

function Write-EtfLog {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Level] $TimeStr - [ETF-MONITOR] $Message"
    Write-Host $entry
    Add-Content -Path $LogFile -Value "  - $entry" -Encoding UTF8
}

Write-EtfLog "===== ETF 资金流监控开始 ====="

# 方案 1: 尝试 Coinglass API (可能需要 key)
# 方案 2: Farside Investors 公开页面
$urls = @(
    @{ name = "Farside_Investors_BTC_ETF"; url = "https://farside.co.uk/btc/" },
    @{ name = "Farside_Investors_ETH_ETF"; url = "https://farside.co.uk/eth/" },
    @{ name = "Coinglass_ETF"; url = "https://www.coinglass.com/etf/bitcoin" }
)

$results = @{}
foreach ($source in $urls) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $r = Invoke-WebRequest -Uri $source.url -TimeoutSec 15 -UseBasicParsing -UserAgent "Mozilla/5.0"
        $results[$source.name] = @{
            status = $r.StatusCode
            length = $r.Content.Length
            snippet = $r.Content.Substring(0, [Math]::Min(2000, $r.Content.Length))
        }
        Write-EtfLog "✅ $($source.name): HTTP $($r.StatusCode), $($r.Content.Length) 字节"
    } catch {
        $msg = $_.Exception.Message
        if ($msg.Length -gt 80) { $msg = $msg.Substring(0, 80) }
        Write-EtfLog "❌ $($source.name): $msg" "WARN"
        $results[$source.name] = @{ error = $msg }
    }
}

# 保存原始数据
$output = @{
    timestamp = "$DateStr $TimeStr"
    sources = $results
    note = "ETF 资金流监控 - 等待进一步解析"
}

$output | ConvertTo-Json -Depth 6 | Set-Content "$RepoRoot\data\etf-flow-$DateStr.json"
Write-EtfLog "原始数据已保存: data\etf-flow-$DateStr.json"

# 尝试从 Farside 提取最近一天的净流入（粗略正则）
if ($results.Farside_Investors_BTC_ETF.snippet) {
    $content = $results.Farside_Investors_BTC_ETF.snippet
    # 寻找 "Today's Net Flow" 附近的数字
    if ($content -match 'today["\s>:]*([+-]?\$?[\d,.]+)\s*m') {
        Write-EtfLog "💰 今日 BTC ETF 净流入 (粗略): $matches[1]M" "INFO"
    } else {
        Write-EtfLog "未匹配到 BTC ETF 净流入数据（需手工解析）" "WARN"
    }
}

Write-EtfLog "===== ETF 监控完成 ====="
