# fomc-d7-tracker.ps1 - FOMC D7 发酵追踪 (CPI 4.2% 后重建 v2)
# 用途: 距 7/28-29 FOMC 追踪美联储信号 + 市场定价
# 注: 6/16-17 FOMC 已过(鹰派维持), 7/28-29 为下一个关键窗口
# 触发: 每日 09:00 / 17:00 (Asia/US 段双采集)

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

# === 1. 计算距下次 FOMC (7/28-29) 天数 ===
$fomcTarget = Get-Date "2026-07-29"
$daysToFomc = [int]($fomcTarget - (Get-Date)).TotalDays

# === 2. 当前价格快照 ===
$PriceFile = "$RepoRoot\data\market\prices_latest.json"
$btc = $eth = $fng = $oil = $gold = $null

if (Test-Path $PriceFile) {
    try {
        $json = Get-Content $PriceFile -Raw | ConvertFrom-Json
        if ($json.crypto.BTC) { $btc = [double]$json.crypto.BTC.price }
        if ($json.crypto.ETH) { $eth = [double]$json.crypto.ETH.price }
        if ($json.macro.FNG) { $fng = $json.macro.FNG.value }
        elseif ($json.macro.VIX) { $fng = $json.macro.VIX.value }
        if ($json.macro.OIL) { $oil = $json.macro.OIL.value }
        if ($json.macro.GOLD) { $gold = $json.macro.GOLD.value }
    } catch {
        Write-Warning "价格 JSON 解析失败: $_"
    }
}

# === 3. FOMC 关键监控点 (CPI 4.2% 后重建) ===
$fomcWatchlist = @{
    D36_focus = "CPI 5月 4.2% 后续影响 + 7/10 CPI 6月前瞻"
    D14_focus = "6/23-7/10 官员密集讲话窗口 (静默前最后一次)"
    D7_focus  = "7/10 CPI 6月数据 (下一个P0)"
    D3_focus  = "7/25 Fed 静默期前最后一次官员讲话"
    D1_focus  = "7/28-29 FOMC Warsh第2次会 (鹰派维持概率高)"
    key_dates = @(
        @{ date = "06-01"; event = "GTC Taipei (已过)"; impact = "P1" },
        @{ date = "06-17"; event = "6月FOMC 14:00 ET 鹰派维持 (已过)"; impact = "P0" },
        @{ date = "07-10"; event = "CPI 6月数据 20:30 ET"; impact = "P0" },
        @{ date = "07-28"; event = "FOMC Day1 11:00 ET"; impact = "P0" },
        @{ date = "07-29"; event = "FOMC Day2 14:00 ET + 鲍威尔记者会"; impact = "P0" }
    )
}

# === 4. CPI 4.2% 公布后的场景重建 (v2) ===
# 当前现实: CPI 5月 4.2% YoY, FOMC 6/16-17 维持利率但鹰派, 半数委员预期加息
$scenarios = @{
    hawkish_hike = @{ prob = 40; impact = "-3~5% BTC"; trigger = "CPI 6月持续>4% → 7月加息25bp" }
    hawkish_pause = @{ prob = 35; impact = "-1~0% BTC"; trigger = "CPI 6月放缓但仍>3.5% → 维持" }
    dovish_pause  = @{ prob = 15; impact = "+2~3% BTC"; trigger = "CPI 6月意外下降 → 降息信号" }
    dovish_25bp   = @{ prob = 10; impact = "+5% BTC"; trigger = "经济数据恶化 → 7月降息25bp" }
}

# === 5. 输出快照 ===
$snapshot = @{
    timestamp = $TimeStr
    days_to_fomc = $daysToFomc
    fomc_date = "2026-07-28/29"
    price_snapshot = @{
        btc = $btc
        eth = $eth
        fng = $fng
        oil = $oil
        gold = $gold
    }
    fomc_watchlist = $fomcWatchlist
    scenarios = $scenarios
    next_critical_event = "7/10 CPI 6月 (下一个P0)"
    context_note = "CPI 5月 4.2% YoY | 6月FOMC鹰派维持 | 半数委员预期加息 | 7/28-29沃什第2次会"
}

if (-not $DryRun) {
    $snapshot | ConvertTo-Json -Depth 4 | Set-Content -Path $OutputJson -Encoding UTF8
}

Write-Host "FOMC_SUMMARY: D$daysToFomc | next=7/28-29 | BTC=$btc | hawkish_hike(40%)+hawkish_pause(35%) = 75% 鹰派倾斜"
