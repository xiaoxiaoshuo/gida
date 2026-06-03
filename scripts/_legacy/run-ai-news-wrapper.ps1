# run-ai-news-wrapper.ps1 - Wrapper for AI News scheduled task
# 解决Windows任务计划程序直接调用.ps1脚本的稳定性和权限问题

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"
$LogFile = "$RepoRoot\data\ai\cron_wrapper.log"

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"$timestamp - Wrapper started" | Add-Content -Path $LogFile -Encoding UTF8

# 执行HN采集
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"$timestamp - Running fetch-hn-top30.ps1" | Add-Content -Path $LogFile -Encoding UTF8
try {
    & "$RepoRoot\scripts\fetch-hn-top30.ps1" 2>&1 | Out-Null
    "$timestamp - HN completed, exit: $LASTEXITCODE" | Add-Content -Path $LogFile -Encoding UTF8
} catch {
    "$timestamp - HN error: $($_.Exception.Message)" | Add-Content -Path $LogFile -Encoding UTF8
}

# 执行GH Trending
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"$timestamp - Running gh-trending-v3.ps1" | Add-Content -Path $LogFile -Encoding UTF8
try {
    & "$RepoRoot\scripts\gh-trending-v3.ps1" 2>&1 | Out-Null
    "$timestamp - GH completed, exit: $LASTEXITCODE" | Add-Content -Path $LogFile -Encoding UTF8
} catch {
    "$timestamp - GH error: $($_.Exception.Message)" | Add-Content -Path $LogFile -Encoding UTF8
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"$timestamp - Wrapper finished" | Add-Content -Path $LogFile -Encoding UTF8