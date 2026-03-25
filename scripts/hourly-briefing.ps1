# hourly-briefing.ps1 - 每小时简报生成
# 工作目录: C:\Users\Administrator\clawd\agents\workspace-gid
$WorkDir = "C:\Users\Administrator\clawd\agents\workspace-gid"
Set-Location $WorkDir

$ErrorActionPreference = "SilentlyContinue"
$Now = Get-Date

# === 数据过期检测 ===
function Test-StaleData {
    param($TimestampStr)
    $ts = [DateTime]::Parse($TimestampStr)
    $age = ($Now - $ts).TotalHours
    return $age -gt 2
}

# === 价格数据刷新（过期时自动触发）===
$PriceFile = "$WorkDir\data\market\prices_latest.json"
if (Test-Path $PriceFile) {
    $json = Get-Content $PriceFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    $PriceTimestamp = if ($json.crypto.BTC) { $json.crypto.BTC.timestamp } else { $null }
    if ($PriceTimestamp -and (Test-StaleData $PriceTimestamp)) {
        Write-Host "[PRICE-REFRESH] 价格数据过期（>$([Math]::Round((Get-Date).Subtract([DateTime]::Parse($PriceTimestamp)).TotalHours,1))小时），触发采集..."
        try {
            & "$WorkDir\scripts\collect-prices-simple.ps1" -OutputDir "$WorkDir\data\market" 2>&1 | Out-Null
            Write-Host "[PRICE-REFRESH] 价格采集完成"
        } catch {
            Write-Host "[PRICE-REFRESH] 价格采集失败: $_"
        }
    }
}

# === 1. 读取本地价格数据 ===
$PriceFile = "$WorkDir\data\market\prices_latest.json"
$PriceStale = $false
$BtcPrice = $EthPrice = $SolPrice = $null
$PriceSource = $PriceTimestamp = ""

if (Test-Path $PriceFile) {
    $json = Get-Content $PriceFile -Raw | ConvertFrom-Json
    $PriceTimestamp = $json.crypto.BTC.timestamp
    if (Test-StaleData $PriceTimestamp) { $PriceStale = $true }
    $BtcPrice = $json.crypto.BTC.price
    $EthPrice = $json.crypto.ETH.price
    $SolPrice = $json.crypto.SOL.price
    $PriceSource = "OKX_API"
}

# === 2. 读取最新 GitHub 热榜 ===
$TrendingFile = Get-ChildItem "$WorkDir\data\tech\github-trending-*.md" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$TrendingStale = $false
$TrendingContent = ""
$TrendingDate = ""

if ($TrendingFile) {
    $TrendingDate = [System.IO.Path]::GetFileNameWithoutExtension($TrendingFile.FullName) -replace "github-trending-", ""
    if (Test-StaleData $TrendingFile.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")) { $TrendingStale = $true }
    $TrendingContent = Get-Content $TrendingFile.FullName -Raw
}

# === 3. 提取 GitHub Top3 项目 ===
$TopProjects = @()
# 支持 openclaw/openclaw 或 openclaw
if ($TrendingContent -match '(?s)\| \*\*openclaw[/\\].*?\| ([\d.]+) \|') {
    $stars = $Matches[1]; $TopProjects += "openclaw ($stars stars) - AI助手平台"
}
if ($TrendingContent -match '(?s)\| \*\*AutoGPT[/\\].*?\| ([\d.]+) \|') {
    $stars = $Matches[1]; $TopProjects += "AutoGPT ($stars stars) - Agent工作流"
}
if ($TrendingContent -match '(?s)\| \*\*Significant-Gravitas[/\\]AutoGPT.*?\| ([\d.]+) \|') {
    $stars = $Matches[1]; if ($TopProjects.Count -lt 2) { $TopProjects += "AutoGPT ($stars stars) - Agent工作流" }
}
if ($TrendingContent -match '(?s)\| \*\*n8n[/\\].*?\| ([\d.]+) \|') {
    $stars = $Matches[1]; if ($TopProjects.Count -lt 3) { $TopProjects += "n8n ($stars stars) - 工作流自动化" }
}

# 备用：从描述行提取
if ($TopProjects.Count -eq 0 -and $TrendingContent -match 'openclaw.*?(\d+)\s*stars') {
    $TopProjects += "openclaw - AI助手平台"
}

# === 4. 获取 OpenAI 最新新闻 (cn.bing.com) ===
$NewsItems = @()
try {
    $SearchUrl = "https://cn.bing.com/search?q=OpenAI+site:openai.com+OR+site:techcrunch.com&format=rss"
    $Feed = Invoke-RestMethod $SearchUrl -TimeoutSec 10 -UserAgent "Mozilla/5.0"
    if ($Feed -and $Feed.Count -gt 0) {
        $Top3 = $Feed | Select-Object -First 3
        foreach ($item in $Top3) {
            $title = $item.title -replace '<[^>]+>', ''
            $NewsItems += "• $title"
        }
    }
} catch {
    $NewsItems += "• [新闻获取失败，将使用缓存]"
}

# === 5. 生成简报 ===
$DateStr = $Now.ToString("yyyy-MM-dd HH:mm")
$Weekday = $Now.ToString("dddd", [System.Globalization.CultureInfo]::GetCultureInfo("zh-CN"))

# 价格变化简单判断
$Signal = "观望"
if ($BtcPrice -and $SolPrice) {
    if ($BtcPrice -gt 72000 -and $SolPrice -gt 100) { $Signal = "偏多" }
    elseif ($BtcPrice -lt 70000) { $Signal = "偏空" }
}

# === 构建简报内容 ===
$PriceStaleNote = if ($PriceStale) { "_⚠️ 数据可能过期（超过2小时）_`n" } else { "" }
$TopProjectsText = if ($TopProjects) { $TopProjects -join "`n" } else { "暂无数据" }
$TrendingNote = if ($TrendingStale) { "_⚠️ 热榜数据可能过期_" } else { "_数据来源: $TrendingDate_" }
$NewsText = if ($NewsItems.Count -gt 0) { $NewsItems -join "`n" } else { "• [新闻获取失败]" }

$Briefing = @"

---

## 📊 加密市场简报 | $DateStr ($Weekday)

### 💰 价格动态
| 币种 | 价格 | 来源 | 时间戳 |
|------|------|------|--------|
| BTC  | $BtcPrice | $PriceSource | $PriceTimestamp |
| ETH  | $EthPrice | $PriceSource | $PriceTimestamp |
| SOL  | $SolPrice | $PriceSource | $PriceTimestamp |

$PriceStaleNote
### 🔥 重大新闻
$NewsText

### 📂 GitHub Top3
$TopProjectsText
$TrendingNote

### 🎯 信号判断
**$Signal** — BTC: $BtcPrice | SOL: $SolPrice

---
"@

# === 6. 写入 briefings.md（去重：同一小时只保留最新） ===
$BriefingsFile = "$WorkDir\DAILY\briefings.md"
$Header = @"
# 📈 每日简报汇总

"@

# 当前小时的简报标识（精确到小时）
$CurrentHourMarker = "## 📊 加密市场简报 | $DateStr"
# 简报开始标记（定位要删除的块）
$BlockStart = "## 📊 加密市场简报 |"
$BlockEnd = "^---$"

if (-not (Test-Path $BriefingsFile)) {
    New-Item -Path $BriefingsFile -ItemType File -Force | Out-Null
    $Header | Set-Content $BriefingsFile -NoNewline
}

# 读取现有内容，去除同一小时的旧条目
$ExistingContent = Get-Content $BriefingsFile -Raw
if ($ExistingContent) {
    $Lines = $ExistingContent -split "`n"
    $NewLines = @()
    $SkipBlock = $false
    foreach ($Line in $Lines) {
        if ($Line -match "^## 📊 加密市场简报 \| (\d{4}-\d{2}-\d{2} \d{2}):") {
            # 检查是否与当前小时相同
            if ($Line -match "^## 📊 加密市场简报 \| $($Now.ToString('yyyy-MM-dd HH')):") {
                $SkipBlock = $true
                continue
            } else {
                $SkipBlock = $false
            }
        }
        if ($Line -match "^---$" -and $SkipBlock) {
            $SkipBlock = $false
            continue
        }
        if (-not $SkipBlock) {
            $NewLines += $Line
        }
    }
    # 移除末尾空行后重新写入
    $CleanContent = $NewLines | Where-Object { $_ -ne "" -or $LastNonEmpty }
    if ($LastNonEmpty) { $CleanContent += "" }
    $CleanContent -join "`n" | Set-Content $BriefingsFile -NoNewline
}

# 追加新简报
$Briefing | Add-Content -Path $BriefingsFile

# === 7. Git 检测变更 ===
try {
    Set-Location $WorkDir
    $Status = git status --porcelain
    if ($Status) {
        git add .
        git commit -m "简报更新: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        git push 2>&1 | Out-Null
        Write-Host "[INFO] 简报已提交并推送"
    } else {
        Write-Host "[INFO] 无变更，跳过提交"
    }
} catch {
    Write-Host "[WARN] Git操作失败: $_"
}

Write-Host "[OK] 简报生成完成"
