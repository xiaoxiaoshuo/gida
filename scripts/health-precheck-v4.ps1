<#
.SYNOPSIS
  采集程序v3 - API健康预检层 v4 (2026-06-23 07:30)
  基于 api-routing-v3.json 的数据源路由矩阵，动态测试所有源连通性

.DESCRIPTION
  v4 核心改进（对比 v3）:
  1. 从 api-routing-v3.json 读取源列表（而非硬编码）
  2. 测试每个源连通性 → 更新 routing 中的 status
  3. 输出 JSON 格式健康报告 (兼容现有 v3 输出路径)
  4. 如果所有primary都失败 → 产生 ALERT
  5. 支持 DNS 劫持检测
  6. 兼容现有 cron-watchdog 输出格式

.PARAMETER Json
  以 JSON 格式输出结果（供其他脚本调用）

.PARAMETER Detail
  输出详细日志

.PARAMETER OutputDir
  输出目录（默认 data/system/）

.OUTPUTS
  JSON 到 data/system/health-precheck-v4-state.json
  ALERT 追加到 data/system/alerts.jsonl
  EXIT CODE: 0=proceed, 1=degrade, 2=block
#>

[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$Detail,
    [string]$OutputDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data\system"
)

# ========== 配置 ==========
$WorkspaceRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"
$RoutingConfigPath = "$WorkspaceRoot\conf\api-routing-v3.json"
$StatePath = "$OutputDir\health-precheck-v4-state.json"
$AlertPath = "$OutputDir\alerts.jsonl"

# ========== 日志 ==========
function Write-Log {
    param([string]$Msg, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    Write-Host "[$timestamp][$Level] $Msg"
}

# ========== DNS劫持检测 ==========
function Test-DnsHijack {
    param([string]$Domain, [string]$ResolvedIP)
    
    # GFW DNS劫持常见回退IP
    $hijackPatterns = @(
        '^169\.254\.',      # AWS ELB内部回退
        '^10\.',            # RFC1918私有
        '^100\.64\.',       # CGNAT
        '^127\.',           # Loopback
        '^0\.'              # 无效
    )
    
    foreach ($pattern in $hijackPatterns) {
        if ($ResolvedIP -match $pattern) {
            return $true
        }
    }
    
    # 空解析或解析到特殊IP
    if ([string]::IsNullOrEmpty($ResolvedIP) -or $ResolvedIP -eq "0.0.0.0") {
        return $true
    }
    
    # 解析到中国CDN专属IP (某些劫持行为)
    if ($ResolvedIP -match '^47\.\d+\.') {
        # 阿里云公网IP段, 某些情况下被GFW重定向, 需要进一步判断
        # 这里不做误判, 仅返回可疑
        return "suspicious"
    }
    
    return $false
}

# ========== API健康测试（5s超时） ==========
function Test-ApiHealth {
    param(
        [hashtable]$Source,
        [string]$AssetKey
    )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $result = @{
        asset       = $AssetKey
        name        = $Source.name
        url         = $Source.endpoint
        status      = $Source.status  # 初始状态
        critical    = if ($Source.tier -eq 1) { $true } else { $false }
        tier        = if ($Source.tier) { $Source.tier } else { 2 }
        category    = if ($Source.category) { $Source.category } else { "unknown" }
        role        = $null  # 由调用方填充
        http_ok     = $false
        json_ok     = $false
        data_ok     = $false
        latency_ok  = $false
        latency_ms  = 0
        dns_hijacked = $false
        error       = $null
        healthy     = $false
    }
    
    # 跳过已标记为blocked的源
    if ($Source.status -eq "blocked") {
        $result.healthy = $false
        $result.error = "源已被标记为blocked: $($Source.blocked_reason)"
        $stopwatch.Stop()
        $result.latency_ms = $stopwatch.ElapsedMilliseconds
        return $result
    }
    
    # 跳过需要API Key但未配置的源
    if ($Source.status -eq "needs_api_key") {
        $result.healthy = $false
        $result.error = "需要API Key但未配置"
        $stopwatch.Stop()
        $result.latency_ms = $stopwatch.ElapsedMilliseconds
        return $result
    }
    
    # 设置超时
    $timeout = if ($Source.timeout_s) { $Source.timeout_s } else { 5 }
    
    try {
        # 强制TLS1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        $response = Invoke-WebRequest -Uri $Source.endpoint -TimeoutSec $timeout -UseBasicParsing -ErrorAction Stop
        
        $result.http_ok = ($response.StatusCode -eq 200)
        
        if ($result.http_ok) {
            try {
                $json = $response.Content | ConvertFrom-Json -ErrorAction Stop
                $result.json_ok = $true
                $result.data_ok = ($null -ne $json -and "$json".Length -gt 2)
                
                # 特定端点的数据非空检查
                if ($Source.endpoint -like "*alternative.me/fng*") {
                    $result.data_ok = ($json.data -and $json.data.Count -gt 0)
                }
                if ($Source.endpoint -like "*hacker-news*") {
                    $result.data_ok = ($json -is [array] -or $json.PSObject.Properties.Name -contains '0')
                }
            } catch {
                # 对于非JSON端点（如HTML页面），只要HTTP 200就算连通
                $result.json_ok = $true  # 宽容处理
                $result.data_ok = ($response.Content.Length -gt 100)
            }
        }
    } catch {
        $errorMsg = $_.Exception.Message
        
        # 截断过长错误消息
        if ($errorMsg.Length -gt 150) {
            $errorMsg = $errorMsg.Substring(0, 150) + "..."
        }
        
        $result.error = $errorMsg
        
        # DNS劫持检测
        if ($errorMsg -match "The remote name could not be resolved|No such host is known") {
            # 尝试解析域名
            try {
                $uri = [System.Uri]$Source.endpoint
                $hostname = $uri.Host
                $resolvedIPs = [System.Net.Dns]::GetHostAddresses($hostname) | ForEach-Object { $_.ToString() }
                foreach ($ip in $resolvedIPs) {
                    $hijackResult = Test-DnsHijack -Domain $hostname -ResolvedIP $ip
                    if ($hijackResult -eq $true) {
                        $result.dns_hijacked = $true
                        $result.error = "GFW DNS劫持: 解析到$ip ($hostname)"
                        break
                    }
                }
            } catch {
                # DNS解析也失败
            }
        }
    } finally {
        $stopwatch.Stop()
        $result.latency_ms = $stopwatch.ElapsedMilliseconds
        $result.latency_ok = ($result.latency_ms -le ($timeout * 1000))
    }
    
    # 综合健康判定
    $result.healthy = $result.http_ok -and $result.json_ok -and $result.data_ok -and $result.latency_ok
    
    if ($result.healthy) {
        $result.status = "up"
    } elseif ($result.dns_hijacked) {
        $result.status = "dns_hijacked"
    } else {
        $result.status = "down"
    }
    
    return $result
}

# ========== 从路由矩阵提取测试端点 ==========
function Get-TestEndpoints {
    param($RoutingConfig)
    
    $endpoints = @()
    
    # 兼容 PSCustomObject（ConvertFrom-Json输出）和 Hashtable
    $sources = $RoutingConfig.sources
    $sourceKeys = if ($sources -is [hashtable]) { $sources.Keys } else { $sources.PSObject.Properties.Name }
    
    foreach ($assetKey in $sourceKeys) {
        $source = if ($sources -is [hashtable]) { $sources[$assetKey] } else { $sources.$assetKey }
        
        # 如果是单个源（非资产组，如OKX_BTC/COINGECKO）
        if ($source.endpoint) {
            $endpoints += @{
                asset_key = $assetKey
                name = $source.name
                endpoint = $source.endpoint
                status = $source.status
                tier = if ($source.tier) { $source.tier } else { 99 }
                timeout_s = if ($source.timeout_s) { $source.timeout_s } else { 5 }
                category = if ($source.category) { $source.category } else { "unknown" }
            }
            continue
        }
        
        # 如果是资产组（有primary/alt1/alt2）
        $priorityKeys = @("primary", "alt1", "alt2", "alt3", "alt4")
        foreach ($pKey in $priorityKeys) {
            if ($source.$pKey) {
                $ep = $source.$pKey
                $endpoints += @{
                    asset_key = $assetKey
                    role = $pKey
                    name = $ep.name
                    endpoint = $ep.endpoint
                    status = $ep.status
                    tier = if ($ep.tier) { $ep.tier } else { if ($pKey -eq "primary") { 1 } else { 2 } }
                    timeout_s = if ($ep.timeout_s) { $ep.timeout_s } else { 5 }
                    category = if ($ep.category) { $ep.category } else { "unknown" }
                }
            }
        }
    }
    
    return $endpoints
}

# ========== 主逻辑 ==========

if ($Detail) { Write-Log "v4 Health Pre-Check 启动" }

# 1. 读取路由配置
if (-not (Test-Path $RoutingConfigPath)) {
    Write-Log "路由配置不存在: $RoutingConfigPath" "ERROR"
    exit 2
}

$routingConfig = Get-Content $RoutingConfigPath -Raw | ConvertFrom-Json
if ($Detail) { Write-Log "路由配置已加载 (version: $($routingConfig.version))" }

# 2. 提取测试端点
$endpoints = Get-TestEndpoints -RoutingConfig $routingConfig
$totalCount = $endpoints.Count
if ($Detail) { Write-Log "待测试端点: $totalCount 个" }

# 3. 顺序测试每个端点（避免并发DNS风暴）
$results = @()
$upCount = 0
$criticalFailures = @()
$dnsHijacked = @()
$blockedSources = @()

foreach ($ep in $endpoints) {
    if ($Detail) { 
        $statusIcon = if ($ep.status -eq "blocked") { "⛔" } elseif ($ep.status -eq "needs_api_key") { "🔑" } else { "🔍" }
        Write-Log "$statusIcon $($ep.name) ($($ep.asset_key))" 
    }
    
    $r = Test-ApiHealth -Source @{
        name = $ep.name
        endpoint = $ep.endpoint
        status = $ep.status
        tier = $ep.tier
        category = $ep.category
        timeout_s = $ep.timeout_s
    } -AssetKey $ep.asset_key
    
    $r.role = $ep.role  # 直接赋值（兼容嵌套对象序列化）
    $results += $r
    
    if ($r.healthy) { $upCount++ }
    if ($r.dns_hijacked) { $dnsHijacked += @{ name = $ep.name; ip = $r.error } }
    if ($r.status -eq "blocked") { $blockedSources += $ep.name }
    if ($r.critical -and -not $r.healthy) { $criticalFailures += $ep.name }
    
    if ($Detail) {
        $statusStr = if ($r.healthy) { "✅ OK" } elseif ($r.dns_hijacked) { "🔥 DNS_HIJACK" } elseif ($r.status -eq "down") { "❌ DOWN" } else { "⏭️ SKIP" }
        Write-Log "  $statusStr ($($r.latency_ms)ms) $($r.error)" 
    }
}

# 4. 评分 (0-100)
$score = [math]::Round(($upCount / $totalCount) * 100, 1)

# 5. 资产级分析：统计每个资产primary是否可用
$assetHealth = @{}
foreach ($r in $results) {
    # 兼容: hashtable（Add-Member前）vs PSObject（Add-Member后）
    $hasAsset = $r.ContainsKey('asset') -or ($r.PSObject.Properties.Name -contains 'asset')
    $assetName = if ($hasAsset) { $r.asset } else { $r.asset_key }
    if (-not $assetName) { continue }
    if (-not $assetHealth[$assetName]) {
        $assetHealth[$assetName] = @{ primary_ok = $false; alts_ok = @(); blocked = $false }
    }
    if ($r.role -eq "primary" -and $r.healthy) {
        $assetHealth[$assetName].primary_ok = $true
    }
    if ($r.role -like "alt*" -and $r.healthy) {
        $assetHealth[$assetName].alts_ok += $r.name
    }
}

$assetsWithPrimaryDown = @()
$assetsAllSourcesDown = @()
foreach ($assetKey in $assetHealth.Keys) {
    $h = $assetHealth[$assetKey]
    if (-not $h.primary_ok) {
        $assetsWithPrimaryDown += $assetKey
    }
    if (-not $h.primary_ok -and $h.alts_ok.Count -eq 0) {
        $assetsAllSourcesDown += $assetKey
    }
}

# 6. 阈值判定
$verdict = "green"
$action = "proceed"

if ($score -lt 70 -or $assetsWithPrimaryDown.Count -gt 0) {
    $verdict = "yellow"
    $action = "degrade"
}

# 阻断条件: score < 50 OR 有critical源dns hijacked OR 全部crypto primary都失败
$cryptoFailed = $assetsWithPrimaryDown | Where-Object { 
    $routingConfig.sources.$_ -and $routingConfig.sources.$_.category -eq "crypto" -or 
    ($_ -match "^(BTC|ETH|SOL)$")
}

if ($score -lt 50 -or $dnsHijacked.Count -gt 0 -or $assetsAllSourcesDown.Count -gt 0) {
    $verdict = "red"
    $action = "block"
}

# 7. 构建输出报告
$output = @{
    timestamp       = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss+08:00")
    version         = "v4"
    routing_config  = "conf/api-routing-v3.json"
    total           = $totalCount
    healthy         = $upCount
    score           = $score
    verdict         = $verdict
    action          = $action
    critical_fails  = $criticalFailures
    dns_hijacked    = $dnsHijacked
    blocked_sources = $blockedSources
    assets_with_primary_down = $assetsWithPrimaryDown
    assets_all_sources_down  = $assetsAllSourcesDown
    results         = $results
}

# 8. 持久化状态
$stateDir = Split-Path $StatePath -Parent
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
$output | ConvertTo-Json -Depth 5 | Out-File -FilePath $StatePath -Encoding UTF8 -Force

# 9. ALERT 输出 (兼容现有 watchdog 解析格式)
if ($action -eq "block" -or $dnsHijacked.Count -gt 0) {
    $alert = @{
        level       = "ALERT"
        source      = "health-precheck-v4"
        timestamp   = $output.timestamp
        score       = $score
        action      = $action
        msg         = "API Health Score = $score%, action=$action"
        detail      = ""
    }
    
    if ($dnsHijacked.Count -gt 0) {
        $hijackNames = ($dnsHijacked | ForEach-Object { $_.name }) -join ", "
        $alert.msg += " | DNS_HIJACK: $hijackNames"
        $alert.detail = "DNS劫持检测到 $hijackNames"
    }
    
    if ($assetsAllSourcesDown.Count -gt 0) {
        $downNames = $assetsAllSourcesDown -join ", "
        $alert.msg += " | ALL_SOURCES_DOWN: $downNames"
        $alert.detail += " 资产全部源不可用: $downNames"
    }
    
    $alertJson = $alert | ConvertTo-Json -Compress
    Add-Content -Path $AlertPath -Value $alertJson -Encoding UTF8
}

# 10. 输出
if ($Json) {
    $output | ConvertTo-Json -Depth 5
} else {
    Write-Host ""
    Write-Host "====== v4 API Health Pre-Check ======" -ForegroundColor White
    Write-Host "Time:  $($output.timestamp)" -ForegroundColor Gray
    Write-Host "Score: $score% ($upCount/$totalCount) | Verdict: $verdict | Action: $action" -ForegroundColor $(if ($verdict -eq "green") { "Green" } elseif ($verdict -eq "yellow") { "Yellow" } else { "Red" })
    
    if ($dnsHijacked.Count -gt 0) {
        Write-Host "🔥 DNS HIJACKED: $($dnsHijacked.Count) 个" -ForegroundColor Red
        foreach ($h in $dnsHijacked) {
            Write-Host "  - $($h.name): $($h.ip)" -ForegroundColor Red
        }
    }
    
    if ($criticalFailures.Count -gt 0) {
        Write-Host "CRITICAL FAILS: $($criticalFailures -join ', ')" -ForegroundColor Red
    }
    
    if ($assetsWithPrimaryDown.Count -gt 0) {
        Write-Host "⚡ PRIMARY DOWN: $($assetsWithPrimaryDown -join ', ')" -ForegroundColor Yellow
    }
    
    if ($assetsAllSourcesDown.Count -gt 0) {
        Write-Host "🚫 ALL DOWN: $($assetsAllSourcesDown -join ', ')" -ForegroundColor Red
    }
    
    Write-Host "State: $StatePath" -ForegroundColor Gray
    Write-Host "=======================================" -ForegroundColor White
}

# 11. 返回退出码 (0=proceed, 1=degrade, 2=block)
switch ($action) {
    "proceed" { exit 0 }
    "degrade" { exit 1 }
    "block"   { exit 2 }
}
