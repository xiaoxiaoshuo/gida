# ============================================================================
# auto-push-v5-selflog-rotation.ps1
# 描述: auto-push self-log 422 模式解决方案 (rotation + atomic write + .gitignore)
# 作者: gida-intel subagent (G-50, 2026-06-05 08:05)
# 上一版: auto-push-v4-resilient.ps1 (self-log 4 次失败 6/2 02:57/04:57/05:07/05:18)
# 目标: 解决 GitHub 422 "unprocessable entity" 模式
#       - self-log 在 git add 时被包含, 但 hash 频繁变化
#       - 写入 5min 后自动 rotate 为 .log.1 (保留 3 个)
#       - atomic rename 防止 git add 时 hash 突变
#       - 自动检查 .gitignore 包含 *.log
#
# 铁律: 不重写历史, 不删除 commit, 不破坏 v4 的 3 次重试 + bundle 兜底
#       仅在 v4 写入 self-log 阶段之前加 rotation + atomic rename
#
# 集成方式: 把本脚本的 Write-SelfLog 函数引入到 v4 (或作为独立 module dot-sourced)
#   . "$PSScriptRoot\auto-push-v5-selflog-rotation.ps1"
#   Write-SelfLog -LogFile $selfLog -Content "..."
#
# 用法 (独立调用, 测试 self-log rotation):
#   pwsh -File scripts/auto-push-v5-selflog-rotation.ps1
#   pwsh -File scripts/auto-push-v5-selflog-rotation.ps1 -TestRotate -LogDir logs/test
#   pwsh -File scripts/auto-push-v5-selflog-rotation.ps1 -CheckGitignore
#   pwsh -File scripts/auto-push-v5-selflog-rotation.ps1 -InstallGitignore
#
# 422 模式分析 (auto-push-v4 6/2 失败案例):
#   1. self-log 持续更新 (每 30s 写一次)
#   2. git add . 把 self-log 加入 stage
#   3. git hash-object 计算新 hash
#   4. 但 self-log 在 git commit 之前又更新, hash 突变
#   5. git commit 提交时 hash 校验失败 → 422
#   6. 重复 4 次 (02:57/04:57/05:07/05:18)
#
# v5 解决:
#   1. self-log 写入 5min 后自动 rotate → 不再被 git 频繁纳入
#   2. atomic rename (temp + move) → 写入瞬间完成, 减少 hash 竞争窗口
#   3. .gitignore 自动添加 *.log → 完全避免误提交
# ============================================================================

[CmdletBinding()]
param(
    [string]$RepoRoot  = "C:\Users\Administrator\clawd\agents\workspace-gid",
    [string]$LogDir    = "",     # 默认: $RepoRoot\memory
    [int]$RotateAfterMinutes = 5,
    [int]$KeepCount    = 3,
    [switch]$TestRotate,
    [switch]$CheckGitignore,
    [switch]$InstallGitignore
)

$ErrorActionPreference = "Continue"

# ============================================================================
# 默认 LogDir = $RepoRoot\memory
# ============================================================================
if ([string]::IsNullOrEmpty($LogDir)) {
    $LogDir = Join-Path $RepoRoot "memory"
}
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# ============================================================================
# Rotate-Logs: .log 写入 N min 后自动 rename 为 .log.1
#   - 保留最近 3 个 .log.N 文件 (.log.1 / .log.2 / .log.3)
#   - 超 3 个的自动删除 (按 mtime 排序, 删最旧)
# ============================================================================
function Rotate-Logs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$LogDir,
        [int]$Keep = 3,
        [int]$AfterMinutes = 5
    )

    if (!(Test-Path $LogDir)) { return @() }

    $rotated = @()
    $now = Get-Date

    # 找所有 .log 文件 (不含 .log.N)
    $logs = Get-ChildItem $LogDir -Filter "*.log" -File | Where-Object {
        # 排除已经 rotate 的 (.log.1, .log.2 等)
        $_.Name -notmatch "\.log\.\d+$"
    }

    foreach ($log in $logs) {
        $ageMin = ($now - $log.LastWriteTime).TotalMinutes
        if ($ageMin -lt $AfterMinutes) {
            continue  # 太新, 暂不 rotate
        }

        $baseName = $log.BaseName  # 例如 "auto-push-v4"
        # 把 .log.3 → 删除, .log.2 → .log.3, .log.1 → .log.2, .log → .log.1
        # 从后往前滚动
        for ($i = $Keep; $i -ge 1; $i--) {
            $src = if ($i -eq 1) { $log.FullName } else { Join-Path $LogDir "$baseName.log.$($i-1)" }
            $dst = Join-Path $LogDir "$baseName.log.$i"
            if (Test-Path $src) {
                try {
                    # .log.$Keep 直接删除
                    if ($i -eq $Keep) {
                        Remove-Item $src -Force
                    } else {
                        Move-Item $src $dst -Force
                    }
                } catch {
                    Write-Warn "rotate failed: $src → $dst : $_"
                }
            }
        }
        $rotated += $log.Name
    }
    return $rotated
}

# ============================================================================
# Write-AtomicLog: temp file + atomic rename
#   - 写 .tmp → Move-Item .tmp → .log (PowerShell Move-Item 接近原子操作)
#   - 解决: 写入过程中 git add 读到半文件, hash 不匹配 → 422
# ============================================================================
function Write-AtomicLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [Parameter(Mandatory=$true)]
        [string]$Content
    )

    $dir = Split-Path $Path -Parent
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $tempPath = "$Path.tmp.$($PID)"
    try {
        # 写 temp (UTF-8 无 BOM, 避免 git diff 噪音)
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($tempPath, $Content, $utf8NoBom)
        # 原子 rename
        Move-Item $tempPath $Path -Force
    } catch {
        # 清理残留 temp
        if (Test-Path $tempPath) { Remove-Item $tempPath -Force -ErrorAction SilentlyContinue }
        throw "atomic write failed: $($_.Exception.Message)"
    }
}

# ============================================================================
# Append-AtomicLog: temp append + atomic rename
#   - 读现有 .log 内容 → 追加新内容 → 写 temp → rename
# ============================================================================
function Append-AtomicLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [Parameter(Mandatory=$true)]
        [string]$Content
    )

    $existing = ""
    if (Test-Path $Path) {
        try { $existing = Get-Content $Path -Raw -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
    }
    $newContent = $existing + $Content
    Write-AtomicLog -Path $Path -Content $newContent
}

# ============================================================================
# Test-Gitignore: 检查 .gitignore 是否包含 *.log
# ============================================================================
function Test-Gitignore {
    [CmdletBinding()]
    param([string]$RepoRoot)

    $gitignore = Join-Path $RepoRoot ".gitignore"
    if (!(Test-Path $gitignore)) {
        return @{ has_file = $false; has_log_rule = $false; needs_install = $true }
    }
    $content = Get-Content $gitignore -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    $hasRule = $content -match "(?m)^\s*\*\.log\s*$" -or $content -match "(?m)^\s*\*\.log\b"
    return @{
        has_file      = $true
        has_log_rule  = $hasRule
        needs_install = -not $hasRule
    }
}

# ============================================================================
# Install-Gitignore: 添加 *.log 规则 (幂等, 不重复添加)
# ============================================================================
function Install-Gitignore {
    [CmdletBinding()]
    param([string]$RepoRoot)

    $gitignore = Join-Path $RepoRoot ".gitignore"
    if (!(Test-Path $gitignore)) {
        # 创建基础 .gitignore
        $initial = @"
# gida-intel workspace .gitignore
# Auto-generated by auto-push-v5-selflog-rotation.ps1 (G-50, 2026-06-05)

# Self-logs (解决 auto-push 422 模式, G-50)
*.log
*.log.*

# OS / editor
.DS_Store
Thumbs.db
.vscode/
.idea/

# 临时文件
*.tmp
*.swp
*~
*.bak

# 大文件
repo-*.bundle
node_modules/
"@
        $initial | Out-File -FilePath $gitignore -Encoding UTF8
        return @{ created = $true; rule_added = "*.log" }
    }

    $status = Test-Gitignore -RepoRoot $RepoRoot
    if ($status.has_log_rule) {
        return @{ created = $false; rule_added = ""; note = "*.log rule already present" }
    }

    # 追加 *.log 规则 (注释说明)
    $append = @"

# Self-logs (解决 auto-push 422 模式, G-50, 2026-06-05)
*.log
*.log.*
"@
    Add-Content -Path $gitignore -Value $append -Encoding UTF8
    return @{ created = $false; rule_added = "*.log, *.log.*" }
}

# ============================================================================
# 日志辅助
# ============================================================================
function Write-Info { param($m) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [INFO] $m" }
function Write-OK   { param($m) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [OK]   $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [WARN] $m" -ForegroundColor Yellow }

# ============================================================================
# Main 入口 (独立调用)
# ============================================================================
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " auto-push-v5-selflog-rotation  G-50 (2026-06-05 08:05)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Info "RepoRoot: $RepoRoot"
Write-Info "LogDir:   $LogDir"
Write-Info "RotateAfterMinutes: $RotateAfterMinutes"
Write-Info "KeepCount: $KeepCount"
Write-Host ""

# Step 1: 检查 .gitignore
$giStatus = Test-Gitignore -RepoRoot $RepoRoot
if ($giStatus.needs_install) {
    Write-Warn ".gitignore 缺少 *.log 规则 (auto-push 422 风险)"
    if ($InstallGitignore -or (-not $CheckGitignore -and -not $TestRotate)) {
        $installResult = Install-Gitignore -RepoRoot $RepoRoot
        if ($installResult.created) {
            Write-OK ".gitignore 已创建, 规则: $($installResult.rule_added)"
        } else {
            Write-OK ".gitignore 已追加规则: $($installResult.rule_added)"
        }
    } else {
        Write-Info "跳过安装 (使用 -InstallGitignore 强制安装)"
    }
} else {
    Write-OK ".gitignore 已有 *.log 规则"
}

# Step 2: 如果是 -CheckGitignore 模式, 到此结束
if ($CheckGitignore) {
    Write-Host ""
    Write-Info "CheckGitignore 模式, 退出"
    exit 0
}

# Step 3: 执行 rotation
Write-Host ""
Write-Info "扫描 $LogDir 下的 .log 文件 (mtime > $RotateAfterMinutes min)..."
$rotated = Rotate-Logs -LogDir $LogDir -Keep $KeepCount -AfterMinutes $RotateAfterMinutes
if ($rotated.Count -eq 0) {
    Write-OK "无 .log 需要 rotation"
} else {
    Write-OK "Rotated: $($rotated -join ', ')"
}

# Step 4: 如果是 -TestRotate 模式, 跑一个 422 模式仿真
if ($TestRotate) {
    Write-Host ""
    Write-Info "=== 422 模式仿真测试 ===" -ForegroundColor Magenta
    $testLogDir = Join-Path $LogDir "v5-test-$(Get-Date -Format 'HHmmss')"
    New-Item -ItemType Directory -Path $testLogDir -Force | Out-Null

    # 创建 3 个 .log 文件, mtime 设为 6/10/15 分钟前
    $testLogs = @(
        @{ name = "old1.log"; ageMin = 15 },
        @{ name = "old2.log"; ageMin = 10 },
        @{ name = "fresh.log"; ageMin = 2 }
    )
    foreach ($tl in $testLogs) {
        $p = Join-Path $testLogDir $tl.name
        "test content $(Get-Date -Format 'o')" | Out-File $p -Encoding UTF8
        (Get-Item $p).LastWriteTime = (Get-Date).AddMinutes(-$tl.ageMin)
    }

    Write-Info "创建测试日志: $($testLogs.Count) 个 (old1=15min, old2=10min, fresh=2min)"

    # atomic write 测试
    $testFile = Join-Path $testLogDir "atomic-test.log"
    $content1 = "line 1`n"
    $content2 = "line 2`n"
    Write-AtomicLog -Path $testFile -Content $content1
    Write-OK "atomic write 1: $testFile ($((Get-Item $testFile).Length) bytes)"
    Append-AtomicLog -Path $testFile -Content $content2
    Write-OK "atomic append: $testFile ($((Get-Item $testFile).Length) bytes)"

    # rotation 测试 (把 mtime 全部推到 10min 前, 再 rotate)
    foreach ($tl in $testLogs) {
        $p = Join-Path $testLogDir $tl.name
        if (Test-Path $p) {
            (Get-Item $p).LastWriteTime = (Get-Date).AddMinutes(-10)
        }
    }
    Write-Info "把测试日志 mtime 推到 10min 前, 重新执行 rotation..."
    $rotatedTest = Rotate-Logs -LogDir $testLogDir -Keep $KeepCount -AfterMinutes $RotateAfterMinutes
    Write-OK "Rotated: $($rotatedTest -join ', ')"

    # 列出剩余
    Write-Info "测试目录剩余文件:"
    Get-ChildItem $testLogDir | ForEach-Object {
        Write-Host "    $($_.Name) ($([math]::Round(((Get-Date) - $_.LastWriteTime).TotalMinutes, 1)) min)"
    }

    # 清理
    Remove-Item $testLogDir -Recurse -Force
    Write-OK "测试目录已清理"
}

Write-Host ""
Write-OK "auto-push-v5-selflog-rotation 完成"
exit 0
