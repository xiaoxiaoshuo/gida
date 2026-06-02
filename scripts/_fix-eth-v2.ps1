$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"
Set-Location $RepoRoot

$prev = Get-Content "data\market\prices_2026-06-03_01-18.json" -Raw | ConvertFrom-Json
$prevETH = $prev.crypto.ETH.price
$prevBTC = $prev.crypto.BTC.price

$nowBTC = 67215.22
$btcChg = ($nowBTC - $prevBTC) / $prevBTC
$estETH = [math]::Round($prevETH * (1 + 0.95 * $btcChg), 2)
Write-Host "ETH 估算: $estETH (BTC-ETH 0.95 相关性, BTC 2h: $([math]::Round($btcChg*100,2))%)"

# 读取为 hashtable
$latestJson = Get-Content "data\market\prices_latest.json" -Raw | ConvertFrom-Json
$latestHashtable = @{}
foreach ($prop in $latestJson.PSObject.Properties) {
    $latestHashtable[$prop.Name] = $prop.Value
}
$latestHashtable.crypto.ETH = @{
    price = $estETH
    change_pct = [math]::Round($btcChg * 0.95 * 100, 2)
    timestamp = "2026-06-03 03:11:32"
    raw = "estimated_from_BTC_correlation_0.95"
    confidence = "medium"
    source = "estimated_BTC_ETH_correlation"
}
$latestHashtable | ConvertTo-Json -Depth 5 | Set-Content "data\market\prices_latest.json"
Write-Host "ETH 已修补"

# 验证
$verify = Get-Content "data\market\prices_latest.json" -Raw | ConvertFrom-Json
Write-Host "Verify ETH: price=$($verify.crypto.ETH.price) confidence=$($verify.crypto.ETH.confidence)"
