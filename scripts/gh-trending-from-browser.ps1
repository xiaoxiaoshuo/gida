# gh-trending-from-browser.ps1 - 从浏览器采集数据生成GitHub Trending JSON
$ErrorActionPreference = "Continue"
$WorkDir = "C:\Users\Administrator\clawd\agents\workspace-gid"
$OutputDir = "$WorkDir\data\tech"
$DateStr = Get-Date -Format "yyyy-MM-dd"
$DateTimeStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# 从浏览器采集到的 GitHub Trending 数据（今日）
$projects = @(
    @{
        name = "Fincept-Corporation/FinceptTerminal"
        stars = 11389
        description = "FinceptTerminal is a modern finance application offering advanced market analytics, investment research, and economic data tools, designed for interactive exploration and data-driven decision-making in a user-friendly environment."
        url = "https://github.com/Fincept-Corporation/FinceptTerminal"
        language = "Python"
        starsToday = 2595
    },
    @{
        name = "thunderbird/thunderbolt"
        stars = 3392
        description = "AI You Control: Choose your models. Own your data. Eliminate vendor lock-in."
        url = "https://github.com/thunderbird/thunderbolt"
        language = "TypeScript"
        starsToday = 591
    },
    @{
        name = "zilliztech/claude-context"
        stars = 6488
        description = "Code search MCP for Claude Code. Make entire codebase the context for any coding agent."
        url = "https://github.com/zilliztech/claude-context"
        language = "TypeScript"
        starsToday = 259
    },
    @{
        name = "ruvnet/RuView"
        stars = 48811
        description = "π RuView: WiFi DensePose turns commodity WiFi signals into real-time human pose estimation, vital sign monitoring, and presence detection — all without a single pixel of video."
        url = "https://github.com/ruvnet/RuView"
        language = "Rust"
        starsToday = 828
    },
    @{
        name = "microsoft/ai-agents-for-beginners"
        stars = 57543
        description = "12 Lessons to Get Started Building AI Agents"
        url = "https://github.com/microsoft/ai-agents-for-beginners"
        language = "Jupyter Notebook"
        starsToday = 131
    },
    @{
        name = "dayanch96/YTLite"
        stars = 4789
        description = "A flexible enhancer for YouTube on iOS"
        url = "https://github.com/dayanch96/YTLite"
        language = "Logos"
        starsToday = 43
    },
    @{
        name = "HKUDS/RAG-Anything"
        stars = 16760
        description = "RAG-Anything: All-in-One RAG Framework"
        url = "https://github.com/HKUDS/RAG-Anything"
        language = "Python"
        starsToday = 256
    },
    @{
        name = "sansan0/TrendRadar"
        stars = 53554
        description = "AI-driven public opinion & trend monitor with multi-platform aggregation, RSS, and smart alerts."
        url = "https://github.com/sansan0/TrendRadar"
        language = "Python"
        starsToday = 584
    }
)

# 计算价值分和分类
function Get-ValueScore($Stars, $Description) {
    $score = [Math]::Round($Stars * 1.0)
    $aiKeywords = @("ai","llm","gpt","model","neural","machine learning","deep learning","agent","chatbot","nlp","rag","claude","openai")
    $descLower = $Description.ToLower()
    foreach ($kw in $aiKeywords) {
        if ($descLower.Contains($kw)) {
            $score = [Math]::Round($Stars * 1.3)
            break
        }
    }
    return $score
}

function Get-ProjectCategory($Name, $Description, $Language) {
    $aiKeywords = @("ai","llm","gpt","model","neural","machine learning","deep learning","agent","chatbot","nlp","autogpt","claude","openai","rag")
    $devKeywords = @("tool","cli","dev","code","ide","editor","debug","test","build","deploy","docker","kubernetes","git","api")
    $dataKeywords = @("data","database","sql","storage","cache","search","analytics")
    $text = "$Name $Description".ToLower()
    foreach ($kw in $aiKeywords) { if ($text.Contains($kw)) { return "AI/ML" } }
    foreach ($kw in $devKeywords) { if ($text.Contains($kw)) { return "开发工具" } }
    foreach ($kw in $dataKeywords) { if ($text.Contains($kw)) { return "数据工具" } }
    return "其他"
}

$enrichedProjects = @()
foreach ($p in $projects) {
    $enrichedProjects += @{
        name = $p.name
        stars = $p.stars
        description = $p.description
        url = $p.url
        language = $p.language
        category = Get-ProjectCategory -Name $p.name -Description $p.description -Language $p.language
        valueScore = Get-ValueScore -Stars $p.stars -Description $p.description
        starsToday = $p.starsToday
    }
}

$enrichedProjects = $enrichedProjects | Sort-Object -Property valueScore -Descending

# 生成Markdown
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# GitHub Trending 热榜 | $DateStr")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**数据源**: GitHub Trending 页面（浏览器采集）")
[void]$sb.AppendLine("**采集时间**: $DateTimeStr GMT+8")
[void]$sb.AppendLine("**项目数量**: $($enrichedProjects.Count)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

$categories = @("AI/ML","开发工具","数据工具","其他")
foreach ($cat in $categories) {
    $catProjects = $enrichedProjects | Where-Object { $_.category -eq $cat }
    if ($catProjects.Count -gt 0) {
        $catIcon = if ($cat -eq "AI/ML") { "🔴" } elseif ($cat -eq "开发工具") { "🔧" } elseif ($cat -eq "数据工具") { "📊" } else { "📁" }
        [void]$sb.AppendLine("## $catIcon $cat")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| 项目 | Stars | 今日↑ | 价值分 | 语言 | 描述 |")
        [void]$sb.AppendLine("|------|-------|------|--------|------|------|")
        foreach ($p in $catProjects) {
            $desc = if ($p.description) { $p.description -replace '\|', '\\|' -replace '\n', ' ' } else { "" }
            [void]$sb.AppendLine("| **$($p.name)** | $($p.stars) | +$($p.starsToday) | $($p.valueScore) | $($p.language) | $desc |")
        }
        [void]$sb.AppendLine("")
    }
}

[void]$sb.AppendLine("---")
[void]$sb.AppendLine("*来源: GitHub Trending 页面 自动采集 | 2026-04-22*")

$report = $sb.ToString()

# 保存文件
$jsonPath = "$OutputDir\github-trending-2026-04-22.json"
$enrichedProjects | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonPath -Encoding UTF8

$mdPath = "$OutputDir\github-trending-2026-04-22.md"
$report | Out-File -FilePath $mdPath -Encoding UTF8

$latestJsonPath = "$OutputDir\github-trending_latest.json"
$enrichedProjects | ConvertTo-Json -Depth 5 | Out-File -FilePath $latestJsonPath -Encoding UTF8

$latestMdPath = "$OutputDir\github-trending_latest.md"
$report | Out-File -FilePath $latestMdPath -Encoding UTF8

Write-Host "[OK] GitHub Trending 采集完成"
Write-Host "[OK] JSON: $jsonPath ($($enrichedProjects.Count) 个项目)"
Write-Host "[OK] Markdown: $mdPath"

# 推送
Set-Location $WorkDir
git add data/tech/github-trending-2026-04-22.json data/tech/github-trending-2026-04-22.md data/tech/github-trending_latest.json data/tech/github-trending_latest.md
git commit -m "chore: GitHub Trending 2026-04-22 ($($enrichedProjects.Count) 项目)"
git push 2>&1 | Select-Object -First 5