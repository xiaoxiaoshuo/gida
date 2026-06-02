$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"
Set-Location $RepoRoot

$prev = Get-Content "data\market\prices_2026-06-03_01-18.json" -Raw | ConvertFrom-Json
$prevETH = $prev.crypto.ETH.price
$prevBTC = $prev.crypto.BTC.price

$nowBTC = 67215.22
$btcChg = ($nowBTC - $prevBTC) / $prevBTC
$estETH = [math]::Round($prevETH * (1 + 0.95 * $btcChg), 2)
Write-Host "ETH 估算: $estETH"

# 整体重建为纯 hashtable
$latestJson = Get-Content "data\market\prices_latest.json" -Raw | ConvertFrom-Json

# crypto 重构
$cryptoNew = @{
    BTC = @{
        price = [decimal]$latestJson.crypto.BTC.price
        timestamp = $latestJson.crypto.BTC.timestamp
        raw = $latestJson.crypto.BTC.raw
        confidence = $latestJson.crypto.BTC.confidence
        source = $latestJson.crypto.BTC.source
    }
    SOL = @{
        price = [decimal]$latestJson.crypto.SOL.price
        timestamp = $latestJson.crypto.SOL.timestamp
        raw = $latestJson.crypto.SOL.raw
        confidence = $latestJson.crypto.SOL.confidence
        source = $latestJson.crypto.SOL.source
    }
    ETH = @{
        price = $estETH
        change_pct = [math]::Round($btcChg * 0.95 * 100, 2)
        timestamp = "2026-06-03 03:11:32"
        raw = "estimated_from_BTC_correlation_0.95"
        confidence = "medium"
        source = "estimated_BTC_ETH_correlation"
    }
}

# macro 保留
$macroNew = @{
    VIX = @{
        value = [decimal]$latestJson.macro.VIX.value
        source = $latestJson.macro.VIX.source
        timestamp = $latestJson.macro.VIX.timestamp
        confidence = $latestJson.macro.VIX.confidence
    }
    OIL = @{
        value = [decimal]$latestJson.macro.OIL.value
        source = $latestJson.macro.OIL.source
        timestamp = $latestJson.macro.OIL.timestamp
        confidence = $latestJson.macro.OIL.confidence
        unit = $latestJson.macro.OIL.unit
    }
    GOLD = @{
        value = [decimal]$latestJson.macro.GOLD.value
        source = $latestJson.macro.GOLD.source
        timestamp = $latestJson.macro.GOLD.timestamp
        confidence = $latestJson.macro.GOLD.confidence
        unit = $latestJson.macro.GOLD.unit
    }
}

$result = @{
    timestamp = $latestJson.timestamp
    collection_version = $latestJson.collection_version
    crypto = $cryptoNew
    macro = $macroNew
    note = "ETH 03:11 采集失败，使用 BTC-ETH 0.95 相关性估算"
}

$result | ConvertTo-Json -Depth 6 | Set-Content "data\market\prices_latest.json"
Write-Host "✅ ETH 已修补"

# 验证
$verify = Get-Content "data\market\prices_latest.json" -Raw | ConvertFrom-Json
Write-Host "Verify: ETH price=$($verify.crypto.ETH.price) confidence=$($verify.crypto.ETH.confidence)"
Write-Host "All crypto: BTC=$($verify.crypto.BTC.price) ETH=$($verify.crypto.ETH.price) SOL=$($verify.crypto.SOL.price)"
