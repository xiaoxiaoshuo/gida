$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"
Set-Location $RepoRoot

$prev = Get-Content "data\market\prices_2026-06-03_01-18.json" -Raw | ConvertFrom-Json
$prevETH = $prev.crypto.ETH.price
$prevBTC = $prev.crypto.BTC.price
Write-Host "01:18: BTC=$prevBTC ETH=$prevETH ETH/BTC=$([math]::Round($prevETH/$prevBTC,5))"

$nowBTC = 67215.22
$btcChg = ($nowBTC - $prevBTC) / $prevBTC
Write-Host "BTC 2h 变化: $([math]::Round($btcChg*100,2))%"

$estETH = $prevETH * (1 + 0.95 * $btcChg)
Write-Host "ETH 估算: $([math]::Round($estETH, 2)) (置信度: 中, BTC-ETH 0.95 滚动相关性)"

$latest = Get-Content "data\market\prices_latest.json" -Raw | ConvertFrom-Json
$latest.crypto.ETH = @{
  price = [math]::Round($estETH, 2)
  change_pct = [math]::Round($btcChg * 0.95 * 100, 2)
  timestamp = "2026-06-03 03:11:32"
  raw = "estimated_from_BTC_correlation"
  confidence = "medium"
  source = "estimated_BTC_ETH_correlation_0.95"
}
$latest | ConvertTo-Json -Depth 5 | Set-Content "data\market\prices_latest.json"
Write-Host "ETH 已修补写入 prices_latest.json"
