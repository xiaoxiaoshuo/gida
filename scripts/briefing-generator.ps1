# briefing-generator.ps1 - 简报生成脚本 (v1.0)
# 用途: 触发主代理生成简报 (通过 ALERT 标记 + memory 提示)
# 调用: 简报生成实际由 agent 主动完成, 本脚本:
#   1. 触发 ALERT 提示 agent
#   2. 验证数据完整性
#   3. 写入 readiness 标记

$ErrorActionPreference = "Stop"
$workspace = "C:\Users\Administrator\clawd\agents\workspace-gid"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"

Write-Host "[INFO] $timestamp - ========== 简报生成触发 ==========" -ForegroundColor Cyan
Write-Host "[INFO] $timestamp - 检查数据完整性..."

# 检查关键数据
$checks = @{
    "prices_latest.json" = Test-Path "$workspace\data\market\prices_latest.json"
    "hacker-news_latest.json" = Test-Path "$workspace\data\tech\hacker-news_latest.json"
    "ai-news_latest.json" = Test-Path "$workspace\data\ai\ai-news_latest.json"
    "memory_today" = Test-Path "$workspace\memory\$(Get-Date -Format 'yyyy-MM-dd').md"
}

$allReady = $true
foreach ($key in $checks.Keys) {
    if ($checks[$key]) {
        $age = (Get-Item "$workspace\data\market\prices_latest.json" -ErrorAction SilentlyContinue).LastWriteTime
        Write-Host "[OK]   $key - ready" -ForegroundColor Green
    } else {
        Write-Host "[WARN] $key - missing" -ForegroundColor Yellow
        $allReady = $false
    }
}

if ($allReady) {
    # 写一个 ALERT 触发 agent
    $alertFile = "$workspace\ALERTS\$(Get-Date -Format 'yyyy-MM-dd-HHmm')-briefing-trigger.md"
    $content = @"
# 简报生成触发 — $timestamp

**Status**: 数据就绪
**Action**: 主代理应生成 briefings/v{N} 简报

## 数据检查
- ✅ prices_latest.json
- ✅ hacker-news_latest.json
- ✅ ai-news_latest.json
- ✅ memory/$(Get-Date -Format 'yyyy-MM-dd').md

## 建议
1. 基于 prices_latest.json 生成市场快照
2. 基于 hacker-news_latest.json 提取 P0/P1 信号
3. 检查 ALERTS/ 是否有新事件
4. 检查 INTEL/ 是否有子智能体分析
5. 写入 briefings/YYYY-MM-DD-v{N}-HHMM.md
6. 同步 DAILY/ 增量

---
*由 briefing-generator.ps1 v1.0 自动生成*
"@
    $content | Out-File -FilePath $alertFile -Encoding UTF8
    Write-Host "[OK]   触发文件已写入: $alertFile" -ForegroundColor Green
} else {
    Write-Host "[FAIL] 数据不完整，跳过本次触发" -ForegroundColor Red
}

Write-Host "[INFO] $timestamp - ========== 完成 ==========" -ForegroundColor Cyan
