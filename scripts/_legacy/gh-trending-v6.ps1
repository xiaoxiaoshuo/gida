# gh-trending-v6.ps1 - GitHub Trending 采集脚本 v6 (全自动)
# v5 升级 (2026-06-04): 修复 v5 断链问题 - 不再打印"请在 browser tool 执行",直接调用 Playwright PowerShell 模块
# 用法: powershell -File gh-trending-v6.ps1
#   自动流程: launch Chromium → navigate → evaluate → parse → save → close
#   输出: data/ai/github-trending-YYYY-MM-DD-HHMM.json

$ErrorActionPreference = "Stop"
$workspace = "C:\Users\Administrator\clawd\agents\workspace-gid"
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmm"
$outFile = "$workspace\data\ai\github-trending-$timestamp.json"

Write-Host "[INFO] $(Get-Date -Format 'HH:mm:ss') - gh-trending v6 启动"

# 检查 Playwright 模块
$playwrightModule = Get-Module -ListAvailable -Name Playwright | Select-Object -First 1
if (-not $playwrightModule) {
    Write-Host "[WARN] Playwright 模块未安装,尝试加载..." -ForegroundColor Yellow
    try {
        Import-Module Playwright -ErrorAction Stop
    } catch {
        Write-Host "[FAIL] Playwright 不可用,fallback 到 web_fetch" -ForegroundColor Red
        # Fallback: 用 web_fetch 抓 GitHub Trending (注意: GitHub 经常返回 200 但内容是 SPA 骨架)
        try {
            $html = (Invoke-WebRequest -Uri "https://github.com/trending" -UseBasicParsing -TimeoutSec 15).Content
            if ($html -match "article.Box-row" -or $html -match "Box-row") {
                Write-Host "[OK] web_fetch 拿到部分 HTML (需 JS 渲染)" -ForegroundColor Yellow
                # 解析 HTML 中已有的 repo 信息 (虽然不全)
                $repos = @()
                # 简单 regex 提取 repo 名 (匹配 /<user>/<repo> 模式)
                $matches = [regex]::Matches($html, '/([\w-]+/[\w.-]+)(?:"|\s)')
                $unique = $matches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique | Select-Object -First 25
                foreach ($name in $unique) {
                    $repos += @{ name = $name; source = "web_fetch_partial"; confidence = "C" }
                }
                $repos | ConvertTo-Json -Depth 3 | Out-File $outFile -Encoding UTF8
                Write-Host "[OK] Fallback 完成: $($repos.Count) repos (partial) → $outFile"
                exit 0
            }
        } catch {
            Write-Host "[FAIL] web_fetch 也失败: $_" -ForegroundColor Red
            exit 1
        }
    }
}

# ===== Playwright 路径 =====
try {
    Import-Module Playwright -ErrorAction Stop
} catch {
    Write-Host "[FAIL] Playwright 加载失败" -ForegroundColor Red
    exit 1
}

# 启动浏览器 + 导航 + evaluate
try {
    $browser = Start-Playwright -Chromium
    $context = $browser.NewContext()
    $page = $context.NewPage()
    
    Write-Host "[INFO] 导航 github.com/trending..."
    $page.Goto("https://github.com/trending", [Microsoft.Playwright.WaitUntilState]::NetworkIdle, 15000)
    
    Write-Host "[INFO] 执行 evaluate 提取..."
    $extractJs = @'
() => {
  const repos = [];
  const articles = document.querySelectorAll('article.Box-row');
  articles.forEach((article) => {
    const linkEl = article.querySelector('h2 a');
    const name = linkEl ? linkEl.textContent.trim().replace(/\s+/g, ' ') : '';
    const starLink = article.querySelector('a[href*="/stargazers"]');
    let stars = 0;
    if (starLink) {
      const match = starLink.textContent.match(/[\d,]+/);
      if (match) stars = parseInt(match[0].replace(/,/g, ''), 10);
    }
    let starsToday = 0;
    const walker = document.createTreeWalker(article, NodeFilter.SHOW_TEXT, null, false);
    const textNodes = [];
    while (walker.nextNode()) textNodes.push(walker.currentNode);
    const todayText = textNodes.map(n => n.textContent).join(' ').match(/([\d,]+)\s+stars?\s+today/i);
    if (todayText) starsToday = parseInt(todayText[1].replace(/,/g, ''), 10);
    let language = '';
    const allSpans = article.querySelectorAll('span');
    for (const s of allSpans) {
      const txt = s.textContent.trim();
      if (/^(Shell|Python|TypeScript|JavaScript|Go|Rust|C\+\+|C)$/i.test(txt)) { language = txt; break; }
    }
    let description = '';
    const ps = article.querySelectorAll('p');
    for (const p of ps) {
      const txt = p.textContent.trim();
      if (txt.length > 10) { description = txt; break; }
    }
    if (name) repos.push({ name, stars, stars_today: starsToday, language, description });
  });
  return JSON.stringify(repos);
}
'@
    $jsonResult = $page.Evaluate($extractJs)
    $repos = $jsonResult | ConvertFrom-Json
    
    # 增强字段
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    $enriched = @{
        collected_at = $timestamp
        source = "github.com/trending"
        total = $repos.Count
        repos = $repos
    }
    $enriched | ConvertTo-Json -Depth 5 | Out-File $outFile -Encoding UTF8
    
    Write-Host "[OK] $($repos.Count) repos 提取完成 → $outFile" -ForegroundColor Green
    
    $browser.Close()
} catch {
    Write-Host "[FAIL] Playwright 路径失败: $_" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] $(Get-Date -Format 'HH:mm:ss') - gh-trending v6 完成"
