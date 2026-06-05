# fomc-d7-tracker.ps1 - 6/13 FOMC 决策日 D7 发酵追踪
# 用途: 距 6/13 FOMC 8 天,D7 关键节点跟踪美联储信号 + 市场定价
# 触发: 每日 09:00 / 17:00 (Asia/US 段双采集)
# 派单方: agent:gida:meta-planner (2026-06-05 设计)

param(
    [string]$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid",
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Continue"
$DateStr = Get-Date -Format "yyyy-MM-dd"
$TimeStr = Get-Date -Format "HH:mm"
$LogFile = "$RepoRoot\data\fomc\d7-tracker-$DateStr.log"
$OutputJson = "$RepoRoot\data\fomc\fomc-d7-snapshot-$DateStr.json"

New-Item -ItemType Directory -Path "$RepoRoot\data\fomc" -Force | Out-Null

# === 1. 计算距 FOMC 天数 ===
$fomcTarget = Get-Date "2026-06-13"
$daysToFomc = [int]($fomcTarget - (Get-Date)).TotalDays
$dTag = switch ($daysToFomc) {
    7 { "D7" } 6 { "D6" } 5 { "D5" } 4 { "D4" } 3 { "D3" }
    2 { "D2" } 1 { "D1" } 0 { "D0" } default { "D$daysToFomc" }
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Level] $(Get-Date -Format 'HH:mm:ss') [$dTag] - $Message"
    Write-Host $entry
    Add-Content -Path $LogFile -Value $entry -Encoding UTF8
}

Write-Log "========== FOMC D$daysToFomc 发酵追踪开始 =========="

# === 2. 当前价格快照 ===
$PriceFile = "$RepoRoot\data\market\prices_latest.json"
$btc = $eth = $fng = $oil = $gold = $null

if (Test-Path $PriceFile) {
    try {
        $json = Get-Content $PriceFile -Raw | ConvertFrom-Json
        if ($json.crypto.BTC) { $btc = [double]$json.crypto.BTC.price }
        if ($json.crypto.ETH) { $eth = [double]$json.crypto.ETH.price }
        if ($json.macro.FNG) { $fng = $json.macro.FNG.value }
        elseif ($json.macro.VIX) { $fng = $json.macro.VIX.value }  # FNG 替代 VIX 降级
        if ($json.macro.OIL) { $oil = $json.macro.OIL.value }
        if ($json.macro.GOLD) { $gold = $json.macro.GOLD.value }
        Write-Log "快照: BTC $btc / ETH $eth / F&G $fng / OIL $oil / GOLD $gold"
    } catch {
        Write-Log "价格 JSON 解析失败: $_" "WARN"
    }
}

# === 3. FOMC 关键监控点 ===
$fomcWatchlist = @{
    D7_focus = "通胀粘性 + JOLTS/职位空缺 + ISM 价格分项"
    D3_focus = "6/11 Fed 静默期前最后一次官员讲话 (Williams/Daly)"
    D2_focus = "6/11-12 GTC Paris 黄仁勋主题演讲 (BTC 杠杆资金联动)"
    D0_focus = "6/13 02:00 ET SEP dot plot + Powell press conf"
    key_dates = @(
        @{ date = "06-09"; event = "JOLTS 职位空缺"; impact = "P1" },
        @{ date = "06-10"; event = "CPI 5月数据"; impact = "P0" },
        @{ date = "06-11"; event = "PPI + 6/12 GTC Paris 开幕"; impact = "P0" },
        @{ date = "06-12"; event = "GTC Paris Keynote (黄仁勋)"; impact = "P0" },
        @{ date = "06-13"; event = "FOMC 决议 02:00 ET + 鲍威尔记者会 02:30"; impact = "P0" }
    )
}

# === 4. 派单方 5 场景概率加权 (基线 v1) ===
$scenarios = @{
    dovish_25bp = @{ prob = 30; impact = "+1.5% BTC"; trigger = "CPI <0.2% + NFP <100K" }
    hawkish_pause = @{ prob = 45; impact = "-0.5% BTC"; trigger = "CPI 0.3%+ NFP >180K" }
    dovish_50bp = @{ prob = 10; impact = "+3.0% BTC"; trigger = "CPI <0.1% + 失业率 >4.2%" }
    hawkish_hike = @{ prob = 5; impact = "-2.5% BTC"; trigger = "CPI >0.4% 通胀重新加速" }
    dovish_pause = @{ prob = 10; impact = "+0.5% BTC"; trigger = "CPI 0.2-0.3% 基线" }
}

# === 5. 6/13 NVDA 财报联动 (D0 同日) ===
$nvdaWatch = @{
    earnings_date = "2026-06-14 05:00 GMT+8 (美东 6/13 17:00)"
    key_metrics = @("Q2 Data Center Revenue", "Blackwell 出货节奏", "Q3 Guidance", "中国业务 H20/RTX 进展")
    iv_skew = "65% 偏看涨 (Call/Put 1.85)"
    linkage_to_fomc = "Blackwell capex 指引可能强化/弱化 FOMC AI 投资叙事"
}

# === 6. 输出快照 ===
$snapshot = @{
    timestamp = $TimeStr
    days_to_fomc = $daysToFomc
    d_tag = $dTag
    price_snapshot = @{
        btc = $btc
        eth = $eth
        fng = $fng
        oil = $oil
        gold = $gold
    }
    fomc_watchlist = $fomcWatchlist
    scenarios = $scenarios
    nvda_watch = $nvdaWatch
    next_critical_event = "6/10 20:30 CPI 5月 (D3)"
}

if (-not $DryRun) {
    $snapshot | ConvertTo-Json -Depth 4 | Set-Content -Path $OutputJson -Encoding UTF8
    Write-Log "快照已落盘: $OutputJson"
}

Write-Log "========== FOMC D$daysToFomc 追踪完成 =========="
Write-Host "FOMC_SUMMARY: D$daysToFomc | BTC=$btc | scenarios weighted: dovish_50bp(10%)+dovish_25bp(30%)+dovish_pause(10%) = 50% dovish"
