# cron-watchdog.ps1
# AINewsCollector_6h + HourlyPriceCollector + DailyCollector 全栈健康监控
# v2 (2026-06-04 06:40 重建, 因 git reset --hard 清掉原版)
# 设计: 错峰 30min 监控 (00:30 / 06:30 / 12:30 / 18:30), 失败写 ALERT + 历史 jsonl
# 使用全路径避免 Scheduled Task 在 SYSTEM 下 CWD 问题

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$workspace = "C:\Users\Administrator\clawd\agents\workspace-gid"
$alertDir = Join-Path $workspace "ALERTS"
$historyFile = Join-Path $workspace "data\system\cron-health-history.jsonl"

# 确保目录存在
if (!(Test-Path $alertDir)) { New-Item -ItemType Directory -Path $alertDir -Force | Out-Null }
$historyDir = Split-Path $historyFile -Parent
if (!(Test-Path $historyDir)) { New-Item -ItemType Directory -Path $historyDir -Force | Out-Null }

$alerts = @()
$health = @{
  timestamp = $timestamp
  checks = @{}
  overall = "healthy"
}

# 检查 1: AINewsCollector_6h Last Result
try {
  $taskInfo = schtasks /Query /TN "AINewsCollector_6h" /V /FO LIST 2>&1 | Out-String
  if ($taskInfo -match "Last Result:\s+(\S+)") {
    $lastResult = $matches[1]
    if ($lastResult -eq "0") {
      $health.checks.AINewsCollector_6h = "healthy"
    } else {
      $health.checks.AINewsCollector_6h = "unhealthy (Last Result = $lastResult)"
      $alerts += "AINewsCollector_6h Last Result = $lastResult (expected 0)"
    }
  } else {
    $health.checks.AINewsCollector_6h = "unknown"
  }
} catch {
  $health.checks.AINewsCollector_6h = "error: $_"
  $alerts += "AINewsCollector_6h check failed: $_"
}

# 检查 2: HourlyPriceCollector Last Result
try {
  $taskInfo = schtasks /Query /TN "HourlyPriceCollector" /V /FO LIST 2>&1 | Out-String
  if ($taskInfo -match "Last Result:\s+(\S+)") {
    $lastResult = $matches[1]
    if ($lastResult -eq "0") {
      $health.checks.HourlyPriceCollector = "healthy"
    } else {
      $health.checks.HourlyPriceCollector = "unhealthy (Last Result = $lastResult)"
      $alerts += "HourlyPriceCollector Last Result = $lastResult (expected 0)"
    }
  } else {
    $health.checks.HourlyPriceCollector = "unknown"
  }
} catch {
  $health.checks.HourlyPriceCollector = "error: $_"
  $alerts += "HourlyPriceCollector check failed: $_"
}

# 检查 3: hacker-news_latest.json mtime (超 8h 报警)
$hnLatest = Join-Path $workspace "data\tech\hacker-news_latest.json"
if (Test-Path $hnLatest) {
  $age = (Get-Date) - (Get-Item $hnLatest).LastWriteTime
  $hoursOld = [math]::Round($age.TotalHours, 1)
  if ($age.TotalHours -gt 8) {
    $health.checks.HN_latest_freshness = "stale (${hoursOld}h)"
    $alerts += "hacker-news_latest.json stale: ${hoursOld}h (max 8h)"
  } else {
    $health.checks.HN_latest_freshness = "fresh (${hoursOld}h)"
  }
} else {
  $health.checks.HN_latest_freshness = "missing"
  $alerts += "hacker-news_latest.json missing"
}

# 检查 4: cron_wrapper.log 最近 50 行错误关键词
$wrapperLog = Join-Path $workspace "data\ai\cron_wrapper.log"
if (Test-Path $wrapperLog) {
  $recentErrors = Get-Content $wrapperLog -Tail 50 -ErrorAction SilentlyContinue | Select-String -Pattern "error|FAIL|not recognized" -CaseSensitive:$false
  if ($recentErrors) {
    $health.checks.wrapper_log_errors = "$($recentErrors.Count) errors in last 50 lines"
    $alerts += "cron_wrapper.log 末尾 50 行有 $($recentErrors.Count) 个错误"
  } else {
    $health.checks.wrapper_log_errors = "clean"
  }
} else {
  $health.checks.wrapper_log_errors = "missing"
}

# 检查 5: 上次 GitHub 推送距今 (超 24h 报警)
try {
  $gitLog = (git -C $workspace log -1 --format="%ct" 2>&1) | Out-String
  $gitLog = $gitLog.Trim()
  if ($gitLog -match "^\d+$") {
    $epoch = [double]$gitLog
    $lastPush = (Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0).AddSeconds($epoch)
    $age = (Get-Date) - $lastPush
    $hoursOld = [math]::Round($age.TotalHours, 1)
    if ($hoursOld -gt 24) {
      $health.checks.last_push_age = "stale (${hoursOld}h)"
      $alerts += "Last GitHub push: ${hoursOld}h ago (max 24h)"
    } else {
      $health.checks.last_push_age = "fresh (${hoursOld}h)"
    }
  } else {
    $health.checks.last_push_age = "error: $gitLog"
  }
} catch {
  $health.checks.last_push_age = "error: $_"
}

# 写历史
try {
  $health | ConvertTo-Json -Compress | Add-Content -Path $historyFile
} catch {
  Write-Host "WARN: failed to write history: $_"
}

# 输出结果
$health | ConvertTo-Json -Depth 5 | Write-Host

# 报警 (写 ALERT 文件)
if ($alerts.Count -gt 0) {
  $health.overall = "unhealthy"
  $alertFile = Join-Path $alertDir "$(Get-Date -Format 'yyyy-MM-dd-HHmm')-cron-watchdog.md"
  $alertContent = @"
# CRON Watchdog ALERT - $timestamp

**Overall**: UNHEALTHY
**Alerts**: $($alerts.Count) 项

## Failed Checks

$($alerts | ForEach-Object { "- $_" } | Out-String)

## Health Snapshot

```json
$($health | ConvertTo-Json -Depth 5)
```

## 修复建议

1. 检查 Last Result 不为 0 的 Scheduled Task, 重新注册或修复 wrapper 脚本
2. 检查 stale JSON 文件, 手动触发对应 cron
3. 检查 cron_wrapper.log 末尾错误, 对照根因修复
4. 检查 last_push_age, 手动 git push (绕过 GFW)

---
*由 cron-watchdog.ps1 v2 自动生成 (2026-06-04 06:40 重建)*
"@
  $alertContent | Out-File -FilePath $alertFile -Encoding utf8
  Write-Host ""
  Write-Host "ALERT written: $alertFile"
  exit 1
} else {
  Write-Host ""
  Write-Host "All cron healthy"
  exit 0
}
