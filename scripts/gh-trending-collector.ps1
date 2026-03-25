# gh-trending-collector.ps1 - GitHub Trending 深度采集 v2
# 用途: 采集GitHub热门项目 (多源降级)
# 降级路径: GitHub镜像站 → Gitee → Bing搜索优化策略
# 输出: data/tech/github-trending_YYYY-MM-DD.md + .json
# ============================================================

param(
    [string]$OutputDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data\tech",
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"
Add-Type -AssemblyName System.Web
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$DateStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$LogFile = "$OutputDir\gh-collector.log"
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $msg = "[$Level] $(Get-Date -Format 'HH:mm:ss') - $Message"
    Write-Host $msg
    Add-Content -Path $LogFile -Value $msg -Encoding UTF8
}

function Invoke-SafeFetch {
    param([string]$Url, [int]$Timeout = 12, [string]$UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
    try {
        $headers = @{ "User-Agent" = $UA; "Accept" = "text/html,*/*" }
        $r = Invoke-WebRequest -Uri $Url -Headers $headers -TimeoutSec $Timeout -UseBasicParsing
        return @{ ok = $true; content = $r.Content; status = $r.StatusCode; len = $r.Content.Length }
    } catch {
        return @{ ok = $false; error = $_.Exception.Message.Substring(0, 60); status = 0 }
    }
}

# ========== GitHub镜像站测试 ==========
function Test-GitHubMirrors {
    Write-Log "测试GitHub镜像站可用性..."
    $mirrors = @(
        @{ name = "githubfast.com"; url = "https://githubfast.com/trending" },
        @{ name = "hub.fastgit.xyz"; url = "https://hub.fastgit.xyz/trending" }
    )
    $results = @()
    foreach ($m in $mirrors) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $r = Invoke-SafeFetch -Url $m.url -Timeout 10
        $sw.Stop()
        if ($r.ok -and $r.status -eq 200 -and $r.len -gt 5000) {
            Write-Log "  [OK]  $($m.name) ($($sw.ElapsedMilliseconds)ms, $($r.len) bytes)" "OK"
            $results += @{ name = $m.name; url = $m.url; ok = $true; ms = $sw.ElapsedMilliseconds; len = $r.len }
        } else {
            Write-Log "  [FAIL] $($m.name) - status=$($r.status) len=$($r.len)" "WARN"
            $results += @{ name = $m.name; url = $m.url; ok = $false; status = $r.status; ms = $sw.ElapsedMilliseconds }
        }
    }
    return $results
}

# ========== 从镜像提取Trending数据 ==========
function Parse-GitHubTrendingHtml {
    param([string]$Html, [string]$Source)
    $projects = @()
    # 提取 <h2 class="h3"> or <article> 项目块
    # 格式: github.com/owner/repo
    $regexOwnerRepo = [regex]'github\.com[/\-]([a-zA-Z0-9_\-\.]+)/([a-zA-Z0-9_\-\.]+)'
    $regexStars = [regex]'([\d,\.]+)\s*(?:star|stars)'
    $regexDesc = [regex]'(?s)<p[^>]*>(.+?)</p>'
    
    $ownerRepoMatches = $regexOwnerRepo.Matches($Html)
    $seen = @{}
    $count = 0
    foreach ($m in $ownerRepoMatches) {
        if ($count -ge 50) { break }
        $repo = "$($m.Groups[1].Value)/$($m.Groups[2].Value)"
        if ($seen.ContainsKey($repo)) { continue }
        $seen[$repo] = $true
        
        # 找描述
        $desc = ""
        if ($m.Index -lt $Html.Length - 200) {
            $snippet = $Html.Substring($m.Index, [Math]::Min(500, $Html.Length - $m.Index))
            $dm = $regexDesc.Match($snippet)
            if ($dm.Success) { $desc = $dm.Groups[1].Value -replace '<[^>]+>', '' -replace '\s+', ' ' }
        }
        
        # 找stars
        $stars = 0
        if ($m.Index -lt $Html.Length - 300) {
            $snippet = $Html.Substring($m.Index, [Math]::Min(300, $Html.Length - $m.Index))
            $sm = $regexStars.Match($snippet)
            if ($sm.Success) { $stars = $sm.Groups[1].Value -replace ',', '' }
        }
        
        $projects += @{
            repo = $repo
            stars_raw = $stars
            description = $desc.Trim()
            source = $Source
        }
        $count++
    }
    return $projects
}

# ========== Bing搜索优化策略 (替代方案) ==========
function Get-GitHubTrendingViaBing {
    Write-Log "通过Bing搜索采集GitHub Trending..."
    
    # 优化的查询策略 - 直接搜具体项目类型
    $queries = @(
        @{ lang = "Python"; q = "GitHub trending Python repositories " + (Get-Date -Format "yyyy-MM-dd") },
        @{ lang = "JavaScript"; q = "GitHub trending JavaScript repositories " + (Get-Date -Format "yyyy-MM-dd") },
        @{ lang = "AI/ML"; q = "GitHub trending AI machine learning " + (Get-Date -Format "yyyy-MM-dd") },
        @{ lang = "Rust"; q = "GitHub trending Rust projects " + (Get-Date -Format "yyyy-MM-dd") },
        @{ lang = "Go"; q = "GitHub trending Go projects " + (Get-Date -Format "yyyy-MM-dd") }
    )
    
    $allProjects = @()
    $seen = @{}
    
    foreach ($q in $queries) {
        Write-Log "  查询: $($q.lang) - $($q.q)"
        $encoded = [System.Web.HttpUtility]::UrlEncode($q.q)
        $url = "https://cn.bing.com/search?q=$encoded"
        $r = Invoke-SafeFetch -Url $url -Timeout 15
        if (-not $r.ok) {
            Write-Log "    Bing查询失败" "WARN"
            continue
        }
        
        # 提取GitHub链接
        $ghRegex = [regex]'github\.com[/\-]([a-zA-Z0-9_\-\.]+)/([a-zA-Z0-9_\-\.]+)'
        $matches = $ghRegex.Matches($r.content)
        $found = 0
        foreach ($m in $matches) {
            $repo = "$($m.Groups[1].Value)/$($m.Groups[2].Value)"
            if ($seen.ContainsKey($repo)) { continue }
            $seen[$repo] = $true
            $found++
            
            # 简单估算stars (从搜索结果上下文)
            $stars = 0
            if ($m.Index -gt 50) {
                $snippet = $r.content.Substring([Math]::Max(0, $m.Index - 100), 200)
                $sMatch = [regex]'([\dK]+)\s*(?:star|k)'
                $sm = $sMatch.Match($snippet)
                if ($sm.Success) {
                    $starStr = $sm.Groups[1].Value
                    if ($starStr -match 'K') { $stars = [double]($starStr -replace 'K','') * 1000 }
                    else { $stars = [double]$starStr }
                }
            }
            
            $allProjects += @{
                repo = $repo
                lang = $q.lang
                stars_raw = $stars
                description = ""
                source = "cn.bing.com"
                query = $q.q
                confidence = if ($stars -gt 0) { "medium" } else { "low" }
            }
        }
        Write-Log "    发现 $found 个项目 (累计: $($allProjects.Count))"
        Start-Sleep -Seconds 1.5
    }
    
    return $allProjects
}

# ========== Gitee热榜 (备选) ==========
function Get-GiteeTrending {
    Write-Log "尝试Gitee热榜..."
    $urls = @(
        "https://gitee.com/api/v5/explore_rank/hottest?lang=python&scope=all&since=weekly",
        "https://gitee.com/api/v5/explore_rank/hottest?lang=javascript&scope=all&since=weekly"
    )
    $projects = @()
    foreach ($url in $urls) {
        $r = Invoke-SafeFetch -Url $url -Timeout 10
        if ($r.ok) {
            try {
                $json = $r.content | ConvertFrom-Json
                foreach ($item in $json) {
                    if ($projects.Count -ge 30) { break }
                    $projects += @{
                        repo = "gitee.com/$($item.path)"
                        stars_raw = $item.star_count
                        description = $item.description
                        source = "gitee.com"
                        lang = $item.lang
                        confidence = "medium"
                    }
                }
                Write-Log "  Gitee采集成功: $($projects.Count) 个项目" "OK"
            } catch {
                Write-Log "  Gitee JSON解析失败" "WARN"
            }
        }
    }
    return $projects
}

# ========== 生成Markdown报告 ==========
function New-GitHubTrendingReport {
    param([array]$Projects, [string]$Method, [int]$TotalLen)
    
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("# GitHub Trending 热榜 | $(Get-Date -Format 'yyyy-MM-dd')")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("**采集方法**: $Method  ")
    $null = $sb.AppendLine("**项目数量**: $($Projects.Count)  ")
    $null = $sb.AppendLine("**采集时间**: $(Get-Date -Format 'HH:mm GMT+8')")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine("")
    
    # 按stars排序
    $sorted = $Projects | Sort-Object -Property stars_raw -Descending | Select-Object -First 30
    
    # AI/ML项目
    $aiProjects = $sorted | Where-Object { $_.description -match "AI|artificial|model|llm|gpt|neural|agent|deep.?learn" -or $_.repo -match "AI|agent|llm|gpt" }
    if ($aiProjects) {
        $null = $sb.AppendLine("## 🤖 AI/ML 相关")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("| 项目 | Stars | 描述 | 来源 |")
        $null = $sb.AppendLine("|------|-------|------|------|")
        foreach ($p in $aiProjects) {
            $desc = if ($p.description) { $p.description.Substring(0, [Math]::Min(60, $p.description.Length)) } else { "" }
            $stars = if ($p.stars_raw -gt 1000) { "$([Math]::Round($p.stars_raw/1000,1))k" } else { $p.stars_raw }
            $null = $sb.AppendLine("| **$($p.repo)** | $stars | $desc | $($p.source) |")
        }
        $null = $sb.AppendLine("")
    }
    
    # 其他热门
    $null = $sb.AppendLine("## 📈 热门项目 (Top 20)")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| # | 项目 | Stars | 描述 |")
    $null = $sb.AppendLine("|---|------|-------|------|")
    $idx = 1
    foreach ($p in $sorted | Select-Object -First 20) {
        $desc = if ($p.description) { $p.description.Substring(0, [Math]::Min(50, $p.description.Length)) } else { "" }
        $stars = if ($p.stars_raw -gt 1000) { "$([Math]::Round($p.stars_raw/1000,1))k" } else { $p.stars_raw }
        $null = $sb.AppendLine("| $idx | **$($p.repo)** | $stars | $desc |")
        $idx++
    }
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine("*采集于 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss GMT+8')*")
    
    return $sb.ToString()
}

# ========== 主程序 ==========
Write-Log "========== GitHub Trending 采集开始 =========="
Write-Log "时间: $DateStr"

$result = @{
    timestamp = $DateStr
    collection_version = "v2"
    method = "unknown"
    projects = @()
    errors = @()
}

# 策略1: 测试GitHub镜像
$mirrorResults = Test-GitHubMirrors
$workingMirror = $mirrorResults | Where-Object { $_.ok -eq $true } | Select-Object -First 1

if ($workingMirror) {
    Write-Log "使用镜像: $($workingMirror.name)"
    $r = Invoke-SafeFetch -Url $workingMirror.url -Timeout 15
    if ($r.ok) {
        $projects = Parse-GitHubTrendingHtml -Html $r.content -Source $workingMirror.name
        if ($projects.Count -gt 0) {
            $result.projects = $projects
            $result.method = "mirror:$($workingMirror.name)"
            Write-Log "镜像采集成功: $($projects.Count) 个项目" "OK"
        }
    }
}

# 策略2: Bing搜索 (如果没有镜像)
if ($result.projects.Count -eq 0) {
    Write-Log "镜像不可用，降级到Bing搜索..."
    $bingProjects = Get-GitHubTrendingViaBing
    if ($bingProjects.Count -gt 0) {
        $result.projects = $bingProjects
        $result.method = "bing_optimized"
        Write-Log "Bing采集成功: $($bingProjects.Count) 个项目" "OK"
    }
}

# 策略3: Gitee (最后备选)
if ($result.projects.Count -eq 0) {
    Write-Log "尝试Gitee作为最后备选..."
    $giteeProjects = Get-GiteeTrending
    if ($giteeProjects.Count -gt 0) {
        $result.projects = $giteeProjects
        $result.method = "gitee_backup"
        Write-Log "Gitee采集成功: $($giteeProjects.Count) 个项目" "OK"
    } else {
        $result.errors += "所有采集方式均失败"
    }
}

# 保存JSON
$jsonFile = "$OutputDir\github-trending_$Timestamp.json"
$result | ConvertTo-Json -Depth 4 | Out-File -FilePath $jsonFile -Encoding UTF8

# 生成Markdown
$report = New-GitHubTrendingReport -Projects $result.projects -Method $result.method -TotalLen 0
$mdFile = "$OutputDir\github-trending_$Timestamp.md"
$report | Out-File -FilePath $mdFile -Encoding UTF8

# 更新latest
$result | ConvertTo-Json -Depth 4 | Out-File -FilePath "$OutputDir\github-trending_latest.json" -Encoding UTF8
$report | Out-File -FilePath "$OutputDir\github-trending_latest.md" -Encoding UTF8

Write-Log "========== 采集完成 =========="
Write-Log "方法: $($result.method)"
Write-Log "项目数: $($result.projects.Count)"
Write-Log "JSON: $jsonFile"
Write-Log "MD: $mdFile"

if ($result.errors.Count -gt 0) {
    Write-Log "错误: $($result.errors -join '; ')" "WARN"
}

exit $(if ($result.projects.Count -eq 0) { 1 } else { 0 })
