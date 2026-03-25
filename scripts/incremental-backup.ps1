# incremental-backup.ps1 - 增量归档与推送状态管理
# 用途: 数据归档 + 推送状态追踪 + archive清理
# 流程: 采集 → 检查推送 → 失败则归档 → 成功后清理已推送
# ============================================================

param(
    [string]$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid",
    [string]$DataDir = "$RepoRoot\data",
    [string]$ArchiveDir = "$RepoRoot\data\archive",
    [string]$LogFile = "$RepoRoot\memory\$(Get-Date -Format 'yyyy-MM-dd').md",
    [int]$PushRetryCount = 3,
    [int]$PushRetryDelaySec = 30
)

$ErrorActionPreference = "Continue"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$DateStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $msg = "[$Level] $(Get-Date -Format 'HH:mm:ss') - $Message"
    Write-Host $msg
    Add-Content -Path $LogFile -Value "  - $msg" -Encoding UTF8
}

function Get-GitStatus {
    Set-Location $RepoRoot
    $status = git status --short 2>&1
    return @{
        exitCode = $LASTEXITCODE
        output = $status
        hasChanges = -not [string]::IsNullOrWhiteSpace($status)
    }
}

function Invoke-GitPush {
    param([int]$MaxRetries = $PushRetryCount, [int]$DelaySec = $PushRetryDelayDelay)
    Set-Location $RepoRoot
    $success = $false
    $attempts = @()
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        git push origin main 2>&1 | Out-Null
        $sw.Stop()
        $ok = ($LASTEXITCODE -eq 0)
        $attempts += @{ n = $i; ok = $ok; ms = $sw.ElapsedMilliseconds }
        Write-Log "推送 $i/$MaxRetries ... $(if($ok){'成功'}else{'失败'}) ($($sw.ElapsedMilliseconds)ms)"
        if ($ok) { $success = $true; break }
        if ($i -lt $MaxRetries) { Start-Sleep -Seconds $DelaySec }
    }
    
    return @{
        success = $success
        attempts = $attempts
        finalOk = $ok
    }
}

function Get-ArchiveManifest {
    $manifestFile = "$ArchiveDir\_manifest.json"
    if (Test-Path $manifestFile) {
        try {
            return Get-Content $manifestFile -Raw | ConvertFrom-Json
        } catch {}
    }
    return @{ pushed = @(); pending = @() }
}

function Set-ArchiveManifest {
    param([hashtable]$Manifest)
    $manifestFile = "$ArchiveDir\_manifest.json"
    $Manifest | ConvertTo-Json -Depth 4 | Out-File -FilePath $manifestFile -Encoding UTF8
}

function Move-ToArchive {
    # 归档新的未推送文件
    $gitStatus = Get-GitStatus
    if (-not $gitStatus.hasChanges) {
        Write-Log "无新变更，无需归档"
        return @()
    }
    
    $manifest = Get-ArchiveManifest
    $archived = @()
    $lines = $gitStatus.output -split "`n" | Where-Object { $_ -match '^\s*[AM]' }
    
    foreach ($line in $lines) {
        $file = $line -replace '^\s*[AM]\s+', ''
        $srcPath = Join-Path $RepoRoot $file
        $destDir = $ArchiveDir
        $destPath = Join-Path $destDir $file
        
        if (Test-Path $srcPath) {
            # 创建归档子目录
            $destDirForFile = Split-Path $destPath -Parent
            if (-not (Test-Path $destDirForFile)) {
                New-Item -ItemType Directory -Path $destDirForFile -Force | Out-Null
            }
            
            # 如果目标已存在，先删除
            if (Test-Path $destPath) {
                Remove-Item $destPath -Force
            }
            
            Move-Item -Path $srcPath -Destination $destPath -Force
            $manifest.pending += @{
                original_path = $file
                archive_path = $destPath
                archived_at = $DateStr
                size_bytes = (Get-Item $destPath).Length
            }
            $archived += $file
            Write-Log "归档: $file → data/archive/$file"
        }
    }
    
    Set-ArchiveManifest -Manifest $manifest
    return $archived
}

function Clear-ArchiveForPushedFiles {
    # 推送成功后，清理已推送的文件引用
    $manifest = Get-ArchiveManifest
    if ($manifest.pending.Count -eq 0) {
        Write-Log "archive无待清理项目"
        return
    }
    
    $remaining = @()
    foreach ($item in $manifest.pending) {
        $remaining += $item
    }
    $manifest.pending = @()
    $manifest.pushed += $manifest.pending
    Set-ArchiveManifest -Manifest $manifest
    
    # 清理超过7天的已推送记录
    $cutoff = (Get-Date).AddDays(-7)
    $manifest.pushed = $manifest.pushed | Where-Object {
        try { [DateTime]::Parse($_.archived_at) -gt $cutoff } catch { $false }
    }
    Set-ArchiveManifest -Manifest $manifest
    Write-Log "已清理archive历史记录 (保留7天内)"
}

function Restore-Archive {
    # 如果需要从archive恢复文件
    param([string]$Pattern = "*")
    $manifest = Get-ArchiveManifest
    $restored = @()
    
    foreach ($item in $manifest.pending) {
        if ($item.original_path -like $Pattern) {
            $src = $item.archive_path
            $dest = Join-Path $RepoRoot $item.original_path
            if (Test-Path $src) {
                $destDir = Split-Path $dest -Parent
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Move-Item -Path $src -Destination $dest -Force
                $restored += $item.original_path
                Write-Log "恢复: data/archive/$($item.original_path) → $($item.original_path)"
            }
        }
    }
    
    # 更新manifest
    $manifest.pending = $manifest.pending | Where-Object { $restored -notcontains $_.original_path }
    Set-ArchiveManifest -Manifest $manifest
    return $restored
}

# ========== 主流程 ==========
Write-Log "========== 增量备份流程开始 =========="
Write-Log "时间: $DateStr"

$archiveAction = $args[0]
switch ($archiveAction) {
    "archive" {
        # 采集后调用：将新文件归档
        Write-Log "[模式] 归档新变更"
        $archived = Move-ToArchive
        Write-Log "归档完成: $($archived.Count) 个文件"
    }
    "push" {
        # auto-push调用：推送 + 成功后清理
        Write-Log "[模式] 推送 + 清理"
        $pushResult = Invoke-GitPush
        if ($pushResult.success) {
            Write-Log "推送成功，清理archive已推送记录..."
            Clear-ArchiveForPushedFiles
            exit 0
        } else {
            Write-Log "推送失败 $( $PushRetryCount ) 次，进入归档保序..." "WARN"
            $archived = Move-ToArchive
            Write-Log "已归档 $($archived.Count) 个文件到 data/archive/"
            Write-Log "下次推送时将恢复这些文件" "WARN"
            exit 1
        }
    }
    "restore" {
        # 手动恢复：恢复archive中的文件
        $pattern = if ($args[1]) { $args[1] } else { "*" }
        $restored = Restore-Archive -Pattern $pattern
        Write-Log "恢复完成: $($restored.Count) 个文件"
    }
    default {
        # 状态检查
        $gitStatus = Get-GitStatus
        $manifest = Get-ArchiveManifest
        Write-Log "当前状态:"
        Write-Log "  工作区变更: $( if($gitStatus.hasChanges){'有'}else{'无'} )"
        Write-Log "  archive待推送: $($manifest.pending.Count) 个文件"
        Write-Log "  archive已推送历史: $($manifest.pushed.Count) 个文件"
        
        if ($gitStatus.hasChanges) {
            Write-Log "建议: 运行 .\incremental-backup.ps1 archive 先归档"
        }
        if ($manifest.pending.Count -gt 0) {
            Write-Log "建议: 运行 .\incremental-backup.ps1 push 尝试推送"
        }
    }
}

Write-Log "========== 增量备份流程完成 =========="
