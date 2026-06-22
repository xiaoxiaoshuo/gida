# G-61 (P0): Tech-to-AI 镜像 cron
# 修复 4 周黑洞: data/ai/hacker-news_latest.json 28.3d 老化
# 修复: data/ai/tech-news_latest.json 28.3d 老化
# 根因: AINewsCollector_0400 跑 tech/hacker-news_latest.json 但 ai/ 没同步
# 修复: 每次 AINewsCollector 跑完后, 镜像到 ai/ 目录

$repoRoot = 'C:\Users\Administrator\clawd\agents\workspace-gid'
$logFile = Join-Path $repoRoot 'data\system\G61-sync-2026-06-05.log'
$startTime = Get-Date

function Log {
    param([string]$msg)
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $msg
    Write-Host $line
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

Log "G61 mirror start"

# Mirror 1: tech/hacker-news_latest.json -> ai/hacker-news_latest.json
$src = Join-Path $repoRoot 'data\tech\hacker-news_latest.json'
$dst = Join-Path $repoRoot 'data\ai\hacker-news_latest.json'
if (Test-Path $src) {
    Copy-Item -Path $src -Destination $dst -Force
    $sz = (Get-Item $dst).Length
    $age = ((Get-Date) - (Get-Item $src).LastWriteTime).TotalMinutes
    Log ("[MIRROR] hacker-news: tech -> ai ({0}KB, source age={1:N0}m)" -f [int]($sz/1024), $age)
} else {
    Log "[FAIL] tech/hacker-news_latest.json not found"
}

# Mirror 2: ai/ai-news_latest.json -> ai/tech-news_latest.json (legacy alias)
$src2 = Join-Path $repoRoot 'data\ai\ai-news_latest.json'
$dst2 = Join-Path $repoRoot 'data\ai\tech-news_latest.json'
if (Test-Path $src2) {
    Copy-Item -Path $src2 -Destination $dst2 -Force
    $sz2 = (Get-Item $dst2).Length
    $age2 = ((Get-Date) - (Get-Item $src2).LastWriteTime).TotalMinutes
    Log ("[MIRROR] tech-news: ai/ai-news -> ai/tech-news ({0}KB, source age={1:N0}m)" -f [int]($sz2/1024), $age2)
} else {
    Log "[FAIL] ai/ai-news_latest.json not found"
}

# Mirror 3: hourly archive copy
$ts = Get-Date -Format 'yyyy-MM-dd_HH-00'
$dst3 = Join-Path $repoRoot "data\ai\hacker-news-$ts.json"
if (Test-Path $src) {
    if (Test-Path $dst3) { Remove-Item $dst3 -Force }
    Copy-Item -Path $src -Destination $dst3 -Force
    Log ("[ARCHIVE] hacker-news-{0}: {1}KB" -f $ts, [int]((Get-Item $dst3).Length/1024))
}

$elapsed = ((Get-Date) - $startTime).TotalSeconds
Log ("G61 mirror done: {0:N1}s" -f $elapsed)
