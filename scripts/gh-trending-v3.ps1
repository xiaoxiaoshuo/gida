# ============================================================
# gh-trending-v3.ps1 - GitHub Trending 采集脚本 v3
# 
# 关键发现 (2026-04-09):
#   - curl.exe / Invoke-WebRequest / PowerShell 无法访问 api.github.com (SSL/TLS握手失败)
#   - 但 Brave浏览器 (browser tool) 可以完美访问 api.github.com
#   - 解决方案: 浏览器是访问GitHub API的唯一可靠方式
#
# 使用方式:
#   1. 直接运行此脚本 (会用Bing/镜像策略，可能数据不完整)
#   2. 配合browser tool使用API采集 (推荐)
# ============================================================

param(
    [string]$DataDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data\ai",
    [string]$OutputDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data\ai",
    [switch]$UseBingFallback,
    [int]$PerPage = 30,
    [int]$MinStars = 1000
)

$ErrorActionPreference = "Continue"
$DateStr = Get-Date -Format "yyyy-MM-dd"
$DateTimeStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $msg = "[$Level] $(Get-Date -Format 'HH:mm:ss') - $Message"
    Write-Host $msg
    Add-Content -Path "$DataDir\collect-tech.log" -Value $msg -ErrorAction SilentlyContinue
}

# ============================================================
# 策略A: Bing搜索回退 (始终可用)
# ============================================================
function Get-GithubTrendingViaBing {
    Write-Log ">> 策略A: Bing搜索回退"
    
    $queries = @(
        "site:github.com trending 2026 stars",
        "GitHub popular repositories this week AI",
        "github.com trending Python JavaScript today"
    )
    
    $projects = @()
    $seen = @{}
    
    foreach ($q in $queries) {
        Write-Log "  搜索: $q"
        try {
            $encoded = [System.Web.HttpUtility]::UrlEncode($q)
            $url = "https://cn.bing.com/search?q=$encoded"
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15 -UserAgent "Mozilla/5.0"
            
            if ($response.StatusCode -eq 200) {
                $content = $response.Content
                $ghMatches = [regex]::Matches($content, 'github\.com/([\w\-\.]+/[\w\-\.]+)')
                
                foreach ($match in $ghMatches) {
                    $proj = $match.Groups[1].Value
                    if (-not $seen.ContainsKey($proj) -and $proj -notmatch "login|settings|orgs|topics|explore|trending") {
                        $seen[$proj] = $true
                        $projects += @{
                            name = $proj
                            stars = 0
                            description = ""
                            url = "https://github.com/$proj"
                            language = ""
                            pushed = ""
                            category = "其他"
                            valueScore = 0
                        }
                    }
                }
                Write-Log "  本次发现 $($ghMatches.Count) 个 (总计: $($projects.Count))"
            }
        } catch {
            Write-Log "  搜索失败: $($_.Exception.Message.Substring(0,60))" "WARN"
        }
        Start-Sleep -Seconds 3
    }
    
    return $projects
}

# ============================================================
# 策略B: GitHub API (通过浏览器 - 唯一可行方式)
# 重要: 需要配合 browser tool 使用
# ============================================================
function Get-BrowserApiUrl {
    # 返回需要用browser tool访问的URL
    $sinceDate = (Get-Date).AddDays(-30).ToString('yyyy-MM-dd')
    $url = "https://api.github.com/search/repositories?q=stars%3A%3E$($MinStars)+pushed%3A%3E$sinceDate&sort=stars&order=desc&per_page=$PerPage"
    return @{
        url = $url
        description = "用 browser tool 打开此URL，获取JSON响应后调用 Save-GithubData 保存"
    }
}

function Save-GithubData {
    # 从browser工具获取JSON后保存
    param([string]$JsonContent, [string]$DataDir)
    
    try {
        $data = $JsonContent | ConvertFrom-Json
        $items = $data.items
        
        $projects = @()
        foreach ($item in $items) {
            $desc = if ($item.description) { $item.description } else { "" }
            $projects += @{
                name = $item.full_name
                stars = $item.stargazers_count
                description = $desc
                url = $item.html_url
                language = if ($item.language) { $item.language } else { "" }
                owner = $item.owner.login
                pushed = $item.pushed_at
                forks = $item.forks_count
                category = Get-Category $item.full_name $desc ($item.language -as [string])
                valueScore = Get-Score $item.stargazers_count $desc
            }
        }
        
        # 去重
        $seen = @{}
        $unique = @()
        foreach ($p in $projects) {
            if (-not $seen.ContainsKey($p.name)) {
                $seen[$p.name] = $true
                $unique += $p
            }
        }
        
        # 排序
        $unique = $unique | Sort-Object -Property valueScore -Descending | Select-Object -First 30
        
        # 保存
        $dateFile = "$DataDir\github-trending-$DateStr.json"
        $latestFile = "$DataDir\github-trending_latest.json"
        $unique | ConvertTo-Json -Depth 5 | Out-File -FilePath $dateFile -Encoding UTF8
        $unique | ConvertTo-Json -Depth 5 | Out-File -FilePath $latestFile -Encoding UTF8
        
        Write-Log "已保存 $($unique.Count) 个项目到 $dateFile"
        return $unique
    } catch {
        Write-Log "保存失败: $($_.Exception.Message)" "ERROR"
        return @()
    }
}

# ============================================================
# 辅助函数
# ============================================================
function Get-Score {
    param([int]$Stars, [string]$Description)
    $score = [Math]::Round($Stars * 1.0)
    $aiKeywords = @("ai","llm","gpt","model","neural","machine learning","deep learning","agent","chatbot","nlp","autogpt","claude","openai","gemini","deepseek","mcp","rag","vector")
    $descLower = $Description.ToLower()
    foreach ($kw in $aiKeywords) {
        if ($descLower.Contains($kw)) { $score = [Math]::Round($Stars * 1.3); break }
    }
    return $score
}

function Get-Category {
    param([string]$Name, [string]$Description, [string]$Language)
    $aiKeywords = @("ai","llm","gpt","model","neural","machine learning","deep learning","agent","chatbot","nlp","autogpt","claude","openai","deepseek")
    $devKeywords = @("tool","cli","dev","code","ide","editor","debug","test","build","deploy","docker","kubernetes","git","api","sdk")
    $dataKeywords = @("data","database","sql","storage","cache","search","analytics")
    $text = "$Name $Description".ToLower()
    foreach ($kw in $aiKeywords) { if ($text.Contains($kw)) { return "AI/ML" } }
    foreach ($kw in $devKeywords) { if ($text.Contains($kw)) { return "开发工具" } }
    foreach ($kw in $dataKeywords) { if ($text.Contains($kw)) { return "数据工具" } }
    return "其他"
}

function New-MarkdownReport {
    param([array]$Projects)
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# GitHub Trending 热榜 | $DateStr")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("**采集时间**: $DateTimeStr GMT+8")
    [void]$sb.AppendLine("**数据源**: GitHub API (浏览器模式)")
    [void]$sb.AppendLine("**项目数量**: $($Projects.Count)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    
    $cats = @{
        "AI/ML" = ($Projects | Where-Object { $_.category -eq "AI/ML" } | Sort-Object -Property valueScore -Descending)
        "开发工具" = ($Projects | Where-Object { $_.category -eq "开发工具" } | Sort-Object -Property valueScore -Descending)
        "其他" = ($Projects | Where-Object { $_.category -notin @("AI/ML","开发工具") } | Sort-Object -Property valueScore -Descending)
    }
    
    $catNames = @("AI/ML", "开发工具", "其他")
    $catIcons = @{ "AI/ML" = "🔴"; "开发工具" = "🔧"; "其他" = "📊" }
    
    foreach ($cat in $catNames) {
        $items = $cats[$cat]
        if ($items.Count -gt 0) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("## $($catIcons[$cat]) $cat (共$($items.Count)个)")
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("| 项目 | ★ | 价值分 | 描述 |")
            [void]$sb.AppendLine("|------|---|--------|------|")
            foreach ($p in $items) {
                $desc = if ($p.description) { $p.description -replace '\|','\\|' -replace '\n',' ' } else { "" }
                [void]$sb.AppendLine("| **$($p.name)** | $($p.stars) | $($p.valueScore) | $desc |")
            }
        }
    }
    
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("*来源: GitHub API 自动采集 (v3 - 浏览器模式)*")
    return $sb.ToString()
}

# ============================================================
# 主流程
# ============================================================
Write-Log "========== GitHub Trending 采集 v3 =========="
Write-Log "日期: $DateStr"

# 如果没有JSON数据文件，使用Bing回退
$dataFile = "$DataDir\github-trending-$DateStr.json"
$latestFile = "$DataDir\github-trending_latest.json"

if ((Test-Path $latestFile) -and (Get-Content $latestFile -Raw | ConvertFrom-Json)) {
    Write-Log "发现已有数据: $latestFile"
    $projects = Get-Content $latestFile -Raw | ConvertFrom-Json | ForEach-Object { $_ }
    Write-Log "加载了 $($projects.Count) 个项目"
} else {
    Write-Log "使用Bing搜索回退..."
    $projects = Get-GithubTrendingViaBing
    Write-Log "Bing搜索到 $($projects.Count) 个项目"
    
    if ($projects.Count -gt 0) {
        # 保存
        $projects | ConvertTo-Json -Depth 5 | Out-File -FilePath $dataFile -Encoding UTF8
        $projects | ConvertTo-Json -Depth 5 | Out-File -FilePath $latestFile -Encoding UTF8
        Write-Log "已保存到 $dataFile"
    }
}

# 生成报告
if ($projects.Count -gt 0) {
    $report = New-MarkdownReport -Projects $projects
    $mdFile = "$DataDir\github-trending-$DateStr.md"
    $latestMdFile = "$DataDir\github-trending_latest.md"
    $report | Out-File -FilePath $mdFile -Encoding UTF8
    $report | Out-File -FilePath $latestMdFile -Encoding UTF8
    Write-Log "Markdown报告: $mdFile"
}

Write-Log "========== 采集完成 =========="
Write-Log "项目总数: $($projects.Count)"

# 输出API URL供参考
$apiInfo = Get-BrowserApiUrl
Write-Log "GitHub API URL (browser模式): $($apiInfo.url)"

return @{
    date = $DateStr
    count = $projects.Count
    projects = $projects
    apiUrl = $apiInfo.url
    dataFile = $dataFile
    mdFile = $mdFile
}
