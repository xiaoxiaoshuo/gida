# collect-tech-news.ps1 - TechCrunch AI新闻采集
# 工作目录: C:\Users\Administrator\clawd\agents\workspace-gid
param(
    [string]$OutputDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data\tech"
)

$ErrorActionPreference = "SilentlyContinue"
$WorkDir = "C:\Users\Administrator\clawd\agents\workspace-gid"

# 采集TechCrunch AI新闻（通过浏览器）
$BrowserScript = @"
const items = [];
document.querySelectorAll('h3 a').forEach(link => {
  const title = link.textContent.trim();
  const url = link.href;
  const timeEl = link.closest('li')?.querySelector('time');
  const time = timeEl ? timeEl.textContent : '';
  if (title && url && url.includes('techcrunch.com')) {
    items.push({ title, url, time });
  }
});
JSON.stringify(items.slice(0, 20));
"@

# 输出文件
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$OutputFile = Join-Path $OutputDir "tech-news_latest.json"
$BackupFile = Join-Path $OutputDir "tech-news_$(Get-Date -Format 'yyyy-MM-dd')_$Timestamp.json"

# 检查是否有Playwright可用
$HasPlaywright = Get-Command npx -ErrorAction SilentlyContinue

if ($HasPlaywright) {
    Write-Host "[INFO] 使用Playwright采集TechCrunch..."
    try {
        $result = npx playwright evaluate --url "https://techcrunch.com/category/artificial-intelligence/" 2>&1
        if ($result) {
            $newsData = $result | ConvertFrom-Json
            $output = @{
                timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                source = "TechCrunch AI"
                count = $newsData.Count
                items = $newsData
            }
            $output | ConvertTo-Json -Depth 5 | Out-File $OutputFile -Encoding UTF8
            Copy-Item $OutputFile $BackupFile -Force
            Write-Host "[OK] 采集完成，共 $($newsData.Count) 条新闻"
            exit 0
        }
    } catch {
        Write-Host "[WARN] Playwright采集失败: $_"
    }
}

# 备用：使用Invoke-WebRequest（可能失败）
Write-Host "[INFO] 尝试直接HTTP采集..."
try {
    # 尝试RSS feed
    $rss = Invoke-RestMethod "https://techcrunch.com/category/artificial-intelligence/feed/" -TimeoutSec 15
    if ($rss -and $rss.Count -gt 0) {
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
        $output | ConvertTo-Json -Depth 5 | Out-File $OutputFile -Encoding UTF8
        Copy-Item $OutputFile $BackupFile -Force
        Write-Host "[OK] RSS采集完成，共 $($items.Count) 条"
        exit 0
    }
} catch {
    Write-Host "[WARN] RSS失败: $_"
}

Write-Host "[ERROR] 所有采集方式均失败"
exit 1