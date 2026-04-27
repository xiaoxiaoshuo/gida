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
#   1. 手动运行: .\scripts\gh-trending-browser-v5.ps1
#   2. 定时任务由 daily-collector.ps1 调用
#
# 数据输出:
#   - data/github-trending-history.json (追加历史记录)
#   - data/ai/github-trending_latest.md (Markdown报告)
# ============================================================

param(
    [string]$RepoRoot = "C:\Users\Administrator\clawd\agents\workspace-gid",
    [string]$HistoryFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\github-trending-history.json",
    [string]$LatestMdFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\github-trending_latest.md",
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
# Step 1: 使用 browser tool 打开 GitHub Trending 页面
# ============================================================
function Invoke-BrowserCollection {
    Write-Log ">> [1/3] 启动 Playwright 浏览器采集 GitHub Trending..."

    # 构造 JS 提取脚本
    $extractScript = @'
() => {
    const repos = [];
    const articles = document.querySelectorAll('article.Box-row');
    articles.forEach((article, idx) => {
        // repo 名: h2 a (e.g. "facebook / react")
        const linkEl = article.querySelector('h2 a');
        const name = linkEl ? linkEl.textContent.trim().replace(/\s+/g, ' ') : '';

        // stars 总数: 包含 "Stars" 的 span
        const starsText = article.innerText;
        let stars = 0;
        let starsToday = 0;

        // 匹配 "XX,XXX stars" 或 "XXX stars"
        const starsMatch = starsText.match(/([\d,]+)\s+star/i);
        if (starsMatch) {
            stars = parseInt(starsMatch[1].replace(/,/g, ''), 10);
        }

        // 匹配 "今日新增" 格式: "X,XXX stars today" or "XXX stars today"
        const todayMatch = starsText.match(/([\d,]+)\s+star\s+today/i);
        if (todayMatch) {
            starsToday = parseInt(todayMatch[1].replace(/,/g, ''), 10);
        }

        // 语言: .d-inline-block .text-bold
        const langEl = article.querySelector('.d-inline-block .text-bold');
        const language = langEl ? langEl.textContent.trim() : '';

        // 描述: p.text-normal
        const descEl = article.querySelector('p.text-normal');
        const description = descEl ? descEl.textContent.trim() : '';

        if (name) {
            repos.push({
                name: name,
                stars: stars,
                stars_today: starsToday,
                language: language,
                description: description
            });
        }
    });
    return JSON.stringify(repos);
}
'@

    Write-Log "请在 browser tool 中执行以下操作:"
    Write-Log "  1. browser action=open url=`"https://github.com/trending`""
    Write-Log "  2. 等待页面加载完成 (等待3-5秒)"
    Write-Log "  3. browser action=snapshot 获取页面结构确认"
    Write-Log "  4. browser action=act kind=evaluate fn=`"$($extractScript -replace '`n','' -replace '`r','')`""
    Write-Log ""
    Write-Log "或者通过以下命令直接提取数据 (使用 evaluate):"
    Write-Log "  browser action=act kind=evaluate fn=`"<提取脚本>`" targetUrl=`"https://github.com/trending`""
    Write-Log ""
    Write-Log "将 evaluate 返回的 JSON 结果保存到临时文件后，运行本脚本处理:"

    return $null
}

# ============================================================
# Step 2: 从临时文件解析数据
# ============================================================
function Parse-ExtractedData {
    param([string]$TempFile)
    Write-Log ">> [2/3] 解析提取的数据..."

    if (-not (Test-Path $TempFile)) {
        Write-Log "临时文件不存在: $TempFile" "ERROR"
        return $null
    }

    $content = Get-Content $TempFile -Raw -ErrorAction SilentlyContinue
    if (-not $content) {
        Write-Log "临时文件为空" "ERROR"
        return $null
    }

    try {
        $repos = $content | ConvertFrom-Json
        if ($repos.Count -eq 0) {
            Write-Log "未提取到任何项目" "WARN"
            return $null
        }
        Write-Log "提取到 $($repos.Count) 个项目"
        return $repos
    } catch {
        Write-Log "JSON解析失败: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# ============================================================
# Step 3: 生成报告并保存
# ============================================================
function Save-Results {
    param(
        [array]$Repos,
        [string]$DateStr,
        [string]$DateTimeStr
    )

    Write-Log ">> [3/3] 生成报告并保存..."

    if ($Repos.Count -eq 0) {
        Write-Log "没有数据可保存" "WARN"
        return $false
    }

    # --- 更新 github-trending-history.json ---
    $history = [System.Collections.ArrayList]::new()
    if (Test-Path $script:HistoryFile) {
        try {
            $history = Get-Content $script:HistoryFile -Raw | ConvertFrom-Json
            if ($history -is [Array]) {
                $history = [System.Collections.ArrayList]::new(,$history)
            } else {
                $history = [System.Collections.ArrayList]::new(@($history))
            }
        } catch {
            $history = [System.Collections.ArrayList]::new()
        }
    }

    # 查找今日记录是否存在
    $todayExists = $false
    for ($i = 0; $i -lt $history.Count; $i++) {
        if ($history[$i].date -eq $DateStr) {
            $history[$i].timestamp = $DateTimeStr
            $history[$i].data = @($Repos)
            $todayExists = $true
            break
        }
    }
    if (-not $todayExists) {
        $history.Add(@{
            date = $DateStr
            timestamp = $DateTimeStr
            data = @($Repos)
        }) | Out-Null
    }

    $history | ConvertTo-Json -Depth 6 | Out-File -FilePath $script:HistoryFile -Encoding UTF8
    Write-Log "历史记录已保存 (共 $($history.Count) 条, 今天: $($Repos.Count) 个项目)"

    # --- 生成 Markdown 报告 ---
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# GitHub Trending 热榜 | $DateStr")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("**采集时间**: $DateTimeStr GMT+8")
    [void]$sb.AppendLine("**数据源**: github.com/trending (Playwright 浏览器采集)")
    [void]$sb.AppendLine("**项目数量**: $($Repos.Count)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")

    # 分类图标
    $catIcons = @{
        "AI/ML" = "🤖"
        "开发工具" = "🔧"
        "数据工具" = "💾"
        "其他" = "📊"
    }

    # AI关键词
    $aiKeywords = @("ai","llm","gpt","model","neural","machine learning","deep learning","agent","chatbot","nlp","rag","claude","openai","deepseek","gemini","mistral","llama","qwen","gemma","transformer","langchain","diffusion","vector")

    foreach ($repo in $Repos) {
        $repo | Add-Member -NotePropertyName "category" -NotePropertyValue "其他" -Force -ErrorAction SilentlyContinue
    }

    $catOrder = @("AI/ML", "开发工具", "数据工具", "其他")
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
    $mdContent | Out-File -FilePath $script:LatestMdFile -Encoding UTF8
    Write-Log "Markdown报告已保存: $script:LatestMdFile"

    return $true
}

# ============================================================
# 自动流程 (被 daily-collector.ps1 调用)
# 假设 browser tool 已经将结果写入临时文件
# ============================================================
function Invoke-AutoCollection {
    Write-Log "========== GitHub Trending 采集 v5 (Browser) =========="
    Write-Log "日期: $DateStr"

    $tempFile = Join-Path $RepoRoot "data\github-trending-temp.json"

    # 检查是否有手动采集的数据
    if (Test-Path $tempFile) {
        $repos = Parse-ExtractedData -TempFile $tempFile
        if ($repos) {
            Save-Results -Repos $repos -DateStr $DateStr -DateTimeStr $DateTimeStr
        }
    } else {
        Write-Log "未找到临时数据文件: $tempFile" "WARN"
        Write-Log "请先使用 browser tool 采集数据并保存到该文件"
        Invoke-BrowserCollection
    }

    Write-Log "========== GitHub Trending 采集完成 =========="
}

# ============================================================
# 主入口
# ============================================================
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-BrowserCollection
}
