# ============================================================
# gh-trending-v4.ps1 - GitHub Trending 采集脚本 v4
#
# 升级说明 (2026-04-27):
#   - v3使用Bing回退，数据不完整
#   - v4直接调用 browser tool 访问 GitHub API
#   - browser tool 是唯一能绕过 SSL/GFW 阻断的方式
#
# 使用方式:
#   1. 运行脚本，它会输出 browser tool 命令
#   2. 或者直接运行 Run-GhTrendingV4 函数（由主agent调用browser后）
# ============================================================

param(
    [string]$DataDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data",
    [string]$OutputDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data",
    [int]$PerPage = 30,
    [int]$MinStars = 1000
)

$ErrorActionPreference = "Continue"
$DateStr = Get-Date -Format "yyyy-MM-dd"
$DateTimeStr = Get-Date -Format "yyyy-MM-dd HH:mm"

if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $msg = "[$Level] $(Get-Date -Format 'HH:mm:ss') - $Message"
    Write-Host $msg
    Add-Content -Path "$DataDir\collect-tech.log" -Value $msg -ErrorAction SilentlyContinue
}

# ============================================================
# GitHub API URL 生成
# ============================================================
function Get-GithubApiUrl {
    $sinceDate = (Get-Date).AddDays(-30).ToString('yyyy-MM-dd')
    $url = "https://api.github.com/search/repositories?q=stars%3A%3E$MinStars+pushed%3A%3E$sinceDate&sort=stars&order=desc&per_page=$PerPage"
    return $url
}

# ============================================================
# 评分与分类
# ============================================================
$script:AI_KEYWORDS = @("ai","llm","gpt","model","neural","machine learning","deep learning","agent","chatbot","nlp","autogpt","claude","openai","gemini","deepseek","mcp","rag","vector","diffusion","transformer","langchain","llama","mistral","gemma","qwen")
$script:DEV_KEYWORDS = @("tool","cli","dev","code","ide","editor","debug","test","build","deploy","docker","kubernetes","git","api","sdk","framework","library")
$script:DATA_KEYWORDS = @("data","database","sql","storage","cache","search","analytics","etl","pipeline")

function Get-Score {
    param([int]$Stars, [string]$Description)
    $score = [Math]::Round($Stars * 1.0)
    $descLower = $Description.ToLower()
    foreach ($kw in $script:AI_KEYWORDS) {
        if ($descLower.Contains($kw)) { $score = [Math]::Round($Stars * 1.3); break }
    }
    return $score
}

function Get-Category {
    param([string]$Name, [string]$Description, [string]$Language)
    $text = "$Name $Description".ToLower()
    foreach ($kw in $script:AI_KEYWORDS) { if ($text.Contains($kw)) { return "AI/ML" } }
    foreach ($kw in $script:DEV_KEYWORDS) { if ($text.Contains($kw)) { return "开发工具" } }
    foreach ($kw in $script:DATA_KEYWORDS) { if ($text.Contains($kw)) { return "数据工具" } }
    return "其他"
}

# ============================================================
# 保存 GitHub API 原始响应
# ============================================================
function Save-ApiRawResponse {
    param([string]$JsonContent, [string]$DataDir)
    $tempFile = Join-Path $DataDir "github-api-temp.json"
    $JsonContent | Out-File -FilePath $tempFile -Encoding UTF8
    Write-Log "已保存原始响应到 $tempFile (长度: $($JsonContent.Length) 字符)"
    return $tempFile
}

# ============================================================
# 解析 GitHub API JSON 并处理
# ============================================================
function Parse-GithubApiResponse {
    param([string]$DataDir)

    $tempFile = Join-Path $DataDir "github-api-temp.json"

    if (-not (Test-Path $tempFile)) {
        Write-Log "找不到原始响应文件: $tempFile" "ERROR"
        return $null
    }

    $rawContent = Get-Content $tempFile -Raw -ErrorAction SilentlyContinue
    if (-not $rawContent) {
        Write-Log "原始响应文件为空" "ERROR"
        return $null
    }

    try {
        $data = $rawContent | ConvertFrom-Json
        $items = $data.items

        if (-not $items -or $items.Count -eq 0) {
            Write-Log "API返回空数据项" "ERROR"
            # 保存原始文本用于诊断
            $errFile = Join-Path $DataDir "github-raw-error.txt"
            $rawContent | Out-File -FilePath $errFile -Encoding UTF8
            Write-Log "原始内容已保存到 $errFile" "ERROR"
            return $null
        }

        Write-Log "API返回 $($items.Count) 个项目"

        $projects = @()
        foreach ($item in $items) {
            $desc = if ($item.description) { $item.description } else { "" }
            $lang = if ($item.language) { $item.language } else { "" }
            $projects += @{
                name = $item.full_name
                stars = $item.stargazers_count
                description = $desc
                url = $item.html_url
                language = $lang
                owner = $item.owner.login
                pushed = $item.pushed_at
                forks = $item.forks_count
                category = Get-Category $item.full_name $desc $lang
                valueScore = Get-Score $item.stargazers_count $desc
            }
        }

        # 去重 & 排序
        $seen = @{}
        $unique = @()
        foreach ($p in $projects) {
            if (-not $seen.ContainsKey($p.name)) {
                $seen[$p.name] = $true
                $unique += $p
            }
        }
        $unique = $unique | Sort-Object -Property valueScore -Descending | Select-Object -First 30

        Write-Log "去重后: $($unique.Count) 个项目"
        return $unique

    } catch {
        Write-Log "JSON解析失败: $($_.Exception.Message)" "ERROR"
        $errFile = Join-Path $DataDir "github-raw-error.txt"
        $rawContent | Out-File -FilePath $errFile -Encoding UTF8
        Write-Log "原始内容已保存到 $errFile" "ERROR"
        return $null
    }
}

# ============================================================
# 生成 Markdown 报告
# ============================================================
function New-MarkdownReport {
    param([array]$Projects)
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# GitHub Trending 热榜 | $DateStr")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("**采集时间**: $DateTimeStr GMT+8")
    [void]$sb.AppendLine("**数据源**: GitHub API (browser tool)")
    [void]$sb.AppendLine("**项目数量**: $($Projects.Count)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")

    $catIcons = @{ "AI/ML" = "🤖"; "开发工具" = "🔧"; "数据工具" = "💾"; "其他" = "📊" }
    $catOrder = @("AI/ML", "开发工具", "数据工具", "其他")

    foreach ($cat in $catOrder) {
        $items = $Projects | Where-Object { $_.category -eq $cat } | Sort-Object -Property valueScore -Descending
        if ($items.Count -gt 0) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("## $($catIcons[$cat]) $cat (共$($items.Count)个)")
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("| 项目 | ★ | 价值分 | 描述 |")
            [void]$sb.AppendLine("|------|---|--------|------|")
            foreach ($p in $items) {
                $desc = if ($p.description) { $p.description -replace '\|','\\|' -replace '[\r\n]+',' ' } else { "" }
                $lang = if ($p.language) { "[$($p.language)]" } else { "" }
                [void]$sb.AppendLine("| **$($p.name)** $lang | $($p.stars) | $($p.valueScore) | $desc |")
            }
        }
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("*来源: GitHub API 自动采集 (v4 - 浏览器模式)*")
    return $sb.ToString()
}

# ============================================================
# 完整流程 (由主agent在browser调用后执行)
# ============================================================
function Run-GhTrendingV4 {
    param(
        [string]$JsonContent,
        [string]$DataDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data",
        [string]$OutputDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data"
    )

    Write-Log "========== GitHub Trending 采集 v4 =========="
    Write-Log "日期: $DateStr"

    # Step 1: 保存原始响应
    $tempFile = Save-ApiRawResponse -JsonContent $JsonContent -DataDir $DataDir

    # Step 2: 解析JSON
    $projects = Parse-GithubApiResponse -DataDir $DataDir

    if ($projects -eq $null -or $projects.Count -eq 0) {
        Write-Log "解析失败，无法继续" "ERROR"
        return @{
            success = $false
            date = $DateStr
            count = 0
            projects = @()
        }
    }

    # Step 3: 保存JSON
    $dateFile = Join-Path $DataDir "github-trending-$DateStr.json"
    $latestFile = Join-Path $DataDir "github-trending_latest.json"
    $projects | ConvertTo-Json -Depth 5 | Out-File -FilePath $dateFile -Encoding UTF8
    $projects | ConvertTo-Json -Depth 5 | Out-File -FilePath $latestFile -Encoding UTF8
    Write-Log "JSON已保存: $dateFile"

    # Step 4: 生成Markdown
    $report = New-MarkdownReport -Projects $projects
    $mdFile = Join-Path $DataDir "github-trending-$DateStr.md"
    $latestMdFile = Join-Path $DataDir "github-trending_latest.md"
    $report | Out-File -FilePath $mdFile -Encoding UTF8
    $report | Out-File -FilePath $latestMdFile -Encoding UTF8
    Write-Log "Markdown已保存: $mdFile"

    Write-Log "========== 采集完成 =========="
    Write-Log "项目总数: $($projects.Count)"

    return @{
        success = $true
        date = $DateStr
        count = $projects.Count
        projects = $projects
        dataFile = $dateFile
        mdFile = $mdFile
        tempFile = $tempFile
    }
}

# ============================================================
# 主流程入口
# ============================================================
# 脚本不带参数运行时，输出API URL供browser工具使用
if ($MyInvocation.InvocationName -ne '.') {
    $apiUrl = Get-GithubApiUrl
    Write-Host ""
    Write-Host "============================================"
    Write-Host "GitHub Trending 采集 v4 - Browser Mode"
    Write-Host "============================================"
    Write-Host ""
    Write-Host "请使用 browser tool 打开以下URL:"
    Write-Host ""
    Write-Host "browser tool action=open profile=openclaw url=`"$apiUrl`""
    Write-Host ""
    Write-Host "获取页面内容后，提取 document.body.innerText"
    Write-Host "然后运行以下命令处理数据:"
    Write-Host ""
    Write-Host '$jsonContent = Get-Content "github-api-temp.json" -Raw'
    Write-Host '. "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\gh-trending-v4.ps1"'
    Write-Host 'Run-GhTrendingV4 -JsonContent $jsonContent'
    Write-Host ""
    Write-Host "或者由主agent调用 browser + evaluate 自动完成"
}
