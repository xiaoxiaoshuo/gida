# ============================================================
# gh-trending-browser-v5.ps1 - GitHub Trending 采集脚本 v5
# 使用 Playwright MCP 浏览器采集真实的 GitHub Trending 页面
#
# 升级说明 (2026-04-28):
#   - v4 使用 GitHub API 搜索，无法获取真实的 stars_today
#   - v5 使用 Playwright 浏览器直接访问 github.com/trending
#   - 采集字段: repo名、star数、今日新增star、语言、描述
#
# 使用方式:
#   1. 手动采集: 运行脚本后使用 browser tool 执行 JS 提取
#   2. 自动模式: dot-source the script then call Invoke-GhTrendingV5
#   3. 由 daily-collector.ps1 调用 (传入 -BrowserResult)
#
# 数据输出:
#   - data/github-trending-history.json (追加历史记录)
#   - data/ai/github-trending_latest.md (Markdown报告)
# ============================================================

param(
    [string]$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid",
    [string]$HistoryFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\github-trending-history.json",
    [string]$LatestMdFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\github-trending_latest.md",
    [string]$TempFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\github-trending-temp.json",
    [string]$BrowserResult,
    [switch]$NoPush
)

$ErrorActionPreference = "Continue"
$DateStr = Get-Date -Format "yyyy-MM-dd"
$DateTimeStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$LogFile = "$RepoRoot\memory\$DateStr.md"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$Level] $(Get-Date -Format 'HH:mm:ss') - $Message"
    Write-Host $entry
    Add-Content -Path $LogFile -Value "  - $entry" -Encoding UTF8 -ErrorAction SilentlyContinue
}

# ============================================================
# 推荐的 JS 提取脚本 (用于 browser evaluate)
# ============================================================
$ExtractScript = @'
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
      if (/^(Shell|Python|TypeScript|JavaScript|Go|Rust|C\+\+|C|Clojure|HTML|CSS|Jupyter Notebook|Kotlin|Ruby|Java|Perl|PHP|Scala|Swift|Objective-C|Vue|React|Angular|Lua|R|MATLAB|XML|JSON|YAML|TOML|SQL|GraphQL|Markdown|LaTeX|Dockerfile|Makefile|Vim script)$/i.test(txt)) {
        language = txt;
        break;
      }
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

# ============================================================
# 步骤 1: 打印 browser tool 操作指南
# ============================================================
function Invoke-BrowserCollectionGuide {
    Write-Log "========== GitHub Trending 采集 v5 (Browser) =========="
    Write-Log "日期: $DateStr"
    Write-Log ""
    Write-Log "请在 browser tool 中执行以下操作:"
    Write-Log ""
    Write-Log "  Step 1: browser action=open url=https://github.com/trending"
    Write-Log "  Step 2: 等待页面加载完成 (3-5秒)"
    Write-Log "  Step 3: browser action=act kind=evaluate fn=<提取脚本> targetId=<your-target-id>"
    Write-Log ""
    Write-Log "提取脚本 (evaluate fn 参数):"
    Write-Log "---"
    Write-Log $ExtractScript
    Write-Log "---"
    Write-Log ""
    Write-Log "将 evaluate 返回的 JSON 结果保存到: $TempFile"
    Write-Log "然后运行: dot-source this script and call Invoke-GhTrendingV5"
}

# ============================================================
# 步骤 2: 解析数据
# ============================================================
function Parse-ExtractedData {
    param([string]$JsonString)

    if (-not $JsonString) {
        if (Test-Path $TempFile) {
            $JsonString = Get-Content $TempFile -Raw -ErrorAction SilentlyContinue
        }
    }
    if (-not $JsonString) {
        Write-Log "没有数据可解析" "WARN"
        return $null
    }
    try {
        $repos = $JsonString | ConvertFrom-Json
        if ($repos.Count -eq 0) {
            Write-Log "提取到 0 个项目" "WARN"
            return $null
        }
        Write-Log "解析到 $($repos.Count) 个项目"
        return $repos
    } catch {
        Write-Log "JSON解析失败: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# ============================================================
# 步骤 3: 保存结果 (历史 + Markdown)
# ============================================================
function Save-Results {
    param([array]$Repos)
    Write-Log ">> 保存结果..."

    if ($Repos.Count -eq 0) {
        Write-Log "无数据可保存" "WARN"
        return $false
    }

    # --- AI 关键词分类 ---
    $aiKeywords = @("ai","llm","gpt","model","neural","machine learning","deep learning","agent","chatbot","nlp","rag","claude","openai","deepseek","gemini","mistral","llama","qwen","gemma","transformer","langchain","diffusion","vector","codex","coding agent","vibe coding","coding","code assistant","programming")
    $devKeywords = @("tool","cli","dev","code","ide","editor","debug","test","build","deploy","docker","kubernetes","git","api","sdk","framework","library")
    $dataKeywords = @("data","database","sql","storage","cache","search","analytics","etl","pipeline")

    foreach ($repo in $Repos) {
        $text = "$($repo.name) $($repo.description)".ToLower()
        $isAi = $false
        foreach ($kw in $aiKeywords) { if ($text.Contains($kw)) { $isAi = $true; break } }
        if ($isAi) {
            $repo | Add-Member -NotePropertyName "category" -NotePropertyValue "AI/ML" -Force -ErrorAction SilentlyContinue
        } else {
            $isDev = $false
            foreach ($kw in $devKeywords) { if ($text.Contains($kw)) { $isDev = $true; break } }
            if ($isDev) {
                $repo | Add-Member -NotePropertyName "category" -NotePropertyValue "开发工具" -Force -ErrorAction SilentlyContinue
            } else {
                $isData = $false
                foreach ($kw in $dataKeywords) { if ($text.Contains($kw)) { $isData = $true; break } }
                if ($isData) {
                    $repo | Add-Member -NotePropertyName "category" -NotePropertyValue "数据工具" -Force -ErrorAction SilentlyContinue
                } else {
                    $repo | Add-Member -NotePropertyName "category" -NotePropertyValue "其他" -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    # --- 更新历史记录 (重建 JSON 保持格式兼容) ---
    $rawHistory = $null
    if (Test-Path $HistoryFile) {
        try {
            $rawHistory = Get-Content $HistoryFile -Raw | ConvertFrom-Json
        } catch { $rawHistory = $null }
    }

    # 构建 history 数组（过滤掉无效的空条目）
    $historyList = @()
    if ($rawHistory -and $rawHistory.history) {
        foreach ($item in $rawHistory.history) {
            # 跳过无效条目（没有 date 或 repos 为空/空数组）
            if (-not $item.date) { continue }
            if ($item.repos -eq $null -or ($item.repos -is [System.Array] -and $item.repos.Count -eq 0)) { continue }
            $historyList += $item
        }
    }

    # 查找今日记录是否存在
    $todayExists = $false
    for ($i = 0; $i -lt $historyList.Count; $i++) {
        if ($historyList[$i].date -eq $DateStr) {
            $historyList[$i].timestamp = $DateTimeStr
            $historyList[$i].repos = @($Repos)
            $todayExists = $true
            break
        }
    }
    if (-not $todayExists) {
        $historyList += @{
            date = $DateStr
            timestamp = $DateTimeStr
            repos = @($Repos)
        }
    }

    $outputObj = @{
        last_updated = $DateTimeStr
        days_collected = $historyList.Count
        history = $historyList
    }
    $outputObj | ConvertTo-Json -Depth 6 | Out-File -FilePath $HistoryFile -Encoding UTF8
    Write-Log "历史记录已保存 (共 $($historyList.Count) 条有效记录) -> $HistoryFile"

    # --- 生成 Markdown ---
    $catIcons = @{ "AI/ML" = "🤖"; "开发工具" = "🔧"; "数据工具" = "💾"; "其他" = "📊" }
    $catOrder = @("AI/ML", "开发工具", "数据工具", "其他")

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# GitHub Trending 热榜 | $DateStr")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("**采集时间**: $DateTimeStr GMT+8")
    [void]$sb.AppendLine("**数据源**: github.com/trending (Playwright 浏览器采集)")
    [void]$sb.AppendLine("**项目数量**: $($Repos.Count)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")

    foreach ($cat in $catOrder) {
        $catRepos = $Repos | Where-Object { $_.category -eq $cat }
        if ($catRepos.Count -gt 0) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("## $($catIcons[$cat]) $cat (共$($catRepos.Count)个)")
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("| 项目 | ★ | 今日↑ | 语言 | 描述 |")
            [void]$sb.AppendLine("|------|---|------|------|------|")
            foreach ($r in $catRepos) {
                $desc = if ($r.description) { $r.description -replace '\|','\\|' -replace '[\r\n]+',' ' } else { "" }
                $lang = if ($r.language) { $r.language } else { "-" }
                $starsToday = if ($r.stars_today -and $r.stars_today -ne 0) { "+$($r.stars_today)" } else { "-" }
                [void]$sb.AppendLine("| **$($r.name)** | $($r.stars) | $starsToday | $lang | $desc |")
            }
        }
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("*来源: github.com/trending 自动采集 (v5 - Playwright浏览器模式) | $DateTimeStr*")

    $mdContent = $sb.ToString()
    $mdContent | Out-File -FilePath $LatestMdFile -Encoding UTF8
    Write-Log "Markdown报告已保存 -> $LatestMdFile"

    # --- Git push ---
    if (-not $NoPush) {
        Set-Location $RepoRoot
        $status = git status --short 2>&1
        if ($status -and -not [string]::IsNullOrWhiteSpace($status)) {
            Write-Log "变更: $($status -join '; ')"
            git add -A 2>&1 | Out-Null
            $commitMsg = "chore: GitHub Trending $DateStr ($($Repos.Count) 项目)"
            git commit -m $commitMsg 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                git push origin main 2>&1 | Out-Null
                Write-Log "推送完成"
            }
        }
    }

    return $true
}

# ============================================================
# 自动流程入口 (主agent 调用)
# ============================================================
function Invoke-GhTrendingV5 {
    param(
        [string]$JsonContent,
        [switch]$NoPush
    )

    Write-Log "========== GitHub Trending 采集 v5 (Auto Mode) =========="
    Write-Log "日期: $DateStr"

    $repos = Parse-ExtractedData -JsonString $JsonContent
    if ($repos) {
        $ok = Save-Results -Repos $repos
        if ($ok) {
            Write-Log "========== 采集完成 =========="
            Write-Log "项目总数: $($repos.Count)"
        }
    } else {
        Write-Log "无法获取数据，尝试 browser 采集指南..." "WARN"
        Invoke-BrowserCollectionGuide
    }

    return @{
        success = ($repos -ne $null)
        date = $DateStr
        count = if ($repos) { $repos.Count } else { 0 }
    }
}

# ============================================================
# 主入口 (不带参数时输出指南)
# ============================================================
if ($MyInvocation.InvocationName -ne '.') {
    if ($BrowserResult) {
        Invoke-GhTrendingV5 -JsonContent $BrowserResult -NoPush:$NoPush
    } else {
        Invoke-BrowserCollectionGuide
    }
}
