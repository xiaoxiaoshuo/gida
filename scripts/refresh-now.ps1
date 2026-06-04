# refresh-now.ps1 - 主代理用即时数据刷新 (无参数调用)
# 用法: pwsh -File scripts/refresh-now.ps1
# 作用: 重跑价格 + HN + GitHub Trending, 写 prices_latest.json + *_latest.json
# 改进 v2: 用子进程执行 (避免 dot-source 入口函数名匹配问题)

$ErrorActionPreference = 'Continue'
$ws = 'C:\Users\Administrator\clawd\agents\workspace-gid'
Set-Location $ws

# 1. 价格刷新
Write-Host "=== 1/3 价格刷新 ===" -ForegroundColor Cyan
& powershell -NoProfile -ExecutionPolicy Bypass -File "$ws\scripts\collect-prices-simple.ps1" 2>&1 | Select-Object -Last 5

# 2. HN top 30
Write-Host "`n=== 2/3 HN top 30 ===" -ForegroundColor Cyan
& powershell -NoProfile -ExecutionPolicy Bypass -File "$ws\scripts\fetch-hn-top30-v3.ps1" 2>&1 | Select-Object -Last 8

# 3. GitHub Trending
Write-Host "`n=== 3/3 GitHub Trending ===" -ForegroundColor Cyan
& powershell -NoProfile -ExecutionPolicy Bypass -File "$ws\scripts\fetch-github-trending-recent.ps1" 2>&1 | Select-Object -Last 8

# 验证
Write-Host "`n=== 验证 latest 文件 ===" -ForegroundColor Cyan
Get-Item "$ws\data\market\prices_latest.json", "$ws\data\tech\hacker-news_latest.json", "$ws\data\tech\github-trending_latest.json" |
    Select-Object FullName, LastWriteTime, @{N='KB';E={[math]::Round($_.Length/1KB,1)}} | Format-Table -AutoSize

Write-Host "== refresh done ==" -ForegroundColor Green
