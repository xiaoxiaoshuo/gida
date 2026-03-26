# gh-trending-bgithub.ps1
# GitHub Trending 采集 — 使用 bgithub.xyz 镜像
# 2026-03-26

$ErrorActionPreference = 'SilentlyContinue'
$workDir = "C:\Users\Administrator\clawd\agents\workspace-gid"

$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm'
$results = @{
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    timestamp_iso = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    source = "bgithub.xyz/trending"
    projects = @()
    errors = @()
}

# 方法1：直接 Invoke-WebRequest（轻量）
try {
    $page = Invoke-WebRequest "https://bgithub.xyz/trending" -TimeoutSec 15 -UseBasicParsing
    if ($page.Content -match 'href="/[a-zA-Z0-9-]+/[a-zA-Z0-9-.]+"[^>]*>[^<]*</a>') {
        Write-Host "[gh-trending] bgithub.xyz 可访问（方法1）"
    }
} catch {
    Write-Host "[gh-trending] 方法1失败: $($_.Exception.Message)"
    $results.errors += "Method1_failed"
}

# 方法2：GitHub API（备用，不需要认证）
try {
    $gh = Invoke-RestMethod 'https://api.github.com/search/repositories?q=stars:>10000+pushed:>2026-03-25&sort=stars&order=desc&per_page=10' -TimeoutSec 10
    if ($gh.items) {
        $results.projects = $gh.items | Select-Object -First 10 | ForEach-Object {
            @{
                name = $_.full_name
                stars = $_.stargazers_count
                language = $_.language
                description = $_.description
                url = $_.html_url
            }
        }
        Write-Host "[gh-trending] GitHub API 成功: $($results.projects.Count) 项目"
    }
} catch {
    Write-Host "[gh-trending] GitHub API 失败: $($_.Exception.Message)"
    $results.errors += "GitHub_API_failed"
}

# 保存
if ($results.projects.Count -gt 0) {
    $jsonStr = $results | ConvertTo-Json -Depth 5
    $jsonStr | Set-Content "$workDir\data\tech\github-trending_$timestamp.json" -Encoding UTF8
    $jsonStr | Set-Content "$workDir\data\tech\github-trending_latest.json" -Encoding UTF8
    
    # Markdown 摘要
    $md = "# GitHub Trending | $timestamp`n`n"
    $md += "| # | 项目 | Stars | 语言 | 描述 |`n"
    $md += "|---|------|-------|------|------|`n"
    $i = 1
    foreach ($p in $results.projects) {
        $md += "| $i | [$($p.name)]|$($p.url) | $($p.stars) | $($p.language) | $($p.description.Substring(0,[Math]::Min(50,$p.description.Length))) |`n"
        $i++
    }
    $md | Set-Content "$workDir\data\tech\github-trending_$timestamp.md" -Encoding UTF8
    $md | Set-Content "$workDir\data\tech\github-trending_latest.md" -Encoding UTF8
    
    Write-Host "[gh-trending] 已保存 $($results.projects.Count) 个项目"
} else {
    Write-Host "[gh-trending] 警告：无数据"
}
