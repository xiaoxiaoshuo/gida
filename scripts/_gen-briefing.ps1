$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid"
Set-Location $RepoRoot

$today = Get-Date -Format "yyyy-MM-dd"
$hnLatest = Get-Content "data\ai\hacker-news_latest.json" -Raw | ConvertFrom-Json
$techLatest = Get-Content "data\tech\tech-news_latest.json" -Raw | ConvertFrom-Json
$pricesFile = Get-ChildItem "data\market\prices_2026-06-02_*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$prices = Get-Content $pricesFile.FullName -Raw | ConvertFrom-Json
$fg = Get-Content "data\market\fear-greed_latest.json" -Raw | ConvertFrom-Json
$ghFile = Get-ChildItem "data\github-trending-2026-06-02*.json" -ErrorAction SilentlyContinue | Select-Object -First 1
$aiNews = Get-Content "data\ai\ai-news_latest.json" -Raw | ConvertFrom-Json

# Crypto 24h 与上周对比（5/9 基准）
$btc_now = [math]::Round($prices.crypto.BTC.price, 0)
$eth_now = [math]::Round($prices.crypto.ETH.price, 0)
$sol_now = [math]::Round($prices.crypto.SOL.price, 0)
$btc_old = 80300; $eth_old = 2315; $sol_old = 92.5
$btc_chg = [math]::Round(($btc_now - $btc_old) / $btc_old * 100, 1)
$eth_chg = [math]::Round(($eth_now - $eth_old) / $eth_old * 100, 1)
$sol_chg = [math]::Round(($sol_now - $sol_old) / $sol_old * 100, 1)

# 选取 top 5 HN（按 score）
$hnTop = $hnLatest.top_stories | Sort-Object { [int]$_.score } -Descending | Select-Object -First 5

# GitHub Trending 摘要
$ghRaw = Get-Content "data\github-trending-temp.json" -Raw
$ghRepos = $ghRaw | ConvertFrom-Json
$ghTop = $ghRepos | Sort-Object { [int]$_.stars_today } -Descending | Select-Object -First 5

# Tech news top 5
$techTop = $techLatest.items | Select-Object -First 5

# 输出 BLUF + 摘要文本
$output = @"
=== 系统状态 ===
TODAY: $today
TIMESTAMP: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

=== 价格（实时） ===
BTC: `$$btc_now  (vs 5/9: `$$btc_old → $btc_chg%)
ETH: `$$eth_now  (vs 5/9: `$$eth_old → $eth_chg%)
SOL: `$$sol_now  (vs 5/9: `$$sol_old → $sol_chg%)
GOLD: `$$($prices.macro.GOLD.value)/oz
OIL: `$$($prices.macro.OIL.value)/bbl
VIX: $($prices.macro.VIX.value)
F&G: $($fg.value) ($($fg.value_classification)) — 数据5/9

=== HN Top 5（按 score） ===
"@
$i = 1
foreach ($s in $hnTop) {
    $output += "`n$([int]$s.score) pts | $($s.title)"
    $i++
}
$output += "`n`n=== GitHub Trending Top 5（按 stars_today） ==="
$i = 1
foreach ($r in $ghTop) {
    $output += "`n$($r.name) | ★$($r.stars) (today +$($r.stars_today)) | $($r.language)"
}
$output += "`n`n=== Tech News Top 5 ==="
$i = 1
foreach ($t in $techTop) {
    $output += "`n$($t.title) ($($t.time))"
}
$output += "`n"
Write-Host $output
$output | Out-File -FilePath "$RepoRoot\memory\_briefing_$today.txt" -Encoding UTF8
Write-Host "`n[OK] Saved to memory\_briefing_$today.txt"
