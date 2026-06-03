#!/usr/bin/env pwsh
# 智能GitHub推送策略脚本

param(
    [int]$CommitsPerBatch = 2,
    [int]$MaxRetries = 3,
    [int]$InitialDelay = 3
)

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
}

function Optimize-GitForPush {
    Write-Log "优化Git推送配置..."
    
    # 关键优化参数
    git config --global http.postbuffer 104857600  # 100MB
    git config --global http.maxRequests 5
    git config --global http.lowspeedlimit 0
    git config --global http.lowspeedtime 0
    git config --global core.compression 9
    git config --global core.deltaBaseCacheLimit 2g
    git config --global pack.windowMemory 256m
    git config --global pack.packSizeLimit 256m
    git config --global pack.threads 4
    
    Write-Log "Git配置优化完成"
}

function Get-PendingCommits {
    $commits = git log --oneline origin/main..main
    return $commits.Count
}

function Push-ByBatch {
    param(
        [int]$BatchSize,
        [int]$TotalCommits
    )
    
    $batches = [math]::Ceiling($TotalCommits / $BatchSize)
    Write-Log "待推送 $TotalCommits 个commit，分 $batches 批次推送（每批 $BatchSize 个）"
    
    for ($i = 0; $i -lt $batches; $i++) {
        Write-Log "处理批次 $($i+1)/$batches..."
        
        # 重置到远程分支，然后重新应用最近的commit
        git fetch origin
        
        # 创建临时分支进行分批推送
        $tempBranch = "temp-push-batch-$i"
        git checkout -b $tempBranch origin/main
        
        # 挑选最近的commit
        $skipCommits = $i * $BatchSize
        $cherryPicks = git log --oneline --reverse origin/main..main | 
                       Select-Object -Skip $skipCommits -First $BatchSize
        
        foreach ($commit in $cherryPicks) {
            Write-Log "应用commit: $commit"
            git cherry-pick $commit --no-edit
        }
        
        # 尝试推送这个批次
        $attempt = 1
        $success = $false
        
        while ($attempt -le $MaxRetries -and -not $success) {
            Write-Log "批次 $($i+1) 推送尝试 $attempt/$MaxRetries"
            
            try {
                git push origin $tempBranch:main
                
                if ($LASTEXITCODE -eq 0) {
                    $success = $true
                    Write-Log "批次 $($i+1) 推送成功"
                } else {
                    throw "推送失败，退出码: $LASTEXITCODE"
                }
            } catch {
                Write-Log "批次 $($i+1) 推送失败: $_"
                
                if ($attempt -lt $MaxRetries) {
                    $waitTime = $InitialDelay * [math]::Pow(2, $attempt - 1)
                    Write-Log "等待 ${waitTime}秒后重试..."
                    Start-Sleep -Seconds $waitTime
                    
                    # 重置并重新尝试
                    git reset --hard origin/main
                    foreach ($commit in $cherryPicks) {
                        git cherry-pick $commit --no-edit
                    }
                }
                
                $attempt++
            }
        }
        
        # 清理临时分支
        git checkout main
        git branch -D $tempBranch
        
        if (-not $success) {
            Write-Log "错误: 批次 $($i+1) 推送失败，请手动处理"
            return $false
        }
        
        # 批次间等待
        if ($i -lt $batches - 1) {
            Write-Log "等待5秒后进行下一批次..."
            Start-Sleep -Seconds 5
        }
    }
    
    return $true
}

function Test-GitHubConnectionAdvanced {
    Write-Log "测试GitHub连接质量..."
    
    # 测试TCP连接
    $tcpTest = Test-NetConnection -ComputerName github.com -Port 443 -WarningAction SilentlyContinue
    
    if (-not $tcpTest.TcpTestSucceeded) {
        Write-Log "警告: TCP连接测试失败"
        return $false
    }
    
    # 测试git协议
    try {
        $startTime = Get-Date
        git ls-remote --heads origin > $null 2>&1
        $duration = (Get-Date) - $startTime
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Git协议测试成功 (响应时间: $($duration.TotalMilliseconds)ms)"
            return $true
        } else {
            Write-Log "Git协议测试失败"
            return $false
        }
    } catch {
        Write-Log "Git协议测试异常: $_"
        return $false
    }
}

function Main {
    Write-Log "=== 智能GitHub推送策略开始 ==="
    
    # 1. 优化配置
    Optimize-GitForPush
    
    # 2. 检查连接
    if (-not (Test-GitHubConnectionAdvanced)) {
        Write-Log "警告: 连接质量不佳，继续尝试..."
    }
    
    # 3. 检查待推送commit
    $pendingCommits = Get-PendingCommits
    Write-Log "发现 $pendingCommits 个待推送commit"
    
    if ($pendingCommits -eq 0) {
        Write-Log "没有待推送的commit"
        return
    }
    
    # 4. 分批推送
    $success = Push-ByBatch -BatchSize $CommitsPerBatch -TotalCommits $pendingCommits
    
    if ($success) {
        Write-Log "✓ 所有批次推送成功！"
    } else {
        Write-Log "✗ 推送过程遇到错误，请检查日志"
        exit 1
    }
    
    Write-Log "=== 智能推送策略完成 ==="
}

# 执行主流程
Main