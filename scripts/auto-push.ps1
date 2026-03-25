# auto-push.ps1 - 定时变更自动推送
# 运行方式: 每日定时或手动执行
# 依赖: git, 当前目录为仓库根

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
    Write-Log "ERROR: 推送失败，已达到最大重试次数"
    Write-Log "请手动检查: cd $RepoRoot; git push origin main"
    exit 1
}
