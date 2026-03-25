# ============================================================
# collect-tech-news.ps1 - 科技新闻采集脚本
# 用途: 采集GitHub Trending、AI博客、量子计算进展
# 数据源: 
#   - cn.bing.com (GitHub Trending镜像搜索, AI新闻)
#   - deepseek.com (DeepSeek官方博客)
#   - federalreserve.gov (Fed相关)
# 频率: 每日执行 (建议北京时间 10:00 / 22:00)
# ============================================================

param(
    [string]$OutputDir = "C:\Users\Administrator\clawd\agents\workspace-gid\data\tech",
    [switch]$Verbose
)

# ========== 基础配置 ==========
$ErrorActionPreference = "Continue"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$DateStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $msg = "[$Level] $(Get-Date -Format 'HH:mm:ss') - $Message"
    Write-Host $msg
    Add-Content -Path "$OutputDir\collect-tech.log" -Value $msg
}

function Invoke-WebFetch {
    param([string]$Url, [int]$MaxChars = 5000)
    try {
        $result = web-fetch --url $Url --maxChars $MaxChars 2>$null
        if ($result -and $result.status -eq 200) {
            return $result.text
        }
    } catch {
        Write-Log "Fetch失败: $Url - $_" "ERROR"
    }
    return $null
}

function Invoke-BingSearch {
    param([string]$Query, [int]$MaxChars = 5000)
    $encoded = [System.Web.HttpUtility]::UrlEncode($Query)
    $url = "https://cn.bing.com/search?q=$encoded"
    try {
        $result = web-fetch --url $url --maxChars $MaxChars 2>$null
        if ($result -and $result.status -eq 200) {
            return $result.text
        }
    } catch {}
    return $null
}

# ========== 主采集流程 ==========
Write-Log "========== 科技新闻采集开始 =========="
Write-Log "采集时间: $DateStr"

$report = @{
    timestamp = $DateStr
    data = @{}
    errors = @()
}

# ---------- 1. GitHub Trending (通过 gh-trending-v2.ps1) ----------
Write-Log ">> 采集GitHub Trending (v2)..."
$ghScriptPath = "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\gh-trending-v2.ps1"
if (Test-Path $ghScriptPath) {
    try {
        $ghResult = & $ghScriptPath -OutputDir $OutputDir
        if ($ghResult -and $ghResult.count -gt 0) {
            $report.data.github_trending = $ghResult.projects
            Write-Log "GitHub Trending 采集成功: $($ghResult.count) 个项目"
        } else {
            Write-Log "GitHub Trending 采集返回空结果" "WARN"
            $report.errors += "GitHub trending returned empty"
        }
    } catch {
        Write-Log "GitHub Trending 脚本执行失败: $($_.Exception.Message.Substring(0,80))" "ERROR"
        $report.errors += "GitHub trending script failed"
    }
} else {
    Write-Log "gh-trending-v2.ps1 未找到，回退到Bing搜索模式" "WARN"
    # 回退: Bing搜索模式
    $githubTrendingQueries = @(
        "GitHub Trending Python 2026",
        "GitHub Trending JavaScript 2026",
        "GitHub trending repositories today"
    )
    $githubProjects = @()
    foreach ($q in $githubTrendingQueries) {
        Write-Log "  搜索: $q"
        $content = Invoke-BingSearch -Query $q -MaxChars 5000
        if ($content) {
            $matches = [regex]::Matches($content, 'github\.com/[\w\-\.]+/[\w\-\.]+')
            $uniqueProjects = @{}
            foreach ($m in $matches) {
                $proj = $m.Value -replace 'github\.com/', ''
                if (-not $uniqueProjects.ContainsKey($proj)) {
                    $uniqueProjects[$proj] = $true
                    $githubProjects += @{ name = $proj; query = $q }
                }
            }
            Write-Log "  发现 $($uniqueProjects.Count) 个项目"
        }
        Start-Sleep -Seconds 2
    }
    $report.data.github_trending = $githubProjects
}

# ---------- 2. AI技术博客 ----------
Write-Log ">> 采集AI技术博客..."

# DeepSeek Blog (官方网站)
Write-Log "  DeepSeek Blog..."
$deepseekContent = Invoke-WebFetch -Url "https://deepseek.com/blog" -MaxChars 8000
if ($deepseekContent) {
    $report.data.deepseek_blog = @{
        url = "https://deepseek.com/blog"
        raw_length = $deepseekContent.Length
        raw_snippet = $deepseekContent.Substring(0, [Math]::Min(1000, $deepseekContent.Length))
    }
    Write-Log "  DeepSeek采集成功 (长度: $($deepseekContent.Length))"
} else {
    Write-Log "  DeepSeek采集失败" "ERROR"
    $report.errors += "DeepSeek blog failed"
}

# OpenAI News (通过搜索)
Write-Log "  OpenAI News..."
$openaiContent = Invoke-BingSearch -Query "OpenAI blog news 2026" -MaxChars 5000
if ($openaiContent) {
    $report.data.openai_news = @{
        source = "cn.bing.com search"
        raw_length = $openaiContent.Length
        raw_snippet = $openaiContent.Substring(0, [Math]::Min(1000, $openaiContent.Length))
    }
    Write-Log "  OpenAI采集成功"
} else {
    Write-Log "  OpenAI采集失败" "ERROR"
    $report.errors += "OpenAI search failed"
}

# Google AI Blog
Write-Log "  Google AI Blog..."
$googleAiContent = Invoke-BingSearch -Query "Google AI deepmind research blog 2026" -MaxChars 5000
if ($googleAiContent) {
    $report.data.google_ai = @{
        source = "cn.bing.com search"
        raw_length = $googleAiContent.Length
        raw_snippet = $googleAiContent.Substring(0, [Math]::Min(1000, $googleAiContent.Length))
    }
    Write-Log "  Google AI采集成功"
} else {
    Write-Log "  Google AI采集失败" "ERROR"
    $report.errors += "Google AI search failed"
}

# ---------- 3. 量子计算进展 ----------
Write-Log ">> 采集量子计算进展..."
$quantumQueries = @(
    "quantum computing breakthrough 2026",
    "IBM Google quantum qubit 2026",
    "量子计算 突破 2026"
)

$quantumNews = @()
foreach ($q in $quantumQueries) {
    Write-Log "  查询: $q"
    $content = Invoke-BingSearch -Query $q -MaxChars 5000
    if ($content) {
        $quantumNews += @{
            query = $q
            raw_length = $content.Length
            snippet = $content.Substring(0, [Math]::Min(500, $content.Length))
        }
        Write-Log "  采集成功 (长度: $($content.Length))"
    } else {
        Write-Log "  查询失败: $q" "ERROR"
    }
    Start-Sleep -Seconds 2
}
$report.data.quantum = $quantumNews

# ---------- 4. 芯片/半导体行业 ----------
Write-Log ">> 采集芯片半导体行业动态..."
$chipQueries = @(
    "semiconductor chip industry news 2026",
    "芯片半导体 行业动态 2026"
)

$chipNews = @()
foreach ($q in $chipQueries) {
    Write-Log "  查询: $q"
    $content = Invoke-BingSearch -Query $q -MaxChars 4000
    if ($content) {
        $chipNews += @{
            query = $q
            raw_length = $content.Length
            snippet = $content.Substring(0, [Math]::Min(500, $content.Length))
        }
        Write-Log "  成功 (长度: $($content.Length))"
    } else {
        Write-Log "  失败: $q" "ERROR"
    }
    Start-Sleep -Seconds 2
}
$report.data.chip_industry = $chipNews

# ========== 保存结果 ==========
$jsonPath = "$OutputDir\tech-news_$Timestamp.json"
$report | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonPath -Encoding UTF8

$latestPath = "$OutputDir\tech-news_latest.json"
$report | ConvertTo-Json -Depth 5 | Out-File -FilePath $latestPath -Encoding UTF8

Write-Log "========== 采集完成 =========="
Write-Log "数据文件: $jsonPath"
Write-Log "错误数量: $($report.errors.Count)"
if ($report.errors.Count -gt 0) {
    Write-Log "错误详情: $($report.errors -join '; ')" "WARN"
}

