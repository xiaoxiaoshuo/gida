<#
.SYNOPSIS
  子智能体健康监控脚本 — 用于 cron-watchdog 检测"子智能体无声失败"

.DESCRIPTION
  检查最近 N 小时内 INTEL/ 目录中新生成的 .md 文件。
  如果发现某个预期输出文件缺失（上次运行后无新产出），输出警告到 stderr。
  可以被 cron-watchdog-v3-wrapper.ps1 调用来检测子智能体未自动回报的无声失败。

.PARAMETER Hours
  回溯检查的时间窗口（默认 2 小时）。

.PARAMETER IntelsDir
  INTEL 输出目录（默认 \$RepoRoot\INTEL）。

.PARAMETER ExpectedPatterns
  预期存在产出的文件名模式列表（通配符）。
  默认检查 G-64A ~ G-66 等近期任务文件。

.PARAMETER Quiet
  安静模式 — 仅通过退出码指示状态（0=正常, 1=告警）。

.EXAMPLE
  .\subagent-health-monitor.ps1
  # 基本检查，最近 2h 内 INTEL 文件产出的异常检测

.EXAMPLE
  .\subagent-health-monitor.ps1 -Hours 4 -Quiet
  # 检查最近 4h，安静模式，适合 cron 调用

.NOTES
  作者: G-65B system-fix
  创建: 2026-06-23 18:29
  >=8KB task, part of evening maintenance
#>

param(
    [Parameter(Mandatory = $false)]
    [int]$Hours = 2,

    [Parameter(Mandatory = $false)]
    [string]$IntelsDir = "",

    [Parameter(Mandatory = $false)]
    [string[]]$ExpectedPatterns = @(
        "G-64*.md",
        "G-65*.md",
        "G-66*.md"
    ),

    [Parameter(Mandatory = $false)]
    [switch]$Quiet
)

# ── RepoRoot auto-detect ──────────────────────────────────────────
if (-not $IntelsDir) {
    # 先猜脚本位置
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $candidate = Join-Path $scriptDir "..\INTEL"
    if (Test-Path $candidate) {
        $IntelsDir = Resolve-Path $candidate
    } else {
        $candidate2 = "C:\Users\Administrator\clawd\agents\workspace-gid\INTEL"
        if (Test-Path $candidate2) {
            $IntelsDir = $candidate2
        } else {
            Write-Error "无法定位 INTEL 目录。请通过 -IntelsDir 参数指定。"
            exit 2
        }
    }
}

# ── 计算回溯时间 ──────────────────────────────────────────────────
$cutoff = (Get-Date).AddHours(-$Hours)

# ── 列出所有在回溯窗口内的 .md 文件 ──────────────────────────────
$recentFiles = Get-ChildItem -Path $IntelsDir -Filter "*.md" -ErrorAction SilentlyContinue | 
    Where-Object { $_.LastWriteTime -ge $cutoff } |
    Sort-Object LastWriteTime -Descending

$recentCount = @($recentFiles).Count

# ── 检查每个预期模式 ──────────────────────────────────────────────
$warnings = @()
foreach ($pattern in $ExpectedPatterns) {
    $matchingRecent = $recentFiles | Where-Object { $_.Name -like $pattern }
    if (-not $matchingRecent) {
        $warnings += "[WARN] 预期产出模式 '$pattern' 在最近 ${Hours}h 内无新文件 → 可能子智能体无声失败"
    }
}

# ── 空 INTEL 目录告警 ────────────────────────────────────────────
if ($recentCount -eq 0) {
    $warnings += "[CRITICAL] INTEL 目录最近 ${Hours}h 内完全无新 → 系统级故障？"
}

# ── 当前健康状况 ──────────────────────────────────────────────────
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$info = @(
    "=== subagent-health-monitor @ $now ===",
    "检查窗口: ${Hours}h (回溯至 $($cutoff.ToString('yyyy-MM-dd HH:mm')))",
    "INTEL路径: $IntelsDir",
    "最近${Hours}h内新文件: ${recentCount} 个"
)
foreach ($f in $recentFiles) {
    $info += "  - $($f.Name) (${($f.LastWriteTime).ToString('HH:mm')})"
}

# ── 输出 ───────────────────────────────────────────────────────────
if (-not $Quiet) {
    # stdout: 标准信息
    $info | ForEach-Object { Write-Host $_ }
    Write-Host ""

    if ($warnings.Count -gt 0) {
        Write-Host "⚠ 发现 $($warnings.Count) 个告警:" -ForegroundColor Yellow
        $warnings | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
        Write-Host ""
    } else {
        Write-Host "✅ 所有预期模式均命中，子智能体健康。" -ForegroundColor Green
    }
}

# stderr: 仅输出告警，便于 cron-watchdog 捕获
if ($warnings.Count -gt 0) {
    $warnings | ForEach-Object { Write-Warning $_ }
    exit 1
}

exit 0
