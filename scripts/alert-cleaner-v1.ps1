# alert-cleaner-v1.ps1 - ALERTS 目录噪声清理
# 功能: 扫描 ALERTS 目录, 基于关键词分类 true_signal vs noise
# 将 >14天的 noise 文件归档到 ARCHIVE\alerts\
# 支持 -WhatIf 模式预览不执行
# 创建: G-64B 2026-06-23

param(
    [string]$AlertsDir = "C:\Users\Administrator\clawd\agents\workspace-gid\ALERTS",
    [string]$ArchiveDir = "C:\Users\Administrator\clawd\agents\workspace-gid\ARCHIVE\alerts",
    [int]$MaxAgeDays = 14,
    [switch]$WhatIf = $false
)

$ErrorActionPreference = "Continue"
$cutoffDate = (Get-Date).AddDays(-$MaxAgeDays)

# 定义 true_signal 关键词 (高价值告警)
$trueSignalKeywords = @(
    'F&G', 'FNG', 'Fear & Greed',
    'BTC暴跌', 'BTC崩盘', 'BTC crash', 'BTC dump',
    'FOMC', 'CPI', 'NFP', '非农', '失业率',
    '地缘', '地缘政治', 'Hormuz', '霍尔木兹', '战争', '冲突',
    '变盘', '方向突破', '跌破', '暴涨', '暴跌',
    'SECURITY', 'ALERT',
    'Fed', '鲍威尔', 'Powell',
    '美伊', 'MOU', '贸易战', '关税',
    'black swan', '黑天鹅'
)

# 定义 noise 关键词 (低价值噪音告警)
$noiseKeywords = @(
    'okx_btc', 'binance_btc', 'bybit_btc',
    'API健康', 'api_health', 'health FAIL',
    'score=', 'health_precheck',
    'gfw_health FAIL', 'gfw_', 'gfw_check',
    'cron-watchdog'
)

function Get-Classification {
    param([string]$Content, [string]$FileName)
    
    # 检查 true_signal
    foreach ($kw in $trueSignalKeywords) {
        if ($Content -match [regex]::Escape($kw) -or $FileName -match [regex]::Escape($kw)) {
            return "true_signal"
        }
    }
    
    # 检查 noise
    foreach ($kw in $noiseKeywords) {
        if ($Content -match [regex]::Escape($kw) -or $FileName -match [regex]::Escape($kw)) {
            return "noise"
        }
    }
    
    # 文件名本身: cron-watchdog 文件大量噪声
    if ($FileName -match 'cron-watchdog|fng-threshold') {
        return "noise"
    }
    
    return "unclassified"
}

# === 执行扫描 ===
Write-Host "=== alert-cleaner-v1 ===" -ForegroundColor Cyan
Write-Host "扫描目录: $AlertsDir"
Write-Host "截止日期: $cutoffDate (>${MaxAgeDays}d文件归档)"
Write-Host "模式: $(if($WhatIf){'WhatIf (预览)'}else{'执行'})"
Write-Host ""

$files = Get-ChildItem -Path $AlertsDir -File
$totalCount = $files.Count

$classified = @{
    true_signal = @()
    noise = @()
    unclassified = @()
}

$noiseToArchive = @()

foreach ($file in $files) {
    try {
        $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
    } catch {
        $content = ""
    }
    
    $cls = Get-Classification -Content $content -FileName $file.Name
    
    if ($isOld -and $cls -eq "noise") {
        if ($file.LastWriteTime -lt $cutoffDate) {
            $noiseToArchive += $file
        }
    }
    
    $classified[$cls] += @{
        Name = $file.Name
        Size = "{0:N0}B" -f $file.Length
        LastWrite = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        AgeDays = [int]((Get-Date) - $file.LastWriteTime).TotalDays
    }
}

# === 分类: 按年龄和类型 ===
foreach ($file in $files) {
    $content = ""
    try { $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop } catch {}
    $cls = Get-Classification -Content $content -FileName $file.Name
    if ($file.LastWriteTime -lt $cutoffDate -and $cls -eq "noise") {
        $noiseToArchive += $file
    }
}

# 去重
$noiseToArchive = $noiseToArchive | Sort-Object FullName -Unique

# === 输出分类统计 ===
Write-Host "===== 分类统计 =====" -ForegroundColor Yellow
Write-Host "总文件数: $totalCount"
Write-Host ""
Write-Host "-- True Signal (高价值) --" -ForegroundColor Green
foreach ($f in $classified.true_signal) {
    Write-Host "  ✅ $($f.Name) | $($f.Size) | $($f.LastWrite) | $($f.AgeDays)d"
}
Write-Host "-- Noise (低价值) --" -ForegroundColor DarkYellow
foreach ($f in $classified.noise) {
    Write-Host "  ⛔ $($f.Name) | $($f.Size) | $($f.LastWrite) | $($f.AgeDays)d"
}
Write-Host "-- Unclassified (未分类) --" -ForegroundColor Gray
foreach ($f in $classified.unclassified) {
    Write-Host "  ❓ $($f.Name) | $($f.Size) | $($f.LastWrite) | $($f.AgeDays)d"
}

# === 执行归档 ===
Write-Host ""
Write-Host "===== 归档计划 =====" -ForegroundColor Yellow
Write-Host "准备归档的噪声文件(>$MaxAgeDays天): $($noiseToArchive.Count) 个"
$totalSize = 0
foreach ($f in $noiseToArchive) {
    $totalSize += $f.Length
    Write-Host "  📦 $($f.Name) | $($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))"
}
Write-Host "合计体积: $('{0:N0}' -f $totalSize) Bytes"

if ($WhatIf) {
    Write-Host ""
    Write-Host "⚠️ WhatIf 模式 - 未执行任何操作" -ForegroundColor Yellow
    Write-Host "  去除 -WhatIf 参数执行实际归档"
} else {
    if ($noiseToArchive.Count -gt 0) {
        # 创建归档目录
        New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null
        
        $moved = 0
        $failed = 0
        foreach ($f in $noiseToArchive) {
            try {
                $dest = Join-Path $ArchiveDir $f.Name
                # 如果目标已存在, 加时间戳后缀避免覆盖
                if (Test-Path $dest) {
                    $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
                    $ext = [System.IO.Path]::GetExtension($f.Name)
                    $dest = Join-Path $ArchiveDir "${base}_$(Get-Date -Format 'yyyyMMddHHmmss')${ext}"
                }
                Move-Item -Path $f.FullName -Destination $dest -Force
                $moved++
                Write-Host "  ✅ 已归档: $($f.Name)" -ForegroundColor Green
            } catch {
                $failed++
                Write-Host "  ❌ 归档失败: $($f.Name) - $_" -ForegroundColor Red
            }
        }
        Write-Host ""
        Write-Host "归档完成: 成功=$moved 失败=$failed" -ForegroundColor Cyan
    } else {
        Write-Host "  无需归档" -ForegroundColor Gray
    }
}

# === 清理报告 ===
Write-Host ""
Write-Host "===== 清理报告 =====" -ForegroundColor Cyan
Write-Host "运行时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
Write-Host "扫描目录: $AlertsDir"
Write-Host "归档目录: $ArchiveDir"
Write-Host "归档阈值: >${MaxAgeDays}天"
Write-Host "---"
Write-Host "总文件数: $totalCount"
$trueCount = $classified.true_signal.Count
$noiseCount = $classified.noise.Count
$unclassCount = $classified.unclassified.Count
$noisePct = if ($totalCount -gt 0) { [math]::Round($noiseCount / $totalCount * 100, 1) } else { 0 }
Write-Host "True Signal: $trueCount ($([math]::Round($trueCount/$totalCount*100,1))%)"
Write-Host "Noise: $noiseCount ($noisePct%)"
Write-Host "Unclassified: $unclassCount ($([math]::Round($unclassCount/$totalCount*100,1))%)"
Write-Host "已归档噪声: $($noiseToArchive.Count)"
Write-Host "---"
Write-Host "清理后 ALERTS 保留: $($totalCount - $noiseToArchive.Count) 个文件"
Write-Host "========================================"
