# health-precheck-v3.ps1
# 采集程序 v3 - API 健康预检层 (P0, 2026-06-05 07:48 GMT+8 实施)
# 来源: G-47B 设计 (2026-06-05 06:36)
# 目的: 每次 cron 任务启动前 5-10s 扫描所有外部 API,评分 < 70% 降级, < 50% 阻断

[CmdletBinding()]
param(
    [switch]$Json,           # 输出 JSON 格式
    [switch]$Detail          # 详细日志 (避免与 CmdletBinding 通用 Verbose 冲突)
)

# 配置文件路径
$ConfigPath = "C:\Users\Administrator\clawd\agents\workspace-gid\data\system\health-precheck-v3-config.json"
$StatePath = "C:\Users\Administrator\clawd\agents\workspace-gid\data\system\health-precheck-v3-state.json"

# 默认 API 端点配置 (派单方 7:48 初始化)
$DefaultEndpoints = @(
    # === 加密货币 (critical) ===
    @{ name="okx_btc";          url="https://www.okx.com/api/v5/market/ticker?instId=BTC-USDT"; timeout=5; critical=$true;  category="crypto" }
    @{ name="binance_btc";      url="https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT"; timeout=5; critical=$true; category="crypto" }
    @{ name="cryptocompare_btc";url="https://min-api.cryptocompare.com/data/price?fsym=BTC&tsyms=USD"; timeout=10; critical=$false; category="crypto" }
    
    # === 情绪指标 ===
    @{ name="alternative_fng";  url="https://api.alternative.me/fng/?limit=1"; timeout=10; critical=$false; category="sentiment" }
    
    # === AI/HN 数据 ===
    @{ name="hn_topstories";    url="https://hacker-news.firebaseio.com/v0/topstories.json"; timeout=10; critical=$false; category="ai" }
    
    # === GitHub (JS 渲染, 走 web_fetch 失败, 不参与预检) ===
    # @{ name="github_trending";  url="https://github.com/trending"; timeout=15; critical=$false; category="tech"; note="JS 渲染" }
)

# 健康判定四要素: HTTP 200 + JSON 解析 + 数据非空 + 延迟 ≤ SLA
function Test-ApiHealth {
    param($Endpoint)
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $result = @{
        name        = $Endpoint.name
        url         = $Endpoint.url
        critical    = $Endpoint.critical
        category    = $Endpoint.category
        http_ok     = $false
        json_ok     = $false
        data_ok     = $false
        latency_ok  = $false
        latency_ms  = 0
        error       = $null
    }
    
    try {
        $response = Invoke-WebRequest -Uri $Endpoint.url -TimeoutSec $Endpoint.timeout -UseBasicParsing -ErrorAction Stop
        $result.http_ok = ($response.StatusCode -eq 200)
        
        if ($result.http_ok) {
            try {
                $json = $response.Content | ConvertFrom-Json -ErrorAction Stop
                $result.json_ok = $true
                
                # 数据非空判定 (按端点类型)
                if ($Endpoint.name -like "*fng*") {
                    $result.data_ok = ($json.data -and $json.data.Count -gt 0)
                } elseif ($Endpoint.name -like "*hn*") {
                    $result.data_ok = ($json -is [array] -or $json.PSObject.Properties.Name -contains '0')
                } else {
                    $result.data_ok = ($null -ne $json -and "$json".Length -gt 5)
                }
            } catch {
                $result.error = "JSON parse: $_"
            }
        }
    } catch {
        $result.error = "$_"
    } finally {
        $stopwatch.Stop()
        $result.latency_ms = $stopwatch.ElapsedMilliseconds
        $result.latency_ok = ($result.latency_ms -le ($Endpoint.timeout * 1000))
    }
    
    # 综合健康
    $result.healthy = $result.http_ok -and $result.json_ok -and $result.data_ok -and $result.latency_ok
    return $result
}

# 主流程
$results = @()
$healthyCount = 0
$criticalFailures = @()

foreach ($ep in $DefaultEndpoints) {
    if ($Detail) { Write-Host "[CHECK] $($ep.name) ($($ep.url))" -ForegroundColor Cyan }
    $r = Test-ApiHealth -Endpoint $ep
    $results += $r
    if ($r.healthy) { $healthyCount++ }
    if ($ep.critical -and -not $r.healthy) { $criticalFailures += $ep.name }
    
    if ($Detail) {
        $status = if ($r.healthy) { "OK" } else { "FAIL" }
        Write-Host "  $status ($($r.latency_ms)ms) $($r.error)" -ForegroundColor $(if ($r.healthy) { "Green" } else { "Red" })
    }
}

# 评分 (0-100)
$totalCount = $DefaultEndpoints.Count
$score = [math]::Round(($healthyCount / $totalCount) * 100, 1)

# 阈值判定
$verdict = "green"
$action = "proceed"
if ($score -lt 70) {
    $verdict = "yellow"
    $action = "degrade_offline_buffer"
}
if ($score -lt 50 -or $criticalFailures.Count -gt 0) {
    $verdict = "red"
    $action = "block_alert"
}

# 输出
$output = @{
    timestamp    = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss+08:00")
    total        = $totalCount
    healthy      = $healthyCount
    score        = $score
    verdict      = $verdict
    action       = $action
    critical_fails = $criticalFailures
    results      = $results
}

# 状态持久化
$stateDir = Split-Path $StatePath -Parent
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
$output | ConvertTo-Json -Depth 5 | Out-File -FilePath $StatePath -Encoding UTF8 -Force

# 报告
if ($Json) {
    $output | ConvertTo-Json -Depth 5
} else {
    Write-Host ""
    Write-Host "====== v3 API Health Pre-Check ======" -ForegroundColor White
    Write-Host "Time:  $($output.timestamp)" -ForegroundColor Gray
    Write-Host "Score: $score% ($healthyCount/$totalCount) | Verdict: $verdict | Action: $action" -ForegroundColor $(if ($verdict -eq "green") { "Green" } elseif ($verdict -eq "yellow") { "Yellow" } else { "Red" })
    if ($criticalFailures.Count -gt 0) {
        Write-Host "CRITICAL FAILS: $($criticalFailures -join ', ')" -ForegroundColor Red
    }
    Write-Host "State: $StatePath" -ForegroundColor Gray
    Write-Host "=====================================" -ForegroundColor White
}

# 返回退出码 (供其他 cron 调用)
# 0 = proceed, 1 = degrade, 2 = block
switch ($action) {
    "proceed" { exit 0 }
    "degrade_offline_buffer" { exit 1 }
    "block_alert" { exit 2 }
}
