# auto-push.ps1 - 定时变更自动推送 (集成增量备份)
# 运行方式: 每日定时或手动执行
# 集成: incremental-backup.ps1 - 推送失败自动归档
# =========================================================

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"
$RemoteUrl = "https://github.com/xiaoxiaoshuo/gida.git"
$MaxRetries = 3
$RetryDelay = 30

$DateStamp = Get-Date -Format "yyyy-MM-dd HH:mm"
$LogFile = "$RepoRoot\memory\$(Get-Date -Format 'yyyy-MM-dd').md"

function Write-Log {
    param($msg)
    $entry = "$(Get-Date -Format 'HH:mm:ss') - $msg"
    Write-Host $entry
    Add-Content -Path $LogFile -Value "  - $entry" -Encoding UTF8
}

# ========== 解决GitHub 502: 强制HTTPS走443端口 ==========
# GitHub的SSH端口(22)经常被GFW阻断，走HTTPS/443绕过
git config --global url."https://github.com/".insteadOf "git@github.com:"
git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"

Set-Location $RepoRoot

# 检查变更
$status = git status --short 2>&1
if ($LASTEXITCODE -ne 0) { Write-Log "ERROR: git status failed"; exit 1 }

if (-not $status -or [string]::IsNullOrWhiteSpace($status)) {
    Write-Log "无变更，跳过推送"
    exit 0
}

Write-Log "检测到变更，准备推送..."
Write-Log "变更内容: $($status -join '; ')"

# 添加并提交
git add -A 2>&1 | Out-Null
$commitMsg = "chore: 定时更新 $DateStamp"
git commit -m $commitMsg 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Log "ERROR: git commit failed"
    exit 1
}

Write-Log "提交成功: $commitMsg"

# 推送（带重试）
$success = $false
for ($i = 1; $i -le $MaxRetries; $i++) {
    Write-Log "推送尝试 $i/$MaxRetries..."
    git push origin main 2>&1
    if ($LASTEXITCODE -eq 0) {
        $success = $true
        Write-Log "推送成功"
        break
    }
    Write-Log "推送失败，等待${RetryDelay}秒后重试..."
    Start-Sleep -Seconds $RetryDelay
}

if (-not $success) {
    # ========== 推送失败 → 触发归档 ==========
    Write-Log "ERROR: 推送失败 $( $MaxRetries ) 次，执行增量归档..."
    
    # 恢复提交的变更（避免git中丢失）
    git reset --soft HEAD~1 2>&1 | Out-Null
    Write-Log "已撤销上一次提交（保留变更）"
    
    # 调用归档脚本
    $archiveScript = "$RepoRoot\scripts\incremental-backup.ps1"
    if (Test-Path $archiveScript) {
        Write-Log "执行归档: & `"$archiveScript`" archive"
        & $archiveScript archive
    } else {
        # 手动归档到data/archive/
        $archiveDir = "$RepoRoot\data\archive"
        if (-not (Test-Path $archiveDir)) {
            New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
        }
        $lines = $status -split "`n" | Where-Object { $_ -match '^\s*[AM]' }
        foreach ($line in $lines) {
            $file = $line -replace '^\s*[AM]\s+', ''
            $src = Join-Path $RepoRoot $file
            $dest = Join-Path $archiveDir $file
            if (Test-Path $src) {
                $destDir = Split-Path $dest -Parent
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Move-Item -Path $src -Destination $dest -Force
                Write-Log "已归档: $file → data/archive/$file"
            }
        }
    }
    
    Write-Log "归档完成。请手动检查网络后重试推送。"
    Write-Log "手动恢复归档: & `"$archiveScript`" restore"
    exit 1
}

# ========== 推送成功 → 清理archive ==========
Write-Log "推送成功，清理archive已推送记录..."
$archiveScript = "$RepoRoot\scripts\incremental-backup.ps1"
if (Test-Path $archiveScript) {
    & $archiveScript push 2>&1 | Out-Null
}
Write-Log "完成"
