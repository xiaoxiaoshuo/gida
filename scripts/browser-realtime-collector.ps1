# browser-realtime-collector.ps1
# 用 Playwright 浏览器实时采集 BTC/ETH/SOL 价格 + Fear&Greed + GitHub Trending
# 2026-03-26

$ErrorActionPreference = 'SilentlyContinue'

$results = @{
    timestamp_iso = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    crypto = @{}
    fear_greed = $null
    github_trending = @()
    errors = @()
}

# 1. BTC/ETH/SOL 实时价格 (via OKX)
try {
    $btc = Invoke-RestMethod 'https://www.okx.com/api/v5/market/ticker?instId=BTC-USDT' -TimeoutSec 5
    $eth = Invoke-RestMethod 'https://www.okx.com/api/v5/market/ticker?instId=ETH-USDT' -TimeoutSec 5
    $sol = Invoke-RestMethod 'https://www.okx.com/api/v5/market/ticker?instId=SOL-USDT' -TimeoutSec 5
    
    $results.crypto = @{
        BTC = @{ price = [double]$btc.data[0].last; source = "OKX_API" }
        ETH = @{ price = [double]$eth.data[0].last; source = "OKX_API" }
        SOL = @{ price = [double]$sol.data[0].last; source = "OKX_API" }
    }
} catch {
    $results.errors += "OKX_API: $($_.Exception.Message)"
}

# 2. Fear&Greed Index (via web_fetch fallback)
try {
    $fg = Invoke-RestMethod 'https://alternative.me/api/fng/' -TimeoutSec 5
    if ($fg) {
        $results.fear_greed = @{
            value = [int]$fg.data[0].value
            classification = $fg.data[0].value_classification
            source = "alternative.me"
        }
    }
} catch {
    $results.errors += "Fear&Greed: $($_.Exception.Message)"
}

# 3. GitHub Trending (via GitHub API - 不需要认证)
try {
    $gh = Invoke-RestMethod 'https://api.github.com/search/repositories?q=stars:>10000+pushed:>2026-03-25&sort=stars&order=desc&per_page=10' -TimeoutSec 10
    if ($gh.items) {
        $results.github_trending = $gh.items | Select-Object -First 10 | ForEach-Object {
            @{
                name = $_.full_name
                stars = $_.stargazers_count
                language = $_.language
                description = $_.description
            }
        }
    }
} catch {
    $results.errors += "GitHub_API: $($_.Exception.Message)"
}

# 4. 黄金/原油 (via Playwright web_fetch - 待实现)
# 暂用本地缓存数据作为 fallback

# 输出
$json = $results | ConvertTo-Json -Depth 5
$outFile = "data/market/realtime_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').json"
$json | Set-Content $outFile -Encoding UTF8

# 更新 latest
$results | ConvertTo-Json -Depth 5 | Set-Content "data/market/realtime_latest.json" -Encoding UTF8

Write-Host "[browser-realtime-collector] 完成 $(Get-Date -Format 'HH:mm')"
Write-Host "BTC: $($results.crypto.BTC.price) | F&G: $($results.fear_greed.value) | Errors: $($results.errors.Count)"
