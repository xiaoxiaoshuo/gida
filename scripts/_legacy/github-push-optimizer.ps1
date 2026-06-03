#!/usr/bin/env pwsh
# GitHub推送优化器 - 解决502错误问题
# 版本: 1.0.0
# 包含智能重试、配置优化、分批处理等最佳实践

param(
    [string]$Action = "push",
    [int]$MaxRetries = 3,
    [int]$InitialDelay = 3,
    [switch]$UseMirror,
    [switch]$DryRun
)

# 颜色输出函数
function Write-Status {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colors = @{
        "INFO" = "White"
        "SUCCESS" = "Green"
        "WARNING" = "Yellow"
        "ERROR" = "Red"
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $colors[$Level]
}

# 优化Git配置
function Optimize-GitConfig {
    Write-Status "优化Git配置..."
    
    # HTTP优化
    git config --global http.postbuffer 104857600  # 100MB
    git config --global http.maxRequests 5
    git config --global http.lowspeedlimit 0
    git config --global http.lowspeedtime 0
    
    # 性能优化
    git config --global core.compression 9
    git config --global core.deltaBaseCacheLimit 2g
    git config --global pack.windowMemory 256m
    git config --global pack.packSizeLimit 256m
    git config --global pack.threads 4
    
    # SSH优化（如果使用SSH）
    git config --global ssh.variant ssh
    
    Write-Status "Git配置优化完成" "SUCCESS"
}

# 获取GitHub镜像URL
function Get-GitHubMirrorUrl {
    param([string]$OriginalUrl)
    
    if ($OriginalUrl -match "github.com/(.+)/(.+).git") {
        $user = $matches[1]
        $repo = $matches[2]
        return "https://bgithub.xyz/${user}/${repo}.git"
    }
    
    return $OriginalUrl
}

# 测试GitHub连接
function Test-GitHubConnection {
    Write-Status "测试GitHub连接..."
    
    # 测试TCP连接
    try {
        $tcpTest = Test-NetConnection -ComputerName github.com -Port 443 -WarningAction SilentlyContinue -ErrorAction Stop
        
        if (-not $tcpTest.TcpTestSucceeded) {
            Write-Status "TCP连接测试失败" "WARNING"
            return $false
        }
    } catch {
        Write-Status "TCP连接测试异常: $_" "WARNING"
    }
    
    # 测试Git协议
    try {
        $startTime = Get-Date
        $result = git ls-remote --heads origin 2>&1
        $duration = (Get-Date) - $startTime
        
        if ($LASTEXITCODE -eq 0) {
            Write-Status "Git协议测试成功 (响应时间: $($duration.TotalMilliseconds)ms)" "SUCCESS"
            return $true
        } else {
            Write-Status "Git协议测试失败: $result" "WARNING"
            return $false
        }
    } catch {
        Write-Status "Git协议测试异常: $_" "WARNING"
        return $false
    }
}

# 智能推送函数
function Push-WithIntelligentRetry {
    param(
        [int]$RetryCount,
        [int]$DelaySeconds,
        [string]$Remote = "origin",
        [string]$Branch = "main"
    )
    
    $attempt = 1
    
    while ($attempt -le $RetryCount) {
        Write-Status "推送尝试 $attempt/$RetryCount..."
        
        try {
            # 第一次尝试标准推送，第二次尝试镜像，后续交替
            if ($UseMirror -or $attempt -eq 2) {
                $mirrorUrl = Get-GitHubMirrorUrl (git remote get-url $Remote)
                Write-Status "使用镜像: $mirrorUrl"
                git push $mirrorUrl $Branch
            } else {
                git push $Remote $Branch
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Status "推送成功！" "SUCCESS"
                return $true
            } else {
                throw "Git推送失败，退出码: $LASTEXITCODE"
            }
        } catch {
            Write-Status "推送失败: $_" "ERROR"
            
            if ($attempt -lt $RetryCount) {
                # 指数退避
                $waitTime = $DelaySeconds * [math]::Pow(2, $attempt - 1)
                Write-Status "等待 ${waitTime}秒后重试..." "WARNING"
                Start-Sleep -Seconds $waitTime
            }
            
            $attempt++
        }
    }
    
    Write-Status "所有推送尝试都失败" "ERROR"
    return $false
}

# 检查待推送状态
function Get-PushStatus {
    $status = git status --porcelain
    $ahead = git rev-list --count origin/main..main 2>$null
    $behind = git rev-list --count main..origin/main 2>$null
    
    return @{
        HasChanges = $status.Count -gt 0
        Ahead = [int]$ahead
        Behind = [int]$behind
    }
}

# 主执行流程
function Main {
    Write-Status "=== GitHub推送优化器启动 ==="
    
    # 1. 优化配置
    Optimize-GitConfig
    
    # 2. 检查状态
    $status = Get-PushStatus
    
    if ($status.Ahead -eq 0 -and -not $status.HasChanges) {
        Write-Status "没有待推送的更改" "WARNING"
        return
    }
    
    Write-Status "待推送状态: 领先 $($status.Ahead) 个commit" "INFO"
    
    if ($status.HasChanges) {
        Write-Status "检测到未提交的更改" "INFO"
    }
    
    # 3. 测试连接
    $connectionOk = Test-GitHubConnection
    
    if (-not $connectionOk) {
        Write-Status "连接质量不佳，但继续尝试..." "WARNING"
    }
    
    # 4. 执行推送（如果启用）
    if (-not $DryRun) {
        $success = Push-WithIntelligentRetry -RetryCount $MaxRetries -DelaySeconds $InitialDelay
        
        if ($success) {
            Write-Status "推送流程完成！" "SUCCESS"
        } else {
            Write-Status "推送流程失败，建议：" "ERROR"
            Write-Status "1. 检查网络连接" "ERROR"
            Write-Status "2. 手动执行: git push origin main" "ERROR"
            Write-Status "3. 如果持续失败，联系管理员" "ERROR"
            exit 1
        }
    } else {
        Write-Status "Dry-run模式，跳过实际推送" "WARNING"
    }
    
    Write-Status "=== GitHub推送优化器完成 ==="
}

# 帮助信息
function Show-Help {
    @"
GitHub推送优化器 - 解决502错误问题

使用方法:
    .\github-push-optimizer.ps1 [-Action <push|status>] [-MaxRetries <次数>] 
                               [-InitialDelay <秒>] [-UseMirror] [-DryRun]

参数:
    -Action       执行的操作: push (默认) 或 status
    -MaxRetries   最大重试次数 (默认: 3)
    -InitialDelay 初始重试延迟秒数 (默认: 3)
    -UseMirror    优先使用GitHub镜像
    -DryRun       只测试不实际推送

示例:
    .\github-push-optimizer.ps1                    # 标准推送
    .\github-push-optimizer.ps1 -UseMirror         # 使用镜像推送
    .\github-push-optimizer.ps1 -Action status     # 只检查状态
"@
}

# 脚本入口点
switch ($Action) {
    "push" { Main }
    "status" { 
        $status = Get-PushStatus
        Write-Status "推送状态检查:"
        Write-Status "  领先远程: $($status.Ahead) 个commit"
        Write-Status "  落后远程: $($status.Behind) 个commit" 
        Write-Status "  未提交更改: $($status.HasChanges)"
    }
    "help" { Show-Help }
    default { 
        Write-Status "未知操作: $Action" "ERROR"
        Show-Help
    }
}