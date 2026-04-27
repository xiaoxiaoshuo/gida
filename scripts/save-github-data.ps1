$DataDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data\ai"
$DateStr = "2026-04-27"
$DateTimeStr = "2026-04-27 19:06:00"

$tempFile = "$DataDir\github-api-temp.json"
if (-not (Test-Path $tempFile)) {
    Write-Host "ERROR: temp file not found at $tempFile"
    exit 1
}

$raw = Get-Content $tempFile -Raw
$data = $raw | ConvertFrom-Json
$items = $data.items

$projects = @()
$aiKeywords = @("ai","llm","gpt","model","neural","machine learning","deep learning","agent","chatbot","nlp","autogpt","claude","openai","gemini","deepseek","mcp","rag","vector","automation","workflow")
$devKeywords = @("tool","cli","dev","code","ide","editor","debug","test","build","deploy","docker","kubernetes","git","api","sdk")

foreach ($item in $items) {
    $desc = if ($item.description) { $item.description } else { "" }
    $lang = if ($item.language) { $item.language } else { "" }
    $text = "$($item.full_name) $desc".ToLower()
    
    $isAI = $false
    foreach ($kw in $aiKeywords) { if ($text.Contains($kw)) { $isAI = $true; break } }
    
    if ($isAI) {
        $category = "AI/ML"
    } elseif ($text -match "tool|cli|dev|code|ide|editor|api|sdk") {
        $category = "开发工具"
    } else {
        $category = "其他"
    }
    
    $score = [Math]::Round($item.stargazers_count * 1.0)
    foreach ($kw in $aiKeywords) { if ($desc.ToLower().Contains($kw)) { $score = [Math]::Round($item.stargazers_count * 1.3); break } }
    
    $projects += @{
        name = $item.full_name
        stars = $item.stargazers_count
        description = $desc
        url = $item.html_url
        language = $lang
        owner = $item.owner.login
        pushed = $item.pushed_at
        forks = $item.forks_count
        category = $category
        valueScore = $score
    }
}

$seen = @{}
$unique = @()
foreach ($p in $projects) {
    if (-not $seen.ContainsKey($p.name)) {
        $seen[$p.name] = $true
        $unique += $p
    }
}
$unique = $unique | Sort-Object -Property valueScore -Descending | Select-Object -First 30

$unique | ConvertTo-Json -Depth 5 | Out-File -FilePath "$DataDir\github-trending-2026-04-27.json" -Encoding UTF8
$unique | ConvertTo-Json -Depth 5 | Out-File -FilePath "$DataDir\github-trending_latest.json" -Encoding UTF8

$aiCount = @($unique | Where-Object { $_.category -eq 'AI/ML' }).Count
$devCount = @($unique | Where-Object { $_.category -eq '开发工具' }).Count
$otherCount = @($unique | Where-Object { $_.category -eq '其他' }).Count

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# GitHub Trending 热榜 | $DateStr")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**采集时间**: $DateTimeStr GMT+8")
[void]$sb.AppendLine("**数据源**: GitHub API (浏览器模式)")
[void]$sb.AppendLine("**项目数量**: $($unique.Count)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## 🔴 AI/ML (共$aiCount个)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| 项目 | ★ | 价值分 | 语言 | 描述 |")
[void]$sb.AppendLine("|------|---|--------|------|------|")
foreach ($p in ($unique | Where-Object { $_.category -eq 'AI/ML' } | Select-Object -First 10)) {
    $desc = if ($p.description) { $p.description -replace '\|','\\|' -replace "`n",' ' } else { "" }
    [void]$sb.AppendLine("| **$($p.name)** | $($p.stars) | $($p.valueScore) | $($p.language) | $desc |")
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## 🔧 开发工具 (共$devCount个)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| 项目 | ★ | 价值分 | 语言 | 描述 |")
[void]$sb.AppendLine("|------|---|--------|------|------|")
foreach ($p in ($unique | Where-Object { $_.category -eq '开发工具' } | Select-Object -First 10)) {
    $desc = if ($p.description) { $p.description -replace '\|','\\|' -replace "`n",' ' } else { "" }
    [void]$sb.AppendLine("| **$($p.name)** | $($p.stars) | $($p.valueScore) | $($p.language) | $desc |")
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## 📊 其他 (共$otherCount个)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| 项目 | ★ | 价值分 | 语言 | 描述 |")
[void]$sb.AppendLine("|------|---|--------|------|------|")
foreach ($p in ($unique | Where-Object { $_.category -eq '其他' } | Select-Object -First 10)) {
    $desc = if ($p.description) { $p.description -replace '\|','\\|' -replace "`n",' ' } else { "" }
    [void]$sb.AppendLine("| **$($p.name)** | $($p.stars) | $($p.valueScore) | $($p.language) | $desc |")
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("*来源: GitHub API 自动采集 (v3 - 浏览器模式)*")

$report = $sb.ToString()
$report | Out-File -FilePath "$DataDir\github-trending-2026-04-27.md" -Encoding UTF8
$report | Out-File -FilePath "$DataDir\github-trending_latest.md" -Encoding UTF8

Write-Host "OK: $($unique.Count) projects saved"
Write-Host "AI/ML: $aiCount, Dev: $devCount, Other: $otherCount"
Remove-Item $tempFile -ErrorAction SilentlyContinue
