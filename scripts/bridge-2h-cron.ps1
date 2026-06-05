# bridge-2h-cron.ps1 - 12:00-16:00 数据桥接 + 决策点预备
# 用途: 填补 4h cron 间隔真空期,持续监测 16:30 决策点触发条件
# 触发: 每 2h (12:00 / 14:00 / 16:00 等) 由 Task Scheduler 调度
# 派单方: agent:gida:meta-planner (2026-06-05 设计)

param(
    [string]$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid",
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Continue"
$DateStr = Get-Date -Format "yyyy-MM-dd"
$TimeStr = Get-Date -Format "HH:mm"
$HourCompact = Get-Date -Format "HH"
$LogFile = "$RepoRoot\data\bridge\bridge-$DateStr-$HourCompact.log"
$OutputJson = "$RepoRoot\data\bridge\bridge-snapshot-$DateStr-$HourCompact.json"

# 确保输出目录存在
New-Item -ItemType Directory -Path "$RepoRoot\data\bridge" -Force | Out-Null

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Level] $(Get-Date -Format 'HH:mm:ss') - $Message"
    Write-Host $entry
    Add-Content -Path $LogFile -Value $entry -Encoding UTF8
}

Write-Log "========== 桥接采集开始 =========="

# === 1. 读取已有价格快照 ===
$PriceFile = "$RepoRoot\data\market\prices_latest.json"
$btc = $eth = $sol = $null
$btcAge = -1

if (Test-Path $PriceFile) {
    try {
        $json = Get-Content $PriceFile -Raw | ConvertFrom-Json
        if ($json.crypto.BTC) { $btc = [double]$json.crypto.BTC.price }
        if ($json.crypto.ETH) { $eth = [double]$json.crypto.ETH.price }
        if ($json.crypto.SOL) { $sol = [double]$json.crypto.SOL.price }
        if ($json.crypto.BTC.timestamp) {
            $btcTs = [DateTime]::Parse($json.crypto.BTC.timestamp)
            $btcAge = [int]((Get-Date) - $btcTs).TotalMinutes
        }
        Write-Log "BTC $btc (age ${btcAge}min) / ETH $eth / SOL $sol"
    } catch {
        Write-Log "价格 JSON 解析失败: $_" "WARN"
    }
}

# === 2. F&G 实时检查 (alternative.me 公开 API,无需 GFW) ===
try {
    $fngUrl = "https://api.alternative.me/fng/?limit=1&format=json"
    $fngResp = Invoke-RestMethod -Uri $fngUrl -TimeoutSec 10
    $fngValue = [int]$fngResp.data[0].value
    $fngClass = $fngResp.data[0].value_classification
    Write-Log "F&G = $fngValue ($fngClass)"
} catch {
    $fngValue = $null
    $fngClass = "FETCH_FAILED"
    Write-Log "F&G 抓取失败: $_" "WARN"
}

# === 3. 价格异动判定 (vs 上一次 cron) ===
$prevJson = "$RepoRoot\data\bridge\bridge-snapshot-$DateStr-$(($HourCompact - 2).ToString('00')).json"
$btcDeltaPct = 0
if (Test-Path $prevJson) {
    $prev = Get-Content $prevJson -Raw | ConvertFrom-Json
    if ($prev.btc) {
        $btcDeltaPct = [math]::Round((($btc - $prev.btc) / $prev.btc) * 100, 3)
        Write-Log "BTC delta (2h): $btcDeltaPct%"
    }
}

# === 4. 决策点触发矩阵判定 ===
$trigger1630 = @{
    btc_position = if ($btc) { 
        if ($btc -gt 63000) { "above_63k" }
        elseif ($btc -gt 62500) { "zone_62500_63000" }
        else { "below_62500" }
    } else { "unknown" }
    fng_status = $fngClass
    delta_2h = $btcDeltaPct
    action = "待 16:30 cron 综合判定"
}

# === 5. 输出 JSON 快照 ===
$snapshot = @{
    timestamp = $TimeStr
    btc = $btc
    eth = $eth
    sol = $sol
    btc_age_min = $btcAge
    fng_value = $fngValue
    fng_class = $fngClass
    btc_delta_2h_pct = $btcDeltaPct
    trigger_1630 = $trigger1630
}

if (-not $DryRun) {
    $snapshot | ConvertTo-Json -Depth 3 | Set-Content -Path $OutputJson -Encoding UTF8
    Write-Log "快照已落盘: $OutputJson"
}

Write-Log "========== 桥接采集完成 =========="

# 输出摘要 (供子智能体抓取)
Write-Host "BRIDGE_SUMMARY: BTC=$btc F&G=$fngValue Delta2h=$btcDeltaPct%"
