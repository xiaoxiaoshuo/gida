# ============================================================================
# cron-watchdog-v3-30min.ps1
# 描述: 30min 周期 cron 健康检查 v3 (错峰 00:30/06:30/12:30/18:30 + 30min 增量)
# 作者: gida-intel subagent (G-50, 2026-06-05 08:05)
# 上一版: cron-watchdog.ps1 (6h 间隔, 00:30/06:30/12:30/18:30 触发, 间隔真空 6h)
# 目标: 解决 v2 6h 间隔真空 (00:30 → 06:30 中间 6h 失败不捕获)
#       把 5 项核心检查的探测频率从 6h 提升到 30min, 故障延迟 6h → 30min
#
# 设计原则:
#   - 5 项核心检查: HourlyPrice / AINews / GitHub Trending / auto-push / GFW 探测
#   - 30min 周期: 错峰 (00:30 + 30min = 01:00, 01:30, 02:00, ... 每 30min 一次)
#   - 输出: data/system/cron-health-watchdog.jsonl (JSONL 追加)
#   - 失败阈值: 2/5 失败 = ALERT 写 ALERTS/cron-watchdog-{date}.md
#   - 跨 24h 累计报告: 每日 23:00 整合为 data/system/cron-health-daily-{date}.md
#
# 用法:
#   pwsh -File scripts/cron-watchdog-v3-30min.ps1
#   pwsh -File scripts/cron-watchdog-v3-30min.ps1 -Date "2026-06-05_08-30"
#   pwsh -File scripts/cron-watchdog-v3-30min.ps1 -Quick   # 跳过 auto-push (10s → 3s)
#
# 注册到 Task Scheduler (管理员 PowerShell):
#   $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
#     -Argument '-NoProfile -File "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\cron-watchdog-v3-30min.ps1"'
#   $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
#     -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 365)
#   Register-ScheduledTask -TaskName 'CronWatchdogV3_30min' `
#     -Action $action -Trigger $trigger `
#     -Principal (New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest) `
#     -Description '30min 周期 cron 健康检查 v3 (5 项检查 + JSONL 追加 + 阈值 2/5 ALERT)'
#
# 输出:
#   - data/system/cron-health-watchdog.jsonl  (主输出, 追加)
#   - ALERTS/cron-watchdog-{date}.md          (失败 ≥ 2/5 时)
#   - data/system/cron-health-daily-{date}.md (每日 23:00 整合报告, 由 daily-rollup 触发)
# ============================================================================

[CmdletBinding()]
param(
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd_HH-mm'),
    [int]$AlertThreshold = 2,    # 5 项检查中, 失败 ≥ 2 = 写 ALERT
    [switch]$Quick,              # 跳过耗时检查 (auto-push), 快速模式
    [switch]$DryRun              # 仅打印不写日志
)

$ErrorActionPreference = "Continue"
$Workspace    = "C:\Users\Administrator\clawd\agents\workspace-gid"
$DataDir      = Join-Path $Workspace "data"
$SysDir       = Join-Path $DataDir "system"
$HealthLog    = Join-Path $SysDir "cron-health-watchdog.jsonl"
$AlertDir     = Join-Path $Workspace "ALERTS"
$SchTasks     = "C:\Windows\System32\schtasks.exe"

# 阈值常量 (可被 -AlertThreshold 覆盖)
$MAX_PRICE_AGE_HOURS   = 2      # HourlyPrice 文件 mtime 超过 2h = 失败
$MAX_AI_NEWS_AGE_HOURS = 14     # AINews 文件 mtime 超过 14h = 失败 (06:00 触发后应 6h 内有)
$MAX_GH_AGE_HOURS      = 30     # GitHub Trending mtime 超过 30h = 失败 (cron-ainews 6h 周期 + 1 周观察期余量)
$MAX_PUSH_AGE_HOURS    = 30     # 上次 auto-push 成功超过 30h = 失败
$GFW_PROBE_TIMEOUT_SEC = 8      # GFW 探测超时

# 确保目录存在
if (!(Test-Path $SysDir))   { New-Item -ItemType Directory -Path $SysDir   -Force | Out-Null }
if (!(Test-Path $AlertDir)) { New-Item -ItemType Directory -Path $AlertDir -Force | Out-Null }
$logDir = Split-Path $HealthLog -Parent
if (!(Test-Path $logDir))   { New-Item -ItemType Directory -Path $logDir   -Force | Out-Null }

# ============================================================================
# 检查函数 (5 项核心)
# ============================================================================

# 检查 1: HourlyPrice 数据新鲜度
function Test-HourlyPrice {
    $f = Join-Path $DataDir "prices\prices_latest.json"
    $result = @{ name = "hourly_price"; ok = $false; detail = ""; age_min = $null }
    if (!(Test-Path $f)) {
        $result.detail = "missing: $f"
        return $result
    }
    $age = (Get-Date) - (Get-Item $f).LastWriteTime
    $ageMin = [math]::Round($age.TotalMinutes, 1)
    $result.age_min = $ageMin
    if ($age.TotalHours -gt $MAX_PRICE_AGE_HOURS) {
        $result.detail = "stale: ${ageMin}min (max $($MAX_PRICE_AGE_HOURS)h)"
    } else {
        $result.ok = $true
        $result.detail = "fresh: ${ageMin}min"
    }
    return $result
}

# 检查 2: AINews 数据新鲜度 (跨 cron-ainews-0400 + AINewsCollector_6h)
function Test-AINews {
    $f = Join-Path $DataDir "ai\ai-news_latest.json"
    $result = @{ name = "ai_news"; ok = $false; detail = ""; age_min = $null }
    if (!(Test-Path $f)) {
        $result.detail = "missing: $f"
        return $result
    }
    $age = (Get-Date) - (Get-Item $f).LastWriteTime
    $ageMin = [math]::Round($age.TotalMinutes, 1)
    $result.age_min = $ageMin
    if ($age.TotalHours -gt $MAX_AI_NEWS_AGE_HOURS) {
        $result.detail = "stale: ${ageMin}min (max $($MAX_AI_NEWS_AGE_HOURS)h)"
    } else {
        $result.ok = $true
        $result.detail = "fresh: ${ageMin}min"
    }
    return $result
}

# 检查 3: GitHub Trending 数据新鲜度
function Test-GitHubTrending {
    $f = Join-Path $DataDir "tech\github-trending_latest.md"
    $result = @{ name = "github_trending"; ok = $false; detail = ""; age_min = $null }
    if (!(Test-Path $f)) {
        $result.detail = "missing: $f"
        return $result
    }
    $age = (Get-Date) - (Get-Item $f).LastWriteTime
    $ageMin = [math]::Round($age.TotalMinutes, 1)
    $result.age_min = $ageMin
    if ($age.TotalHours -gt $MAX_GH_AGE_HOURS) {
        $result.detail = "stale: ${ageMin}min (max $($MAX_GH_AGE_HOURS)h)"
    } else {
        $result.ok = $true
        $result.detail = "fresh: ${ageMin}min"
    }
    return $result
}

# 检查 4: auto-push 上次成功时间
function Test-AutoPush {
    $result = @{ name = "auto_push"; ok = $false; detail = ""; age_min = $null }
    # 跳过: Quick 模式 / DryRun
    if ($Quick -or $DryRun) {
        $result.ok = $true
        $result.detail = "skipped (quick/dryrun)"
        return $result
    }
    try {
        $gitLog = (git -C $Workspace log -1 --format="%ct" 2>&1) | Out-String
        $gitLog = $gitLog.Trim()
        if ($gitLog -match "^\d+$") {
            $epoch = [double]$gitLog
            $lastPush = (Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0).AddSeconds($epoch)
            $age = (Get-Date) - $lastPush
            $ageMin = [math]::Round($age.TotalMinutes, 1)
            $result.age_min = $ageMin
            if ($age.TotalHours -gt $MAX_PUSH_AGE_HOURS) {
                $result.detail = "stale: ${ageMin}min (max $($MAX_PUSH_AGE_HOURS)h)"
            } else {
                $result.ok = $true
                $result.detail = "fresh: ${ageMin}min"
            }
        } else {
            $result.detail = "git log parse error: $gitLog"
        }
    } catch {
        $result.detail = "git error: $($_.Exception.Message)"
    }
    return $result
}

# 检查 5: GFW 健康度 (OpenSSL 探测 github.com)
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

# ============================================================================
# 写 ALERT
# ============================================================================
function Write-Alert {
    param(
        [hashtable]$Results,
        [int]$Failed,
        [string]$Date
    )
    $failedChecks = @(); foreach ($v in $Results.Values) { if (-not $v.ok) { $failedChecks += $v } }
    $alertFile = Join-Path $AlertDir "cron-watchdog-$($Date -replace '_','-').md"
    $content = @"
# CRON Watchdog v3 ALERT - $Date

**Overall**: UNHEALTHY (failed $Failed / 5)
**Threshold**: failed >= $AlertThreshold

## Failed Checks

$($failedChecks | ForEach-Object { "- **$($_.name)**: $($_.detail)" } | Out-String)

## All Checks Snapshot

| Check | Status | Detail |
|-------|--------|--------|
$($Results.GetEnumerator() | ForEach-Object { "| $($_.Key) | $(if($_.Value.ok){'✅'}else{'❌'}) | $($_.Value.detail) |" } | Out-String)

## 修复建议

1. **hourly_price stale**: 检查 HourlyPriceCollector 任务 LastRunTime, 手动触发
2. **ai_news stale**: 检查 AINewsCollector_6h + AINewsCollector_0400, 手动触发
3. **github_trending stale**: 检查 GhTrending_v6_3layer, 手动跑一次
4. **auto_push stale**: 检查 auto-push-v4 失败原因, 手动 git push 或 bundle
5. **gfw_health FAIL**: GFW 阻断 443, 等待 6h 缓解窗口或用 proxychains

---
*由 cron-watchdog-v3-30min.ps1 自动生成 (G-50, 2026-06-05 08:05)*
"@
    if (-not $DryRun) {
        $content | Out-File -FilePath $alertFile -Encoding UTF8
    }
    Write-Host ""
    Write-Host "ALERT written: $alertFile" -ForegroundColor Red
    return $alertFile
}

# ============================================================================
# Main
# ============================================================================
Write-Host "[$(Get-Date -Format 'HH:mm:ss')] cron-watchdog-v3 ($Date) starting..." -ForegroundColor Cyan

$startTime = Get-Date
$results = [ordered]@{}
$results.hourly_price     = Test-HourlyPrice
$results.ai_news          = Test-AINews
$results.github_trending  = Test-GitHubTrending
$results.auto_push        = Test-AutoPush
$results.gfw_health       = Test-GFWHealth

$failed = 0; foreach ($v in $results.Values) { if (-not $v.ok) { $failed++ } }
$ok     = 5 - $failed
$elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)

# 输出控制台
Write-Host ""
Write-Host "=== Results ($elapsed s) ===" -ForegroundColor Cyan
foreach ($key in $results.Keys) {
    $r = $results[$key]
    $mark = if ($r.ok) { "✅" } else { "❌" }
    $color = if ($r.ok) { "Green" } else { "Red" }
    Write-Host "  $mark $key : $($r.detail)" -ForegroundColor $color
}
Write-Host ""
Write-Host "Summary: $ok/5 OK, $failed/5 FAILED" -ForegroundColor $(if($failed -eq 0){"Green"}else{"Yellow"})

# 写 JSONL 日志
$entry = [ordered]@{
    timestamp = (Get-Date -Format "o")
    date      = $Date
    ok        = $ok
    failed    = $failed
    elapsed_s = $elapsed
    results   = $results
    threshold = $AlertThreshold
}
if (-not $DryRun) {
    try {
        $entry | ConvertTo-Json -Compress -Depth 5 | Add-Content -Path $HealthLog -Encoding UTF8
    } catch {
        Write-Host "WARN: failed to write health log: $_" -ForegroundColor Yellow
    }
}

# 触发 ALERT
if ($failed -ge $AlertThreshold) {
    $alertFile = Write-Alert -Results $results -Failed $failed -Date $Date
    exit 1
}

Write-Host ""
Write-Host "✅ All checks within threshold ($AlertThreshold)" -ForegroundColor Green
exit 0
