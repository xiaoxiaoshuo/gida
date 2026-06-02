# heartbeat-self-check.ps1
# 用途: 每6小时扫描工作区，发现数据过期/简报断档/F&G 缺失等问题
# 输出: memory/YYYY-MM-DD.md 追加自检结果
# 触发: 由 cron/heartbeat-selfcheck.conf 注册的计划任务

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"
Set-Location $RepoRoot
$DateStr = Get-Date -Format "yyyy-MM-dd"
$TimeStr = Get-Date -Format "HH:mm:ss"
$LogFile = "$RepoRoot\memory\$DateStr.md"

function Write-Check {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Level] $TimeStr - [HEARTBEAT-SELF-CHECK] $Message"
    Write-Host $entry
    Add-Content -Path $LogFile -Value "  - $entry" -Encoding UTF8
}

Write-Check "===== 心跳自检开始 ====="

# 1. 检查价格数据新鲜度
$priceFile = "$RepoRoot\data\market\prices_latest.json"
if (Test-Path $priceFile) {
    $priceMtime = (Get-Item $priceFile).LastWriteTime
    $age = (Get-Date) - $priceMtime
    if ($age.TotalHours -gt 4) {
        Write-Check "🔴 价格数据过期: $($age.TotalHours.ToString('0.0'))h" "WARN"
    } else {
        Write-Check "✅ 价格数据新鲜 ($($age.TotalHours.ToString('0.0'))h)"
    }
} else {
    Write-Check "🔴 prices_latest.json 不存在" "WARN"
}

# 2. 检查 F&G 数据
$fgFile = "$RepoRoot\data\market\fear-greed_latest.json"
if (Test-Path $fgFile) {
    $fg = Get-Content $fgFile -Raw | ConvertFrom-Json
    $fgDate = [datetime]::Parse($fg.timestamp)
    $age = (Get-Date) - $fgDate
    if ($age.TotalDays -gt 2) {
        Write-Check "🔴 F&G 过期: $($age.TotalDays.ToString('0.0')) 天 (value=$($fg.value))" "WARN"
    } else {
        Write-Check "✅ F&G 新鲜: value=$($fg.value) ($($fg.value_classification))"
    }
} else {
    Write-Check "🔴 fear-greed_latest.json 不存在" "WARN"
}

# 3. 检查今日简报
$briefFile = "$RepoRoot\briefings\$DateStr.md"
if (Test-Path $briefFile) {
    $briefMtime = (Get-Item $briefFile).LastWriteTime
    Write-Check "✅ 今日简报存在: $briefFile (mtime=$($briefMtime.ToString('HH:mm')))"
} else {
    Write-Check "🟡 今日简报缺失: $briefFile（>24h 断档则 WARN）" "INFO"
}

# 4. 检查 cron 状态
$tasks = @("HourlyPriceCollector", "DailyCollector")
foreach ($tn in $tasks) {
    $t = Get-ScheduledTask -TaskName $tn -ErrorAction SilentlyContinue
    if ($t) {
        Write-Check "Cron: $tn → State=$($t.State)"
    } else {
        Write-Check "🔴 Cron 缺失: $tn" "WARN"
    }
}

# 5. 检查 git 状态
$gitStatus = git status --short 2>&1
$changesCount = ($gitStatus | Where-Object { $_ }).Count
Write-Check "Git 未推送变更: $changesCount 条"

Write-Check "===== 心跳自检完成 ====="
