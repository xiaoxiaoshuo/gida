# briefing-generator.ps1 - 简报生成脚本 (v2.0)
# 用途: 数据完整性检查 + ALERT 触发 + 自动生成 v{N+1} 简报骨架
# v2.0 升级: 多源检查 + age 验证 + 简报骨架自动生成
# 调用: 主代理读取 ALERT 后填充实际内容

$ErrorActionPreference = "Stop"
$workspace = "C:\Users\Administrator\clawd\agents\workspace-gid"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
$dateCompact = Get-Date -Format "yyyy-MM-dd"
$timeCompact = Get-Date -Format "HHmm"

Write-Host "[INFO] $timestamp - ========== 简报生成 v2.0 ==========" -ForegroundColor Cyan
Write-Host "[INFO] 检查多源数据完整性..."

# ===== 数据源检查 + age 验证 =====
$sources = @(
    @{ name = "prices_latest.json"; path = "data\market\prices_latest.json"; maxAgeMin = 90; required = $true }
    @{ name = "hacker-news_latest.json"; path = "data\tech\hacker-news_latest.json"; maxAgeMin = 180; required = $true }
    @{ name = "ai-news_latest.json"; path = "data\ai\ai-news_latest.json"; maxAgeMin = 720; required = $true }
    @{ name = "farside-etf-6-3"; path = "data\crypto\farside-etf-6-3-actual-2026-06-04.md"; maxAgeMin = 1440; required = $false }
    @{ name = "middle-east-snapshot"; path = "data\geo\middle-east-snapshot-*.json"; maxAgeMin = 360; required = $false }
    @{ name = "INTEL dir"; path = "INTEL\*.md"; maxAgeMin = 1440; required = $false }
    @{ name = "memory_today"; path = "memory\$dateCompact.md"; maxAgeMin = 1440; required = $true }
    @{ name = "WATCHLIST"; path = "WATCHLIST\active.md"; maxAgeMin = 720; required = $false }
)

$allReady = $true
$sourceStatus = @()

foreach ($src in $sources) {
    $files = Get-ChildItem -Path (Join-Path $workspace $src.path) -ErrorAction SilentlyContinue
    if ($files) {
        $latest = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $ageMin = ((Get-Date) - $latest.LastWriteTime).TotalMinutes
        $status = if ($ageMin -le $src.maxAgeMin) { "OK" } else { "STALE" }
        $sourceStatus += [PSCustomObject]@{
            Name = $src.name
            Status = $status
            AgeMin = [int]$ageMin
            LastWrite = $latest.LastWriteTime.ToString("HH:mm")
        }
        $color = if ($status -eq "OK") { "Green" } else { "Yellow" }
        Write-Host "[$status] $($src.name) - age $($ageMin.ToString('F0'))m (max $($src.maxAgeMin)m)" -ForegroundColor $color
        if ($src.required -and $status -ne "OK") { $allReady = $false }
    } else {
        $sourceStatus += [PSCustomObject]@{
            Name = $src.name
            Status = "MISSING"
            AgeMin = -1
            LastWrite = "-"
        }
        $color = if ($src.required) { "Red" } else { "DarkYellow" }
        Write-Host "[MISSING] $($src.name)" -ForegroundColor $color
        if ($src.required) { $allReady = $false }
    }
}

# ===== 决定生成哪种简报 =====
$latestBriefing = Get-ChildItem "$workspace\briefings\2026-06-04-v*.md" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($latestBriefing) {
    $nextVersion = [int]($latestBriefing.Name -replace '.*v(\d+).*', '$1') + 1
} else {
    $nextVersion = 1
}

$briefingType = if ($allReady) { "FULL" } else { "PARTIAL" }
$nextFile = "$workspace\briefings\$dateCompact-v$nextVersion-$timeCompact.md"

Write-Host ""
Write-Host "[INFO] 简报类型: $briefingType / 版本: v$nextVersion" -ForegroundColor Cyan
Write-Host "[INFO] 目标文件: $nextFile" -ForegroundColor Cyan

# ===== 写简报骨架 =====
$skeleton = @"
# 简报 v$nextVersion — $dateCompact $timeCompact

**Status**: $briefingType 简报
**Trigger**: briefing-generator.ps1 v2.0 自动触发
**Author**: 主代理 (post-collection)

## 数据源状态
$(($sourceStatus | ForEach-Object { "- $($_.Status) $($_.Name) (age $($_.AgeMin)m, write $($_.LastWrite))" }) -join "`n")

## 待填充章节
- [ ] 市场快照 (BTC/ETH/SOL/VIX/Gold/Oil 实时价)
- [ ] P0/P1 信号 (HN + GH Trending)
- [ ] 子智能体产出整合 (INTEL/ 5 报告)
- [ ] 地缘风险 (中东 + AMOC)
- [ ] 加密市场 (ETF 流入/链上健康)
- [ ] AI/科技前沿 (Gemma 4 + Anthropic fs)
- [ ] 行动建议 (5 条以内)

---
*由 briefing-generator.ps1 v2.0 自动生成骨架, 主代理填充*
"@

$skeleton | Out-File -FilePath $nextFile -Encoding UTF8
Write-Host "[OK] 简报骨架已生成: $nextFile" -ForegroundColor Green

# ===== 写 ALERT 触发主代理 =====
$alertFile = "$workspace\ALERTS\$(Get-Date -Format 'yyyy-MM-dd-HHmm')-briefing-trigger-v2.md"
$alertContent = @"
# 简报生成触发 v2.0 — $timestamp

**Status**: $briefingType 简报
**Target**: briefings/v$nextVersion
**Action**: 主代理读取简报骨架后填充

## 流程
1. 读取 $nextFile
2. 调 web_fetch 抓 prices_latest.json / HN / AI news
3. 检查 INTEL/ 5 报告 (gemma4-anthropic-fs / anthropic-fs / ai-economics / amoc / esp32-s31)
4. 检查 WATCHLIST/active.md 当前状态
5. 整合写入 $nextFile
6. 同步 DAILY/ 增量
7. 触发 auto-push (如有新 commit)

## 数据源检查
$(($sourceStatus | ForEach-Object { "- **$($_.Name)**: $($_.Status) (age $($_.AgeMin)m)" }) -join "`n")

---
*由 briefing-generator.ps1 v2.0 自动生成*
"@
$alertContent | Out-File -FilePath $alertFile -Encoding UTF8
Write-Host "[OK] ALERT 触发: $alertFile" -ForegroundColor Green

Write-Host "[INFO] $timestamp - ========== 完成 ==========" -ForegroundColor Cyan
