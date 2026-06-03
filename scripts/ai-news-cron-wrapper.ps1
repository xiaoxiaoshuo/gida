# ai-news-cron-wrapper.ps1
# AINewsCollector_6h 调度任务的执行 wrapper
# 修复 2026-06-04: 之前 cron 调用的 wrapper 已被 archive/, 但 cron 任务仍指向不存在的脚本
# 修复: 创建新 wrapper, 使用现有的 fetch-hn-top30-v2.ps1 + gh-trending-browser-v5.ps1
# 修复: 添加详细日志到 data/ai/cron_wrapper.log

$logFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\cron_wrapper.log"
$workspace = "C:\Users\Administrator\clawd\agents\workspace-gid\scripts"

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $logFile -Value "$timestamp - Wrapper started (v2, 2026-06-04 fix)"

# 任务 1: HN Top 抓取
Add-Content -Path $logFile -Value "$timestamp - Running fetch-hn-top30-v2.ps1"
try {
  & "$workspace\fetch-hn-top30-v2.ps1" 2>&1 | Out-Null
  Add-Content -Path $logFile -Value "$timestamp - HN completed, exit: $LASTEXITCODE"
} catch {
  Add-Content -Path $logFile -Value "$timestamp - HN error: $_"
}

# 任务 2: GitHub Trending 抓取
Add-Content -Path $logFile -Value "$timestamp - Running gh-trending-browser-v5.ps1"
try {
  & "$workspace\gh-trending-browser-v5.ps1" 2>&1 | Out-Null
  Add-Content -Path $logFile -Value "$timestamp - GH completed, exit: $LASTEXITCODE"
} catch {
  Add-Content -Path $logFile -Value "$timestamp - GH error: $_"
}

# 任务 3: AI 新闻整合 (如有新数据)
Add-Content -Path $logFile -Value "$timestamp - Running merge-ai-news.ps1"
try {
  & "$workspace\merge-ai-news.ps1" 2>&1 | Out-Null
  Add-Content -Path $logFile -Value "$timestamp - Merge completed, exit: $LASTEXITCODE"
} catch {
  Add-Content -Path $logFile -Value "$timestamp - Merge error: $_"
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $logFile -Value "$timestamp - Wrapper finished"
