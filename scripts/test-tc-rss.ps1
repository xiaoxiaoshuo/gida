$rss = Invoke-RestMethod 'https://techcrunch.com/category/artificial-intelligence/feed/' -TimeoutSec 15
if ($rss) {
    Write-Host "[OK] RSS获取成功，数量: $($rss.Count)"
    $rss | Select-Object -First 3 | ForEach-Object {
        Write-Host "Title: $($_.title)"
        Write-Host "Link: $($_.link)"
        Write-Host "---"
    }
    
    # 保存到文件
    $items = @()
    foreach ($item in $rss | Select-Object -First 20) {
        $items += @{
            title = $item.title
            url = $item.link
            time = $item.pubDate
        }
    }
    
    $output = @{
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        source = "TechCrunch RSS"
        count = $items.Count
        items = $items
    }
    
    $OutputFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\tech\tech-news_latest.json"
    $output | ConvertTo-Json -Depth 5 | Out-File $OutputFile -Encoding UTF8
    Write-Host "[OK] 已保存到 $OutputFile"
} else {
    Write-Host "[ERROR] RSS获取失败"
}