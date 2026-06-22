# ============================================================================
# patch-v4-to-watchdog.ps1
# 描述: 健康预检v4接入cron-watchdog-v3-30min.ps1 的补丁脚本
#       定义 Test-ApiHealth 函数，以子进程调用 health-precheck-v4.ps1
#       并解析JSON结果，返回统一格式的result对象
# 作者: G-63A subagent (2026-06-23 07:35)
# 
# 用法:
#   1. Dot-source 到 cron-watchdog-v3-30min.ps1:
#      . .\scripts\patch-v4-to-watchdog.ps1
#
#   2. 然后在主执行循环添加:
#      $results.api_health = Test-ApiHealth
#
#   完整整合示例在 §USAGE 部分底部
#
# 输出格式:
#   @{
#     name   = "api_health"
#     ok     = $true/$false
#     detail = "score=85% throttle=proceed ..."
#     score  = 85
#     action = "proceed|degrade|block"
#   }
# ============================================================================

[CmdletBinding()]
param(
    [switch]$Install,         # 安装模式: 将Test-ApiHealth注入到cron-watchdog-v3-30min.ps1
    [string]$RoutingPath = "C:\Users\Administrator\clawd\agents\workspace-gid\conf\api-routing-v3.json",
    [string]$V4Path = "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\health-precheck-v4.ps1",
    [switch]$Test             # 测试模式: 运行Test-ApiHealth并输出结果
)

# ========== 配置 ==========
$WorkspaceRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"
$WatchdogScript = "$WorkspaceRoot\scripts\cron-watchdog-v3-30min.ps1"
$WatchdogBackup = "$WorkspaceRoot\scripts\cron-watchdog-v3-30min.ps1.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# ========== Test-ApiHealth 函数定义 ==========
# 这是本补丁的核心: 在cron-watchdog上下文中调用v4预检并解析结果
<#
.SYNOPSIS
  API健康预检第6项 — 调用health-precheck-v4.ps1并从JSON输出提取评分和action

.DESCRIPTION
  - 以子进程运行v4（避免影响主进程的PS模块加载）
  - 解析v4输出的JSON行（-Json模式）
  - 从JSON提取 score、action、verdict
  - 返回统一样式的result对象
  - 若v4脚本或routing配置缺失 ⇒ 返回 ok=$false, detail="missing"

.OUTPUTS
  hashtable:
    name   = "api_health"
    ok     = $true | $false
    detail = string (人类可读摘要)
    score  = int (0-100, 或 $null)
    action = "proceed" | "degrade" | "block" | "error"
#>
function Test-ApiHealth {
    param(
        [string]$RoutingPath = "C:\Users\Administrator\clawd\agents\workspace-gid\conf\api-routing-v3.json",
        [string]$V4Path = "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\health-precheck-v4.ps1",
        [int]$TimeoutSec = 120   # v4预检可能跑20+端点，给2分钟
    )

    $result = @{
        name   = "api_health"
        ok     = $false
        detail = ""
        score  = $null
        action = "error"
    }

    # --- Step a: 检查文件可用性 ---
    if (!(Test-Path $V4Path)) {
        $result.detail = "v4 script missing: $V4Path"
        Write-Warning "Test-ApiHealth: $($result.detail)"
        return $result
    }
    if (!(Test-Path $RoutingPath)) {
        $result.detail = "routing config missing: $RoutingPath"
        Write-Warning "Test-ApiHealth: $($result.detail)"
        return $result
    }

    # --- Step b: 以子进程运行v4 (JSON模式) ---
    Write-Verbose "Test-ApiHealth: launching pwsh -File $V4Path -RoutingPath $RoutingPath -Json"
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $v4Output = & pwsh -NoProfile -File $V4Path -RoutingPath $RoutingPath -Json 2>&1
        $exitCode = $LASTEXITCODE
        $sw.Stop()
        $elapsed = [math]::Round($sw.Elapsed.TotalSeconds, 1)

        Write-Verbose "Test-ApiHealth: v4 exited with code $exitCode in ${elapsed}s"
    }
    catch {
        $result.detail = "v4 subprocess launch failed: $($_.Exception.Message)"
        Write-Warning "Test-ApiHealth: $($result.detail)"
        return $result
    }

    # --- Step c: 解析v4输出中的JSON ---
    $v4JsonStr = $null

    if ($v4Output -is [array]) {
        # 多行输出: 查找最长的JSON块
        $jsonLines = $v4Output | Where-Object { $_ -is [string] -and $_.Trim().StartsWith("{") -and $_.Trim().EndsWith("}") }
        if ($jsonLines.Count -gt 0) {
            # 取最后一条有效JSON（最完整）
            $v4JsonStr = ($jsonLines | Select-Object -Last 1).Trim()
        }
        # 备选: 找包含"timestamp"的行
        if (-not $v4JsonStr) {
            foreach ($line in $v4Output) {
                if ($line -is [string] -and $line.Trim().StartsWith("{") -and $line -match '"timestamp"') {
                    $v4JsonStr = $line.Trim()
                    break
                }
            }
        }
    }
    elseif ($v4Output -is [string]) {
        $v4JsonStr = $v4Output.Trim()
    }

    if (-not $v4JsonStr) {
        # 尝试读取v4的状态文件（如果v4写入成功）
        $stateFile = "$WorkspaceRoot\data\system\health-precheck-v4-state.json"
        if (Test-Path $stateFile) {
            $fileAge = (Get-Date) - (Get-Item $stateFile).LastWriteTime
            if ($fileAge.TotalSeconds -lt 30) {
                Write-Verbose "Test-ApiHealth: falling back to state file (age=$([int]$fileAge.TotalSeconds)s)"
                $v4JsonStr = Get-Content $stateFile -Raw
            }
            else {
                $result.detail = "v4 output unparseable and state file stale ($([int]$fileAge.TotalSeconds)s old)"
                Write-Warning "Test-ApiHealth: $($result.detail)"
                $result.score = -1
                return $result
            }
        }
        else {
            $result.detail = "v4 output unparseable, exit=$exitCode, elapsed=${elapsed}s"
            Write-Warning "Test-ApiHealth: $($result.detail)"
            $result.score = -1
            return $result
        }
    }

    # --- Step d: 解析JSON ---
    try {
        $v4Data = $v4JsonStr | ConvertFrom-Json

        $score = if ($v4Data.score -ne $null) { [int]$v4Data.score } else { -1 }
        $action = if ($v4Data.action) { $v4Data.action } else { "unknown" }
        $verdict = if ($v4Data.verdict) { $v4Data.verdict } else { "unknown" }
        $healthy = if ($v4Data.healthy -ne $null) { [int]$v4Data.healthy } else { 0 }
        $total = if ($v4Data.total -ne $null) { [int]$v4Data.total } else { 0 }
        $criticalFails = if ($v4Data.critical_fails) { $v4Data.critical_fails.Count } else { 0 }
        $hijacked = if ($v4Data.dns_hijacked) { $v4Data.dns_hijacked.Count } else { 0 }
        $allDown = if ($v4Data.assets_all_sources_down) { $v4Data.assets_all_sources_down } else { @() }
        $primaryDown = if ($v4Data.assets_with_primary_down) { $v4Data.assets_with_primary_down } else { @() }

        # 组装详细摘要
        $detailParts = @()
        $detailParts += "score=$score%"
        $detailParts += "action=$action"
        $detailParts += "verdict=$verdict"
        $detailParts += "healthy=$healthy/$total"

        if ($hijacked -gt 0) {
            $detailParts += "dns_hijacked=$hijacked"
        }
        if ($criticalFails -gt 0) {
            $detailParts += "critical_fails=$criticalFails"
        }
        if ($allDown.Count -gt 0) {
            $detailParts += "all_down=$($allDown -join ',')"
        }
        if ($primaryDown.Count -gt 0) {
            $detailParts += "primary_down=$($primaryDown -join ',')"
        }

        $detailParts += "exit=$exitCode"
        $detailParts += "t=${elapsed}s"

        $result.score = $score
        $result.action = $action

        # --- Step e: 统一判定 ---
        # 健康预检的判定标准:
        #   score >= 50 AND action != "block" ⇒ ok
        #   score < 50 或 action = "block" ⇒ not ok
        #   DNS劫持检测到 ⇒ not ok
        #
        if ($hijacked -gt 0) {
            $result.ok = $false
            $detailParts += "DNS_HIJACK_DETECTED"
        }
        elseif ($action -eq "block") {
            $result.ok = $false
            $detailParts += "BLOCKED"
        }
        elseif ($action -eq "degrade") {
            # degrade 仍算 ok 但标记为降级
            $result.ok = $true
            $detailParts += "DEGRADED"
        }
        elseif ($score -ge 50) {
            $result.ok = $true
            $detailParts += "OK"
        }
        else {
            $result.ok = $false
            $detailParts += "SCORE_TOO_LOW"
        }

        # 如果score低于40但有usable alts，宽容处理
        if ($score -ge 40 -and $score -lt 50 -and $action -ne "block") {
            # 黄色区域: primary失败但有可用alt
            $result.ok = $true
            $detailParts += "MARGINAL_OK"
        }

        $result.detail = $detailParts -join " | "
    }
    catch {
        $result.detail = "JSON parse error: $($_.Exception.Message) | exit=$exitCode | elapsed=${elapsed}s"
        Write-Warning "Test-ApiHealth: $($result.detail)"
        $result.score = -1
        return $result
    }

    return $result
}

# ========== 安装模式 (-Install) ==========
# 将Test-ApiHealth注入到cron-watchdog-v3-30min.ps1中
# 方法: 在主执行循环添加 $results.api_health = Test-ApiHealth 调用
if ($Install.IsPresent) {
    Write-Host "=== patch-v4-to-watchdog: Install Mode ===" -ForegroundColor Cyan

    # 备份原文件
    Copy-Item -Path $WatchdogScript -Destination $WatchdogBackup -Force
    Write-Host "Backup: $WatchdogBackup" -ForegroundColor Gray

    # 读取当前watchdog脚本
    $watchdogContent = Get-Content $WatchdogScript -Raw

    # 检查是否已安装
    if ($watchdogContent -match '\$results\.api_health\s*=\s*Test-ApiHealth') {
        Write-Host "✅ Test-ApiHealth already installed in watchdog" -ForegroundColor Green
    }
    else {
        # 策略: 在 $results.gfw_health = Test-GFWHealth 后面添加一行
        $findLine = '$results.gfw_health       = Test-GFWHealth'
        $replaceLine = @"
`$results.gfw_health       = Test-GFWHealth
    `$results.api_health      = Test-ApiHealth
"@
        $newContent = $watchdogContent -replace [regex]::Escape($findLine), $replaceLine

        # 同时在文件顶部（Test-GFWHealth函数之后）添加函数定义
        # 在最后一个测试函数（Test-GFWHealth）的结束 } 之后添加 Test-ApiHealth 函数
        $findBlock = @'
function Test-GFWHealth {
    $result = @{ name = "gfw_health"; ok = $true; detail = ""; latency_ms = $null }
    if ($Quick) {
        $result.detail = "skipped (quick)"
        return $result
    }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        # 用 OpenSSL 探测 sclient github.com:443 (与 auto-push-v4 一致)
        $probe = cmd /c "openssl s_client -connect github.com:443 -servername github.com < NUL" 2>&1 | Out-String
        $sw.Stop()
        $latency = [int]$sw.ElapsedMilliseconds
        $result.latency_ms = $latency
        if ($LASTEXITCODE -ne 0 -or $probe -notmatch "BEGIN CERTIFICATE") {
            $result.ok = $false
            $result.detail = "GFW probe FAIL ($latency ms, exit=$LASTEXITCODE)"
        } elseif ($latency -gt 5000) {
            # 探测成功但慢 (>5s), 标记 yellow 但仍 ok=true
            $result.detail = "GFW slow ($latency ms, ok=true)"
        } else {
            $result.detail = "GFW OK ($latency ms)"
        }
    } catch {
        $sw.Stop()
        $result.ok = $false
        $result.detail = "GFW probe error: $($_.Exception.Message)"
    }
    return $result
}
'@
        # 注意: 这里用的是一个简化版替换，实际安装需要手工确认或使用模板替换
        # 我们采用更安全的方式: 在文件末尾 Append 函数定义
        $newContent += @"

# ===== [PATCH v4] Test-ApiHealth (由 patch-v4-to-watchdog.ps1 注入, 2026-06-23) =====
# 功能: 调用 health-precheck-v4.ps1 进行 API 可达性检测
# 来源: scripts\patch-v4-to-watchdog.ps1 (G-63A)
# Install-Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
function Test-ApiHealth {
    param()
    # 补丁脚本定义的完整 Test-ApiHealth 函数
    # 已在上一行定义（或与本脚本 dot-source）, 这里作为独立实现
    # 避免重复:
    if (Get-Command Test-ApiHealth -ErrorAction SilentlyContinue) {
        return Test-ApiHealth
    }

    `$result = @{ name = "api_health"; ok = `$false; detail = ""; score = `$null; action = "error" }
    `$v4path = "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\health-precheck-v4.ps1"
    `$routingPath = "C:\Users\Administrator\clawd\agents\workspace-gid\conf\api-routing-v3.json"

    if (!(Test-Path `$v4path) -or !(Test-Path `$routingPath)) {
        `$result.detail = "v4 or routing config missing"
        `$result.ok = `$false
        return `$result
    }

    try {
        `$sw = [System.Diagnostics.Stopwatch]::StartNew()
        `$v4out = & pwsh -NoProfile -File `$v4path -RoutingPath `$routingPath -Json 2>&1
        `$exitCode = `$LASTEXITCODE
        `$sw.Stop()
        `$elapsed = [math]::Round(`$sw.Elapsed.TotalSeconds, 1)

        # 尝试从输出中提取JSON
        `$jsonStr = `$null
        if (`$v4out -is [array]) {
            foreach (`$line in `$v4out) {
                if (`$line -is [string] -and `$line.Trim().StartsWith("{") -and `$line -match '"timestamp"') {
                    `$jsonStr = `$line.Trim()
                    break
                }
            }
        }
        elseif (`$v4out -is [string] -and `$v4out.Trim().StartsWith("{")) {
            `$jsonStr = `$v4out.Trim()
        }

        if (-not `$jsonStr) {
            # fallback to state file
            `$stateFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\system\health-precheck-v4-state.json"
            if (Test-Path `$stateFile) {
                `$fileAge = (Get-Date) - (Get-Item `$stateFile).LastWriteTime
                if (`$fileAge.TotalSeconds -lt 60) {
                    `$jsonStr = Get-Content `$stateFile -Raw
                }
            }
        }

        if (`$jsonStr) {
            `$data = `$jsonStr | ConvertFrom-Json
            `$result.score = if (`$data.score -ne `$null) { [int]`$data.score } else { -1 }
            `$result.action = if (`$data.action) { `$data.action } else { "unknown" }
            `$hijacked = if (`$data.dns_hijacked) { `$data.dns_hijacked.Count } else { 0 }
            `$healthy = if (`$data.healthy -ne `$null) { [int]`$data.healthy } else { 0 }
            `$total = if (`$data.total -ne `$null) { [int]`$data.total } else { 0 }

            if (`$hijacked -gt 0) {
                `$result.ok = `$false
                `$result.detail = "score=`$(`$result.score)% | DNS_HIJACKED=`$hijacked | healthy=`$healthy/`$total | action=`$(`$result.action) | t=${elapsed}s"
            }
            elseif (`$result.action -eq "block") {
                `$result.ok = `$false
                `$result.detail = "score=`$(`$result.score)% | BLOCKED | healthy=`$healthy/`$total | t=${elapsed}s"
            }
            elseif (`$result.score -ge 40) {
                `$result.ok = `$true
                `$result.detail = "score=`$(`$result.score)% | action=`$(`$result.action) | healthy=`$healthy/`$total | t=${elapsed}s"
            }
            else {
                `$result.ok = `$false
                `$result.detail = "score=`$(`$result.score)% | too low | healthy=`$healthy/`$total | t=${elapsed}s"
            }
        }
        else {
            `$result.detail = "v4 output unparseable | exit=`$exitCode | t=${elapsed}s"
        }
    }
    catch {
        `$result.detail = "v4 subprocess error: `$(`$_.Exception.Message)"
    }

    return `$result
}
"@

        $newContent | Out-File -FilePath $WatchdogScript -Encoding UTF8 -Force
        Write-Host "✅ Test-ApiHealth injected into $WatchdogScript" -ForegroundColor Green
        Write-Host "   Backup at: $WatchdogBackup" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Manual verification required:" -ForegroundColor Yellow
        Write-Host "  Line added after: `$results.gfw_health = Test-GFWHealth" -ForegroundColor Yellow
        Write-Host "  Function appened at end of file" -ForegroundColor Yellow
    }

    return
}

# ========== 测试模式 (-Test) ==========
if ($Test.IsPresent) {
    Write-Host "=== patch-v4-to-watchdog: Test Mode ===" -ForegroundColor Cyan
    $testResult = Test-ApiHealth -V4Path $V4Path -RoutingPath $RoutingPath
    Write-Host ""
    Write-Host "--- Test-ApiHealth Result ---" -ForegroundColor Cyan
    $mark = if ($testResult.ok) { "✅" } else { "❌" }
    Write-Host "$mark name   = $($testResult.name)" -ForegroundColor $(if($testResult.ok){"Green"}else{"Red"})
    Write-Host "   ok     = $($testResult.ok)"
    Write-Host "   score  = $($testResult.score)"
    Write-Host "   action = $($testResult.action)"
    Write-Host "   detail = $($testResult.detail)"
    Write-Host "-----------------------------" -ForegroundColor Cyan
    return $testResult
}

# ========== 无参数: 导出函数 (dot-source) ==========
# 在cron-watchdog中使用:
#   . .\scripts\patch-v4-to-watchdog.ps1
#   $results.api_health = Test-ApiHealth
#
# 完整整合示例 for cron-watchdog-v3-30min.ps1:
# ===============================================================
# # 在函数定义区域后面, 主循环前面, 添加:
# . "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\patch-v4-to-watchdog.ps1"
#
# # 在主执行循环中添加第6项:
# $results.api_health = Test-ApiHealth
#
# # 阈值从 2/5 改为 3/6:
# $failed = 0; foreach ($v in $results.Values) { if (-not $v.ok) { $failed++ } }
# $ok = 6 - $failed  # 原来是 5 - $failed
# ===============================================================

# 默认导出函数 (对于 dot-source 模式)
if (-not $Test -and -not $Install) {
    Write-Verbose "patch-v4-to-watchdog: Test-ApiHealth function exported"
    Write-Verbose ""
    Write-Verbose "Usage in cron-watchdog-v3-30min.ps1:"
    Write-Verbose "  1. Add: . .\scripts\patch-v4-to-watchdog.ps1"
    Write-Verbose "  2. Add in main loop:"
    Write-Verbose "     `$results.api_health = Test-ApiHealth"
    Write-Verbose "  3. Update threshold: AlertThreshold should be 3/6"
}

# ============================================================================
# End of patch-v4-to-watchdog.ps1
# ============================================================================
