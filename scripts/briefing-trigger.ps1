#!/usr/bin/env pwsh
<#
.SYNOPSIS
    briefing-trigger.ps1 — 简报自动触发器 (v1.0)
.DESCRIPTION
    检查是否需要生成简报，基于以下条件（任一满足即触发）:
    1. 上次简报年龄 > 12h → 强制过期简报
    2. BTC 24h变化 > 5% → 事件驱动简报
    3. F&G 24h变化 > 10点 → 情绪异动简报
    4. 被 collector-master.ps1 调用 + 距上次简报>4h → 定时简报

    输出触发信号到 data/system/briefing-trigger-signal.json
    Exit code: 0=未触发, 1=已触发简报
.NOTES
    版本: 1.0 (2026-06-24)
    设置: 可被 cron 每 30min 调用，或由 collector-master 作为后置步骤
#>

$ErrorActionPreference = "Continue"
$base = "C:\Users\Administrator\clawd\agents\workspace-gid"
$signalFile = "$base\data\system\briefing-trigger-signal.json"
$briefingDir = "$base\data\briefing"
$pricesFile = "$base\data\market\prices_latest.json"
$fngFile = "$base\data\market\fear-greed_latest.json"
$collectorMasterConfig = "$base\system\collector-master-config.json"

$now = Get-Date
Write-Host "[TRIGGER] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') — 简报触发条件检查" -ForegroundColor Cyan

# ===== 1. 读取上次简报时间 =====
$lastBriefingTime = $null
$lastBriefingFile = $null

# 从 briefing 目录查最新文件
$briefings = Get-ChildItem "$briefingDir\*.md" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending
$briefingJsonFiles = Get-ChildItem "$briefingDir\*.json" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending

$allBriefingFiles = @($briefings) + @($briefingJsonFiles)
if ($allBriefingFiles.Count -gt 0) {
    $latest = $allBriefingFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $lastBriefingTime = $latest.LastWriteTime
    $lastBriefingFile = $latest.FullName
    $ageHours = ($now - $lastBriefingTime).TotalHours
    Write-Host "  最后简报: $(Split-Path -Path $lastBriefingFile -Leaf) — $("{0:N1}" -f $ageHours)h 前" -ForegroundColor Gray
} else {
    $ageHours = [double]::MaxValue
    Write-Host "  简报目录为空 — 强制触发" -ForegroundColor Yellow
}

# ===== 2. 读取 BTC 价格 =====
$btcPrice = $null
$btc24hChange = $null
if (Test-Path $pricesFile) {
    try {
        $prices = Get-Content $pricesFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $btcPrice = $prices.crypto.BTC.price
        Write-Host "  BTC: $btcPrice (来自 prices_latest)" -ForegroundColor Gray
    } catch {
        Write-Host "  [WARN] prices_latest.json 解析失败: $_" -ForegroundColor DarkYellow
    }
}

# BTC 24h 变化检查：通过查找24h前的快照
if ($btcPrice) {
    $oldFile = Get-ChildItem "$base\data\market\prices_*.json" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt $now.AddHours(-25) -and $_.LastWriteTime -lt $now.AddHours(-23) } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($oldFile) {
        try {
            $oldPrices = Get-Content $oldFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $oldBtc = $oldPrices.crypto.BTC.price
            $btcPctChange = [math]::Abs(($btcPrice - $oldBtc) / $oldBtc * 100)
            $btc24hChange = [math]::Round($btcPctChange, 2)
            Write-Host "  BTC 24h变化: $("{0:N2}" -f $btcPctChange)% (参考: $("{0:N0}" -f $oldBtc) → $("{0:N0}" -f $btcPrice))" -ForegroundColor Gray
        } catch {
            Write-Host "  BTC 24h: 旧快照解析失败" -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "  BTC 24h: 无24h前快照作为参考" -ForegroundColor DarkYellow
    }
}

# ===== 3. 读取 F&G =====
$fngValue = $null
$fng24hChange = $null
if (Test-Path $fngFile) {
    try {
        $fng = Get-Content $fngFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $fngValue = $fng.value
        Write-Host "  F&G: $fngValue (来自 fear-greed_latest)" -ForegroundColor Gray
    } catch {
        Write-Host "  [WARN] fear-greed_latest.json 解析失败: $_" -ForegroundColor DarkYellow
    }
}

if ($fngValue) {
    # 查找24h前 F&G 快照
    $oldFngFiles = Get-ChildItem "$base\data\market\fear-greed-*.json" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt $now.AddHours(-25) -and $_.LastWriteTime -lt $now.AddHours(-23) } |
        Sort-Object LastWriteTime -Descending
    if ($oldFngFiles.Count -eq 0) {
        # 从 fear-greed 的 timestamp 取值比较
        # 如果只有 latest，用fetched_at推测
        Write-Host "  F&G 24h: 无精确24h前快照" -ForegroundColor DarkYellow
    } else {
        try {
            $oldFng = Get-Content $oldFngFiles[0].FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $fngDiff = [math]::Abs($fngValue - $oldFng.value)
            $fng24hChange = [math]::Round($fngDiff)
            Write-Host "  F&G 24h变化: $fngDiff 点 (参考: $($oldFng.value) → $fngValue)" -ForegroundColor Gray
        } catch {
            Write-Host "  F&G 24h: 旧快照解析失败" -ForegroundColor DarkYellow
        }
    }
}

# ===== 4. 判断触发条件 =====
$triggerReasons = @()
$triggered = $false

# 条件1: 简报年龄 > 12h
if ($ageHours -gt 12) {
    $triggerReasons += "简报过期>12h ($("{0:N1}" -f $ageHours)h)"
    $triggered = $true
}

# 条件2: BTC 24h > 5%
if ($btc24hChange -and $btc24hChange -gt 5) {
    $triggerReasons += "BTC 24h波动>$("{0:N1}" -f $btc24hChange)%"
    $triggered = $true
}

# 条件3: F&G 24h变化 > 10点
if ($fng24hChange -and $fng24hChange -gt 10) {
    $triggerReasons += "F&G 24h变化${fng24hChange}点"
    $triggered = $true
}

# 条件4: 被 collector-master 调用 + >4h
# 通过检查传递参数判断：如果 -CalledByMaster 且简报年龄>4h
if ($args -contains "-CalledByMaster" -and $ageHours -gt 4 -and $ageHours -le 12) {
    $triggerReasons += "collector-master 定时触发表 (>4h)"
    $triggered = $true
}

# ===== 5. 输出结果 =====
$signal = @{
    "timestamp" = $now.ToString("yyyy-MM-dd HH:mm:ss")
    "triggered" = $triggered
    "reasons" = $triggerReasons
    "last_briefing" = if ($lastBriefingFile) { (Split-Path $lastBriefingFile -Leaf) } else { "none" }
    "last_briefing_age_hours" = [math]::Round($ageHours, 1)
    "btc_price" = $btcPrice
    "btc_24h_change_pct" = $btc24hChange
    "fng_value" = $fngValue
    "fng_24h_change" = $fng24hChange
    "briefing_generator" = "$base\scripts\briefing-generator.ps1"
    "action" = if ($triggered) { "trigger_briefing_generator" } else { "no_action_needed" }
}

# 确保 directory 存在
$signalDir = Split-Path $signalFile -Parent
if (!(Test-Path $signalDir)) { New-Item -ItemType Directory -Path $signalDir -Force | Out-Null }

$signal | ConvertTo-Json -Depth 5 | Set-Content $signalFile -Encoding UTF8
Write-Host ""

if ($triggered) {
    Write-Host "🟢 触发简报生成!" -ForegroundColor Green
    foreach ($r in $triggerReasons) {
        Write-Host "   - $r" -ForegroundColor Yellow
    }
    Write-Host "  信号已写入: $signalFile" -ForegroundColor Gray
    Write-Host "  简报生成脚本: $base\scripts\briefing-generator.ps1" -ForegroundColor Gray
    exit 1
} else {
    Write-Host "⚪ 无需触发简报" -ForegroundColor Gray
    Write-Host "  原因: 简报年龄 $("{0:N1}" -f $ageHours)h (阈值 12h)" -ForegroundColor Gray
    if ($btc24hChange) { Write-Host "        BTC 24h $("{0:N1}" -f $btc24hChange)% (阈值 5%)" -ForegroundColor Gray }
    if ($fng24hChange) { Write-Host "        F&G 24h ${fng24hChange}点 (阈值 10点)" -ForegroundColor Gray }
    Write-Host "  信号已写入: $signalFile" -ForegroundColor Gray
    exit 0
}
