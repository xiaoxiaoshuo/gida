# alert-cleaner-v2.ps1 - ALERTS 目录噪声清理 (Bugfix)
# 修复: G-66B 2026-06-23
# 变更:
#   B1: 添加 $isOld 变量定义 (从 LastWriteTime 计算)
#   B2: 删除重复的 foreach 循环
#   B3: 先检查 noise 关键词, 再检查 true_signal
#   B4: 路径改为相对路径 ./ALERTS/ 和 ./ARCHIVE/alerts/
#   新增: -Execute 参数 (默认 WhatIf; 加 -Execute 才实际移动)

param(
    [string]$AlertsDir = "./ALERTS",
    [string]$ArchiveDir = "./ARCHIVE/alerts",
    [int]$MaxAgeDays = 14,
    [switch]$WhatIf = $true,
    [switch]$Execute = $false
)

# Execute 模式 = WhatIf=$false (兼容原有 -WhatIf 参数)
if ($Execute) {
    $WhatIf = $false
}

$ErrorActionPreference = "Continue"
$cutoffDate = (Get-Date).AddDays(-$MaxAgeDays)

# B4修复: 解析相对路径 — 从当前工作目录解析
$resolvedAlerts = if ([System.IO.Path]::IsPathRooted($AlertsDir)) {
    $AlertsDir
} else {
    # 如果脚本在 ./scripts/ 下运行, 相对路径从工作目录解析
    $base = (Get-Location).Path
    $relative = $AlertsDir.TrimStart('.\').TrimStart('./')
    Join-Path $base $relative
}

$resolvedArchive = if ([System.IO.Path]::IsPathRooted($ArchiveDir)) {
    $ArchiveDir
} else {
    $base = (Get-Location).Path
    $relative = $ArchiveDir.TrimStart('.\').TrimStart('./')
    Join-Path $base $relative
}

# 定义 noise 关键词 (低价值噪音告警) — 放在前面, B3修复
$noiseKeywords = @(
    'okx_btc', 'binance_btc', 'bybit_btc',
    'API健康', 'api_health', 'health FAIL',
    'score=', 'health_precheck',
    'gfw_health FAIL', 'gfw_', 'gfw_check',
    'cron-watchdog'
)

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

function Get-Classification {
    param([string]$Content, [string]$FileName)

    # B3修复: 先检查 noise 关键词
    foreach ($kw in $noiseKeywords) {
        if ($Content -match [regex]::Escape($kw) -or $FileName -match [regex]::Escape($kw)) {
            return "noise"
        }
    }

    # 文件名本身的噪声模式
    if ($FileName -match 'cron-watchdog|fng-threshold') {
        return "noise"
    }

    # 再检查 true_signal 关键词
    foreach ($kw in $trueSignalKeywords) {
        if ($Content -match [regex]::Escape($kw) -or $FileName -match [regex]::Escape($kw)) {
            return "true_signal"
        }
    }

    return "unclassified"
}

# === 执行扫描 ===
Write-Host "=== alert-cleaner-v2 (Bugfix) ===" -ForegroundColor Cyan
Write-Host "扫描目录: $resolvedAlerts"
Write-Host "归档目录: $resolvedArchive"
Write-Host "截止日期: $cutoffDate (>${MaxAgeDays}d文件归档)"
Write-Host "模式: $(if($WhatIf){'WhatIf (预览, 加 -Execute 执行)'}else{'执行'})"
Write-Host ""

if (-not (Test-Path $resolvedAlerts)) {
    Write-Host "⛔ 目录不存在: $resolvedAlerts" -ForegroundColor Red
    exit 1
}

$files = Get-ChildItem -Path $resolvedAlerts -File
$totalCount = $files.Count
Write-Host "找到 $totalCount 个文件" -ForegroundColor DarkGray
Write-Host ""

$classified = @{
    true_signal = @()
    noise       = @()
    unclassified = @()
}

$noiseToArchive = @()

# B1修复: 在循环中按文件计算 $isOld
foreach ($file in $files) {
    try {
        $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
    } catch {
        $content = ""
    }

    $cls = Get-Classification -Content $content -FileName $file.Name
    $classified[$cls] += @{
        Name       = $file.Name
        Size       = "{0:N0}B" -f $file.Length
        LastWrite  = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        AgeDays    = [int]((Get-Date) - $file.LastWriteTime).TotalDays
    }

    # B1: 定义 $isOld — 文件超过14天
    $isOld = (Get-Date) - $file.LastWriteTime -gt [TimeSpan]::FromDays($MaxAgeDays)

    if ($isOld -and $cls -eq "noise") {
        $noiseToArchive += $file
    }
}

# 去重
$noiseToArchive = $noiseToArchive | Sort-Object FullName -Unique

# === 输出分类统计 ===
Write-Host "===== 分类统计 =====" -ForegroundColor Yellow
Write-Host "总文件数: $totalCount"
Write-Host ""
Write-Host "-- Noise (低价值) --" -ForegroundColor DarkYellow
foreach ($f in $classified.noise) {
    Write-Host "  ⛔ $($f.Name) | $($f.Size) | $($f.LastWrite) | $($f.AgeDays)d"
}
Write-Host "-- True Signal (高价值) --" -ForegroundColor Green
foreach ($f in $classified.true_signal) {
    Write-Host "  ✅ $($f.Name) | $($f.Size) | $($f.LastWrite) | $($f.AgeDays)d"
}
Write-Host "-- Unclassified (未分类) --" -ForegroundColor Gray
foreach ($f in $classified.unclassified) {
    Write-Host "  ❓ $($f.Name) | $($f.Size) | $($f.LastWrite) | $($f.AgeDays)d"
}

# === 执行归档 ===
Write-Host ""
Write-Host "===== 归档计划 =====" -ForegroundColor Yellow
$noiseCount = $classified.noise.Count
Write-Host "噪声文件总数: $noiseCount 个"
Write-Host "准备归档(>${MaxAgeDays}d): $($noiseToArchive.Count) 个"
$totalSize = 0
foreach ($f in $noiseToArchive) {
    $totalSize += $f.Length
    Write-Host "  📦 $($f.Name) | $($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))"
}
Write-Host "合计体积: $('{0:N0}' -f $totalSize) Bytes"

if ($WhatIf) {
    Write-Host ""
    Write-Host "⚠️ WhatIf 模式 - 未执行任何操作" -ForegroundColor Yellow
    Write-Host "  运行 `pwsh -File scripts/alert-cleaner-v2.ps1 -Execute` 执行实际归档"
} else {
    if ($noiseToArchive.Count -gt 0) {
        # 创建归档目录
        New-Item -ItemType Directory -Path $resolvedArchive -Force | Out-Null
        
        $moved = 0
        $failed = 0
        foreach ($f in $noiseToArchive) {
            try {
                $dest = Join-Path $resolvedArchive $f.Name
                # 如果目标已存在, 加时间戳后缀避免覆盖
                if (Test-Path $dest) {
                    $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
                    $ext  = [System.IO.Path]::GetExtension($f.Name)
                    $dest = Join-Path $resolvedArchive "${base}_$(Get-Date -Format 'yyyyMMddHHmmss')${ext}"
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
Write-Host "扫描目录: $resolvedAlerts"
Write-Host "归档目录: $resolvedArchive"
Write-Host "归档阈值: >${MaxAgeDays}天"
Write-Host "---"
Write-Host "总文件数: $totalCount"
$trueCount    = $classified.true_signal.Count
$noiseCount   = $classified.noise.Count
$unclassCount = $classified.unclassified.Count
$noisePct     = if ($totalCount -gt 0) { [math]::Round($noiseCount / $totalCount * 100, 1) } else { 0 }
Write-Host "True Signal: $trueCount ($([math]::Round($trueCount/$totalCount*100,1))%)"
Write-Host "Noise: $noiseCount ($noisePct%)"
Write-Host "Unclassified: $unclassCount ($([math]::Round($unclassCount/$totalCount*100,1))%)"
Write-Host "已归档噪声: $($noiseToArchive.Count)"
Write-Host "---"
Write-Host "清理后 ALERTS 保留: $($totalCount - $noiseToArchive.Count) 个文件"
Write-Host "========================================"
