# ============================================================
# gh-trending-v2.ps1 - GitHub Trending 采集脚本 v2
# 用途: 采集 GitHub 热榜项目（解决 GFW 拦截问题）
# 策略: GitHub API优先 → 镜像站备选
# 频率: 每日执行
# ============================================================

param(
    [string]$OutputDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data\tech",
    [string]$GithubToken = $env:GITHUB_TOKEN,
    [switch]$Verbose,
    [int]$PerPage = 20,
    [int]$MaxStars = 100000
)

# ========== 基础配置 ==========
$ErrorActionPreference = "Continue"
$DateStr = Get-Date -Format "yyyy-MM-dd"
$DateTimeStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# 镜像列表（备用）
$MirrorList = @(
    "https://hub.fastgit.xyz",
    "https://ghproxy.com"
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $msg = "[$Level] $(Get-Date -Format 'HH:mm:ss') - $Message"
    Write-Host $msg
    Add-Content -Path "$OutputDir\collect-tech.log" -Value $msg -ErrorAction SilentlyContinue
}

# ========== GitHub API 采集 ==========
function Get-GithubTrendingViaApi {
    param([int]$DaysBack = 7, [int]$MinStars = 500)
    
    Write-Log ">> 策略1: 通过 GitHub API 采集..."
    
    $headers = @{
        "Accept" = "application/vnd.github.v3+json"
        "User-Agent" = "GitHub-Trending-Collector/2.0"
    }
    if ($GithubToken) {
        $headers["Authorization"] = "token $GithubToken"
        Write-Log "  使用 GitHub Token（提高速率限制）"
    }
    
    # 计算日期范围
    $sinceDate = (Get-Date).AddDays(-$DaysBack).ToString('yyyy-MM-dd')
    
    # 搜索查询: 近期活跃的高星项目
    $queries = @(
        "stars:>$MinStars created:>$sinceDate",
        "stars:>$($MinStars * 2) pushed:>$sinceDate"
    )
    
    $allProjects = @()
    
    foreach ($q in $queries) {
        Write-Log "  查询: $q"
        $url = "https://api.github.com/search/repositories?q=[System.Web.HttpUtility]::UrlEncode($q)&sort=stars&order=desc&per_page=$PerPage"
        $encodedQ = [System.Web.HttpUtility]::UrlEncode($q)
        $apiUrl = "https://api.github.com/search/repositories?q=$encodedQ&sort=stars&order=desc&per_page=$PerPage"
        
        try {
            $r = Invoke-WebRequest -Uri $apiUrl -Headers $headers -TimeoutSec 15 -UseBasicParsing
            if ($r.StatusCode -eq 200) {
                $data = $r.Content | ConvertFrom-Json
                $count = $data.total_count
                Write-Log "  API返回: $count 个结果（展示 $($data.items.Count) 个）"
                
                foreach ($item in $data.items) {
                    $allProjects += @{
                        name = $item.full_name
                        stars = $item.stargazers_count
                        description = $item.description
                        url = $item.html_url
                        language = $item.language
                        owner = $item.owner.login
                        created = $item.created_at
                        updated = $item.updated_at
                        pushed = $item.pushed_at
                    }
                }
            }
        } catch {
            Write-Log "  API请求失败: $($_.Exception.Message.Substring(0, [Math]::Min(80, $_.Exception.Message.Length)))" "WARN"
        }
        Start-Sleep -Seconds 2
    }
    
    # 去重（按name）
    $seen = @{}
    $unique = @()
    foreach ($p in $allProjects) {
        if (-not $seen.ContainsKey($p.name)) {
            $seen[$p.name] = $true
            $unique += $p
        }
    }
    
    Write-Log "  去重后: $($unique.Count) 个项目"
    return $unique
}

# ========== 镜像站采集（备用） ==========
function Get-GithubTrendingViaMirror {
    Write-Log ">> 策略2: 通过镜像站采集..."
    
    foreach ($mirror in $MirrorList) {
        Write-Log "  尝试: $mirror"
        try {
            # 通过镜像站访问 GitHub Trending 页面
            $trendingUrl = "$mirror/trending"
            $r = Invoke-WebRequest -Uri $trendingUrl -TimeoutSec 15 -UseBasicParsing -UserAgent "Mozilla/5.0"
            if ($r.StatusCode -eq 200) {
                $content = $r.Content
                
                # 解析仓库名和链接
                $projects = @()
                $repoMatches = [regex]::Matches($content, 'href="/([^/]+)/([^"]+)"')
                
                # 提取热门仓库信息
                $nameSet = @{}
                foreach ($m in $repoMatches) {
                    $owner = $m.Groups[1].Value
                    $repo = $m.Groups[2].Value
                    if ($owner -and $repo -and $owner -ne "login" -and $owner -ne "settings") {
                        $fullName = "$owner/$repo"
                        if (-not $nameSet.ContainsKey($fullName)) {
                            $nameSet[$fullName] = $true
                            $projects += @{
                                name = $fullName
                                stars = 0
                                description = ""
                                url = "$mirror/$fullName"
                                language = ""
                            }
                        }
                    }
                }
                
                Write-Log "  镜像站成功: $($projects.Count) 个项目"
                return $projects
            }
        } catch {
            Write-Log "  镜像站失败: $mirror - $($_.Exception.Message.Substring(0,50))" "WARN"
        }
        Start-Sleep -Seconds 2
    }
    
    Write-Log "  所有镜像站均失败" "ERROR"
    return @()
}

# ========== 计算价值分 ==========
function Get-ValueScore {
    param([int]$Stars, [string]$Description)
    
    $score = [Math]::Round($Stars * 1.0)
    
    # AI/ML 相关项目加权
    $aiKeywords = @("ai", "llm", "gpt", "model", "neural", "machine learning", "deep learning", "agent", "chatbot", "nlp")
    $descLower = $Description.ToLower()
    foreach ($kw in $aiKeywords) {
        if ($descLower.Contains($kw)) {
            $score = [Math]::Round($Stars * 1.2)
            break
        }
    }
    
    return $score
}

# ========== 分类项目 ==========
function Get-ProjectCategory {
    param([string]$Name, [string]$Description, [string]$Language)
    
    $aiKeywords = @("ai", "llm", "gpt", "model", "neural", "machine learning", "deep learning", "agent", "chatbot", "nlp", "autogpt", "claude", "openai")
    $devKeywords = @("tool", "cli", "dev", "code", "ide", "editor", "debug", "test", "build", "deploy", "docker", "kubernetes", "git", "api")
    $dataKeywords = @("data", "database", "sql", "storage", "cache", "search", "analytics")
    
    $text = "$Name $Description".ToLower()
    
    foreach ($kw in $aiKeywords) {
        if ($text.Contains($kw)) { return "AI/ML" }
    }
    foreach ($kw in $devKeywords) {
        if ($text.Contains($kw)) { return "开发工具" }
    }
    foreach ($kw in $dataKeywords) {
        if ($text.Contains($kw)) { return "数据工具" }
    }
    
    return "其他"
}

# ========== 生成 Markdown 报告 ==========
function New-GithubTrendingReport {
    param([array]$Projects)
    
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# GitHub Trending 热榜 | $DateStr")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("**数据源**: GitHub API（自动采集）")
    [void]$sb.AppendLine("**采集时间**: $DateTimeStr GMT+8")
    [void]$sb.AppendLine("**项目数量**: $($Projects.Count)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
    
    # 按分类分组
    $aiProjects = $Projects | Where-Object { $_.category -eq "AI/ML" } | Sort-Object -Property valueScore -Descending
    $devProjects = $Projects | Where-Object { $_.category -eq "开发工具" } | Sort-Object -Property valueScore -Descending
    $otherProjects = $Projects | Where-Object { $_.category -notin @("AI/ML", "开发工具") } | Sort-Object -Property valueScore -Descending
    
    # AI/ML 项目
    if ($aiProjects.Count -gt 0) {
        [void]$sb.AppendLine("## 🔴 AI/ML 相关（重点关注）")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| 项目 | Stars | 价值分 | 描述 | 分类 |")
        [void]$sb.AppendLine("|------|-------|--------|------|------|")
        foreach ($p in $aiProjects) {
            $desc = if ($p.description) { $p.description -replace '\|', '\\|' -replace '\n', ' ' } else { "" }
            [void]$sb.AppendLine("| **$($p.name)** | $($p.stars) | $($p.valueScore) | $desc | $($p.category) |")
        }
        [void]$sb.AppendLine("")
    }
    
    # 开发工具
    if ($devProjects.Count -gt 0) {
        [void]$sb.AppendLine("## 🔧 开发工具")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| 项目 | Stars | 价值分 | 描述 |")
        [void]$sb.AppendLine("|------|-------|--------|------|")
        foreach ($p in $devProjects) {
            $desc = if ($p.description) { $p.description -replace '\|', '\\|' -replace '\n', ' ' } else { "" }
            [void]$sb.AppendLine("| **$($p.name)** | $($p.stars) | $($p.valueScore) | $desc |")
        }
        [void]$sb.AppendLine("")
    }
    
    # 其他项目
    if ($otherProjects.Count -gt 0) {
        [void]$sb.AppendLine("## 📊 其他项目")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| 项目 | Stars | 价值分 | 描述 |")
        [void]$sb.AppendLine("|------|-------|--------|------|")
        foreach ($p in $otherProjects) {
            $desc = if ($p.description) { $p.description -replace '\|', '\\|' -replace '\n', ' ' } else { "" }
            [void]$sb.AppendLine("| **$($p.name)** | $($p.stars) | $($p.valueScore) | $desc |")
        }
        [void]$sb.AppendLine("")
    }
    
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("*来源: GitHub API 自动采集*")
    
    return $sb.ToString()
}

# ========== 主流程 ==========
Write-Log "========== GitHub Trending 采集 v2 开始 =========="
Write-Log "日期: $DateStr"
Write-Log "Token: $(if ($GithubToken) { '已配置' } else { '未配置（使用匿名模式）' })"

# 尝试 API 采集
$projects = Get-GithubTrendingViaApi -DaysBack 30 -MinStars 500

# 如果 API 失败，尝试镜像站
if ($projects.Count -eq 0) {
    Write-Log "API 采集失败，切换到镜像站策略..." "WARN"
    $projects = Get-GithubTrendingViaMirror
}

if ($projects.Count -eq 0) {
    Write-Log "所有采集策略均失败，生成空报告" "ERROR"
    $projects = @()
}

# 计算价值和分类
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
    }
}

# 按价值分排序
$enrichedProjects = $enrichedProjects | Sort-Object -Property valueScore -Descending | Select-Object -First 30

# 生成报告
$report = New-GithubTrendingReport -Projects $enrichedProjects

# 保存 Markdown
$mdPath = "$OutputDir\github-trending-$DateStr.md"
$report | Out-File -FilePath $mdPath -Encoding UTF8
Write-Log "Markdown报告: $mdPath"

# 保存 JSON
$jsonPath = "$OutputDir\github-trending-$DateStr.json"
$enrichedProjects | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonPath -Encoding UTF8
Write-Log "JSON数据: $jsonPath"

# 更新 latest 链接
$latestMdPath = "$OutputDir\github-trending_latest.md"
$report | Out-File -FilePath $latestMdPath -Encoding UTF8
$latestJsonPath = "$OutputDir\github-trending_latest.json"
$enrichedProjects | ConvertTo-Json -Depth 5 | Out-File -FilePath $latestJsonPath -Encoding UTF8

Write-Log "========== 采集完成 =========="
Write-Log "共采集: $($enrichedProjects.Count) 个项目"
if ($enrichedProjects.Count -gt 0) {
    $topProject = $enrichedProjects[0]
    Write-Log "热门项目: $($topProject.name) (★$($topProject.stars))"
}

# 返回结果供调用方使用
return @{
    date = $DateStr
    count = $enrichedProjects.Count
    projects = $enrichedProjects
    mdPath = $mdPath
    jsonPath = $jsonPath
}
