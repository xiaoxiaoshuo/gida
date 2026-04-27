# daily-collector.ps1 - 每日定时采集主脚本
# 采集内容: 黄金/原油/VIX/F&G指数 + AI新闻 + GitHub Trending
# 定时: 每日 08:00 / 20:00 (北京时间)
# 使用方式:
#   手动: .\scripts\daily-collector.ps1
#   定时: 通过 cron/daily-collection.conf 配置定时任务
# ============================================================

param(
    [string]$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid",
    [switch]$NoPush   # 跳过 git push（定时任务中不建议使用）
)

$ErrorActionPreference = "Continue"
$DateStr = Get-Date -Format "yyyy-MM-dd"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$LogFile = "$RepoRoot\memory\$DateStr.md"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Level] $(Get-Date -Format 'HH:mm:ss') - $Message"
    Write-Host $entry
    $memFile = "$RepoRoot\memory\$DateStr.md"
    Add-Content -Path $memFile -Value "  - $entry" -Encoding UTF8
}

function Invoke-GitPush {
    # 封装 auto-push.ps1 的推送逻辑（不调用脚本避免嵌套）
    Set-Location $RepoRoot
    $status = git status --short 2>&1
    if (-not $status -or [string]::IsNullOrWhiteSpace($status)) {
        Write-Log "无变更，跳过推送"
        return $true
    }
    Write-Log "变更检测: $($status -join '; ')"
    git add -A 2>&1 | Out-Null
    $commitMsg = "chore: 每日采集 $DateStr $(Get-Date -Format 'HH:mm')"
    git commit -m $commitMsg 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Log "git commit 失败" "ERROR"
        return $false
    }
    for ($i = 1; $i -le 3; $i++) {
        Write-Log "git push 尝试 $i/3..."
        git push origin main 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "推送成功"
            return $true
        }
        Start-Sleep -Seconds 30
    }
    Write-Log "推送失败 3 次" "ERROR"
    return $false
}

# ============================================================
Write-Log "========== 每日采集开始 | $Timestamp =========="

# ---------- 1. 宏观数据 (黄金/原油/VIX) via IE COM ----------
Write-Log ">> [1/3] 宏观数据采集..."
$macroScript = "$RepoRoot\scripts\collect-macro-playwright.ps1"
if (Test-Path $macroScript) {
    Write-Log "执行 collect-macro-playwright.ps1..."
    & $macroScript -OutputDir "$RepoRoot\data\market" 2>&1 | ForEach-Object {
        if ($_ -match '^\[INFO\]') { Write-Log $_ }
        elseif ($_ -match '^\[WARN\]') { Write-Log $_ "WARN" }
        elseif ($_ -match '^\[ERROR\]') { Write-Log $_ "ERROR" }
    }
} else {
    Write-Log "collect-macro-playwright.ps1 未找到" "WARN"
}

# 更新宏观数据汇总文件 macro-YYYY-MM-DD.json
$macroDailyFile = "$RepoRoot\data\macro-$DateStr.json"
$latestPrices = "$RepoRoot\data\market\prices_latest.json"
if (Test-Path $latestPrices) {
    try {
        $macroData = @{
            date = $DateStr
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            source = "daily-collector"
        } | ConvertTo-Json -AsArray -Depth 3
        # 读取 prices_latest 中的 macro 部分
        $json = Get-Content $latestPrices -Raw | ConvertFrom-Json
        if ($json.macro) {
            $macroData = @{
                date = $DateStr
                timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                data = $json.macro
            }
            $macroData | ConvertTo-Json -Depth 6 | Out-File -FilePath $macroDailyFile -Encoding UTF8
            Write-Log "宏观数据已保存: data/macro-$DateStr.json"
        }
    } catch {
        Write-Log "宏观数据汇总失败: $($_.Exception.Message.Substring(0,80))" "WARN"
    }
}

# ---------- 2. AI新闻 + GitHub Trending ----------
Write-Log ">> [2/3] AI新闻采集..."
$techNewsScript = "$RepoRoot\scripts\collect-tech-news.ps1"
if (Test-Path $techNewsScript) {
    Write-Log "执行 collect-tech-news.ps1..."
    & $techNewsScript -OutputDir "$RepoRoot\data\tech" 2>&1 | ForEach-Object {
        if ($_ -match '^\[INFO\]') { Write-Log $_ }
        elseif ($_ -match '^\[WARN\]') { Write-Log $_ "WARN" }
        elseif ($_ -match '^\[ERROR\]') { Write-Log $_ "ERROR" }
    }
} else {
    Write-Log "collect-tech-news.ps1 未找到" "WARN"
}

# AI新闻归档: data/ai/ai-news-YYYY-MM-DD.json
$aiNewsFile = "$RepoRoot\data\ai\ai-news-$DateStr.json"
$aiLatest = "$RepoRoot\data\tech\github-trending_latest.json"
$techLatest = "$RepoRoot\data\tech\github-trending_latest.json"
if (Test-Path $techLatest) {
    try {
        Copy-Item -Path $techLatest -Destination $aiNewsFile -Force
        Write-Log "AI新闻已归档: data/ai/ai-news-$DateStr.json"
    } catch {
        Write-Log "AI新闻归档失败: $($_.Exception.Message.Substring(0,80))" "WARN"
    }
}

# ---------- 3. GitHub Trending 历史 (github-trending-history.json) ----------
Write-Log ">> [3/3] GitHub Trending 历史追加..."
$ghTrendingHistory = "$RepoRoot\data\github-trending-history.json"
$ghLatest = "$RepoRoot\data\tech\github-trending_latest.json"

if (Test-Path $ghLatest) {
    try {
        $todayEntry = @{
            date = $DateStr
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            repos = @()
        }
        $ghJson = Get-Content $ghLatest -Raw | ConvertFrom-Json
        if ($ghJson.projects) {
            $todayEntry.repos = $ghJson.projects
        }

        # 读取或创建历史记录
        if (Test-Path $ghTrendingHistory) {
            $history = @()
            try {
                $history = Get-Content $ghTrendingHistory -Raw | ConvertFrom-Json
                if ($history -is [System.Object[]]) {
                    $history = [System.Collections.ArrayList]@($history)
                } else {
                    $history = [System.Collections.ArrayList]@($history)
                }
            } catch {
                $history = [System.Collections.ArrayList]@()
            }
        } else {
            $history = [System.Collections.ArrayList]@()
        }

        # 追加今日记录（去重: 同一天不重复）
        $alreadyExists = $false
        foreach ($item in $history) {
            if ($item.date -eq $DateStr) {
                $item.timestamp = $todayEntry.timestamp
                $item.repos = $todayEntry.repos
                $alreadyExists = $true
                break
            }
        }
        if (-not $alreadyExists) {
            $history.Add($todayEntry) | Out-Null
        }

        $history | ConvertTo-Json -Depth 6 | Out-File -FilePath $ghTrendingHistory -Encoding UTF8
        Write-Log "GitHub Trending 历史已更新 (共 $($history.Count) 条记录)"
    } catch {
        Write-Log "GitHub Trending 历史更新失败: $($_.Exception.Message.Substring(0,80))" "WARN"
    }
} else {
    Write-Log "github-trending_latest.json 未找到，跳过历史更新" "WARN"
}

# ---------- 4. Git Push ----------
if (-not $NoPush) {
    Write-Log ">> [4/4] 推送变更..."
    $pushOk = Invoke-GitPush
    if (-not $pushOk) {
        Write-Log "推送失败，请手动检查" "ERROR"
    }
} else {
    Write-Log ">> [4/4] 跳过推送 (NoPush模式)"
}

Write-Log "========== 每日采集完成 | $Timestamp =========="
