# hourly-price-collector.ps1 - 每小时价格采集脚本
# 采集内容: BTC/ETH/SOL + VIX + 黄金 + 原油
# 定时: 每小时执行一次
# 使用方式:
#   手动: .\scripts\hourly-price-collector.ps1
#   定时: 通过 cron/hourly-price.conf 配置定时任务
# ============================================================

param(
    [string]$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid",
    [switch]$NoPush   # 跳过 git push
)

$ErrorActionPreference = "Continue"
$DateStr = Get-Date -Format "yyyy-MM-dd"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$HourStr = Get-Date -Format "HH"
$LogFile = "$RepoRoot\memory\$DateStr.md"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Level] $(Get-Date -Format 'HH:mm:ss') - $Message"
    Write-Host $entry
    $memFile = "$RepoRoot\memory\$DateStr.md"
    Add-Content -Path $memFile -Value "  - $entry" -Encoding UTF8
}

function Invoke-GitPush {
    Set-Location $RepoRoot
    $status = git status --short 2>&1
    if (-not $status -or [string]::IsNullOrWhiteSpace($status)) {
        Write-Log "无变更，跳过推送"
        return $true
    }
    Write-Log "变更检测: $($status -join '; ')"
    git add -A 2>&1 | Out-Null
    $commitMsg = "chore: 每小时价格快照 $Timestamp"
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
Write-Log "========== 每小时价格采集 | $Timestamp =========="

# ---------- 1. 加密货币 + 宏观价格 ----------
Write-Log ">> 执行 collect-prices-simple.ps1..."
$priceScript = "$RepoRoot\scripts\collect-prices-simple.ps1"
if (Test-Path $priceScript) {
    & $priceScript -OutputDir "$RepoRoot\data\market" 2>&1 | ForEach-Object {
        if ($_ -match '^\[INFO\]') { Write-Log $_ }
        elseif ($_ -match '^\[WARN\]') { Write-Log $_ "WARN" }
        elseif ($_ -match '^\[ERROR\]') { Write-Log $_ "ERROR" }
    }
} else {
    Write-Log "collect-prices-simple.ps1 未找到" "ERROR"
}

# ---------- 2. 保存每小时快照 data/prices/YYYY-MM-DD-HH.json ----------
$pricesDir = "$RepoRoot\data\prices"
if (-not (Test-Path $pricesDir)) {
    New-Item -ItemType Directory -Path $pricesDir -Force | Out-Null
}

$hourlySnapshotFile = "$pricesDir\$DateStr-$HourStr.json"
$latestPrices = "$RepoRoot\data\market\prices_latest.json"

if (Test-Path $latestPrices) {
    try {
        $snapshotData = @{
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            source = "hourly-price-collector"
        }
        $json = Get-Content $latestPrices -Raw | ConvertFrom-Json
        $snapshotData.crypto = $json.crypto
        $snapshotData.macro = $json.macro
        $snapshotData | ConvertTo-Json -Depth 6 | Out-File -FilePath $hourlySnapshotFile -Encoding UTF8
        Write-Log "每小时快照已保存: data/prices/$DateStr-$HourStr.json"
    } catch {
        Write-Log "每小时快照保存失败: $($_.Exception.Message.Substring(0,80))" "WARN"
    }
} else {
    Write-Log "prices_latest.json 未找到" "WARN"
}

# ---------- 3. Git Push ----------
if (-not $NoPush) {
    Write-Log ">> 推送变更..."
    $pushOk = Invoke-GitPush
    if (-not $pushOk) {
        Write-Log "推送失败，请手动检查" "ERROR"
    }
} else {
    Write-Log ">> 跳过推送 (NoPush模式)"
}

Write-Log "========== 每小时价格采集完成 | $Timestamp =========="
