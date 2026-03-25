# extract-prices.ps1 - 从Bing搜索结果提取价格
$headers = @{"User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
$queries = @{
    "BTC" = "Bitcoin price USD today 2026"
    "ETH" = "Ethereum price USD today 2026"
    "SOL" = "Solana price USD today 2026"
}

$result = @{}
foreach ($symbol in $queries.Keys) {
    Write-Host "Querying $symbol..."
    $encoded = [Uri]::EscapeDataString($queries[$symbol])
    $url = "https://cn.bing.com/search?q=$encoded"
    
    try {
        $r = Invoke-WebRequest -Uri $url -Headers $headers -TimeoutSec 15 -UseBasicParsing
        $content = $r.Content
        
        # 提取所有 $ 价格
        $prices = [regex]::Matches($content, '\$[\d,]+\.?\d*') | ForEach-Object { $_.Value } | Select-Object -First 5
        
        # 提取摘要文本
        $snippets = [regex]::Matches($content, 'b_lineclamp[^>]*>([^<]+)<') | ForEach-Object { $_.Groups[1].Value } | Select-Object -First 3
        
        Write-Host "  Prices found: $($prices -join ', ')"
        Write-Host "  Snippets: $($snippets -join ' | ')"
        
        $result[$symbol] = @{
            prices = $prices
            snippets = $snippets
            url = $url
        }
    } catch {
        Write-Host "  Error: $($_.Exception.Message)"
    }
}

# 保存结果
$outFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\market\bing_prices_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').txt"
$output = @"
=== Bing价格采集 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===
"@

foreach ($symbol in $result.Keys) {
    $output += @"

$symbol :
  Prices: $($result[$symbol].prices -join ', ')
  Snippets: $($result[$symbol].snippets -join ' | ')
"@
}

$output | Out-File -FilePath $outFile -Encoding UTF8
Write-Host "Saved to: $outFile"
