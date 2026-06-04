# ============================================================
# gh-trending-v6-3layer-fallback.ps1
# GitHub Trending 全自动采集 v6 (3 层降级版)
#
# 设计背景 (2026-06-05):
#   - 现有 gh-trending-v6 (Playwright PowerShell) 因模块未装, cron 静默失败
#   - 现有 gh-trending-v7 (browser tool 调用) 依赖主代理会话, cron 环境无法执行
#   - 现有 gh-trending-browser-v5 (纯指南) 输出"请在 browser tool 执行",4 次断链
#   - 本脚本设计目标: cron 环境 0 依赖 0 人工 0 静默失败
#
# 3 层降级 (Layer 1 → Layer 2 → Layer 3):
#   Layer 1: GitHub Search API (web_fetch 等价, 通过 Invoke-RestMethod 调 api.github.com)
#            - 验证可用 (2026-04-09 测试通过)
#            - 输出: 完整 JSON (30 repos, 含 stars/language/description)
#   Layer 2: web_fetch 备用 (github.com/trending)
#            - JS 渲染网站, 只能拿到 HTML 骨架 + 部分 repo 名
#            - 输出: 部分 JSON (10-20 repos, 仅 name 字段)
#   Layer 3: 错误归档 (data/system/gh-trending-errors.jsonl)
#            - 记录 {timestamp, layer_failed, error_msg}
#            - 同时写空 latest.json (避免下游 read 失败)
#
# 用法:
#   powershell -File C:\Users\Administrator\clawd\agents\workspace-gid\scripts\gh-trending-v6-3layer-fallback.ps1
#   powershell -File ...\gh-trending-v6-3layer-fallback.ps1 -Date "2026-06-05"   # 指定日期
#
# 输出:
#   - data/tech/github-trending_latest.json  (主输出, 始终覆盖)
#   - data/tech/github-trending-YYYY-MM-DD.json  (按日归档, 第一次成功时创建)
#   - data/system/gh-trending-errors.jsonl  (失败日志, 追加)
#
# 测试命令:
#   pwsh -File scripts/gh-trending-v6-3layer-fallback.ps1
#   pwsh -File scripts/gh-trending-v6-3layer-fallback.ps1 -Date "2026-06-05"
#
# 退出码:
#   0 = 至少一层成功
#   1 = 全部失败 (latest.json 仍写入空壳)
# ============================================================

param(
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
    [int]$MaxRepos = 30
)

$ErrorActionPreference = 'Continue'

# ============== 路径配置 ==============
$RepoRoot = 'C:\Users\Administrator\clawd\agents\workspace-gid'
$OutputLatest = Join-Path $RepoRoot 'data\tech\github-trending_latest.json'
$OutputArchive = Join-Path $RepoRoot ("data\tech\github-trending-$Date.json")
$ErrorLog = Join-Path $RepoRoot 'data\system\gh-trending-errors.jsonl'

# 确保目录存在
foreach ($dir in @((Split-Path $OutputLatest -Parent), (Split-Path $ErrorLog -Parent))) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

$Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$StartTime = Get-Date

Write-Host "[$Timestamp] gh-trending-v6-3layer-fallback 启动 (date=$Date, max=$MaxRepos)"

# ============== 工具函数 ==============
function Write-ErrorArchive {
    param(
        [string]$Layer,
        [string]$ErrorMsg,
        [string]$Fallback = 'none'
    )
    $entry = @{
        timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
        layer_failed = $Layer
        error = $ErrorMsg.Substring(0, [Math]::Min(500, $ErrorMsg.Length))
        fallback_used = $Fallback
        date_param = $Date
    }
    $line = ($entry | ConvertTo-Json -Compress)
    Add-Content -Path $ErrorLog -Value $line -Encoding UTF8
    Write-Host "[ARCHIVE] $Layer failed: $ErrorMsg" -ForegroundColor Red
}

function Write-EmptyLatest {
    $empty = @{
        collected_at = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        source = 'gh-trending-v6-3layer-fallback (all layers failed)'
        date = $Date
        total = 0
        repos = @()
        note = '所有 3 层采集均失败, 见 data/system/gh-trending-errors.jsonl'
    }
    $empty | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputLatest -Encoding UTF8
}

# ============== Layer 1: GitHub Search API ==============
function Get-TrendingViaAPI {
    Write-Host "[Layer 1] 尝试 GitHub Search API..."

    # 查询: 最近 1 个月推送, stars>1000, 按 stars 降序
    $pushedDate = (Get-Date).AddDays(-30).ToString('yyyy-MM-dd')
    $query = "stars:>1000+pushed:>$pushedDate"
    $uri = "https://api.github.com/search/repositories?q=$query&sort=stars&order=desc&per_page=$MaxRepos"

    try {
        $headers = @{
            'Accept' = 'application/vnd.github.v3+json'
            'User-Agent' = 'gh-trending-v6-3layer-fallback'
        }
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 20

        if (-not $response -or -not $response.items -or $response.items.Count -eq 0) {
            Write-Host "[Layer 1] API 返回 0 items" -ForegroundColor Yellow
            return $null
        }

        $repos = @()
        foreach ($item in $response.items) {
            $repos += @{
                name = $item.full_name
                stars = [int]$item.stargazers_count
                stars_today = 0   # API 不提供 today, 由 markdown 注释说明
                language = if ($item.language) { $item.language } else { '' }
                description = if ($item.description) { $item.description } else { '' }
                html_url = $item.html_url
                pushed_at = $item.pushed_at
                collected_via = 'github_api_layer1'
            }
        }

        Write-Host "[Layer 1] 成功: $($repos.Count) repos" -ForegroundColor Green
        return @{
            collected_at = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            source = 'github.com/search/repositories (Layer 1)'
            date = $Date
            total = $repos.Count
            note = 'Layer 1 完整数据; stars_today 字段为 0 (API 不提供), 真实 today 需 Layer 0 (browser evaluate)'
            repos = $repos
        }
    } catch {
        $err = $_.Exception.Message
        Write-Host "[Layer 1] 异常: $err" -ForegroundColor Yellow
        Write-ErrorArchive -Layer 'L1_GitHubAPI' -ErrorMsg $err -Fallback 'try_L2_webfetch'
        return $null
    }
}

# ============== Layer 2: web_fetch 备用 (github.com/trending) ==============
function Get-TrendingViaFetch {
    Write-Host "[Layer 2] 尝试 web_fetch (github.com/trending)..."

    try {
        # UA 伪装 + 接受头
        $headers = @{
            'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            'Accept' = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
            'Accept-Language' = 'en-US,en;q=0.9'
        }
        $html = Invoke-WebRequest -Uri 'https://github.com/trending' -Headers $headers -UseBasicParsing -TimeoutSec 20

        if ($html.StatusCode -ne 200) {
            $err = "HTTP $($html.StatusCode)"
            Write-Host "[Layer 2] 状态码异常: $err" -ForegroundColor Yellow
            Write-ErrorArchive -Layer 'L2_webfetch' -ErrorMsg $err -Fallback 'try_L3_archive_only'
            return $null
        }

        $content = $html.Content

        # 检查是否 SPA 骨架
        if ($content -notmatch 'Box-row|article.Box-row') {
            # 尝试 regex 提取 repo 名 (匹配 /<user>/<repo> 模式)
            $matches = [regex]::Matches($content, '/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)(?:"|<|\s)')

            if ($matches.Count -eq 0) {
                $err = "HTML 中无 repo 模式 (SPA 骨架), length=$($content.Length)"
                Write-Host "[Layer 2] $err" -ForegroundColor Yellow
                Write-ErrorArchive -Layer 'L2_webfetch' -ErrorMsg $err -Fallback 'try_L3_archive_only'
                return $null
            }

            $unique = $matches | ForEach-Object { $_.Groups[1].Value } |
                Where-Object { $_ -notmatch '^(sponsors|features|pricing|enterprise|team|explore|topics|trending|collections|events|marketplace|pull-requests|issues|codespaces|copilot|security|login|join|signup|home|about)$' -and $_ -notmatch '/' -split '/' -and $_.Count -eq 2 } |
                Sort-Object -Unique |
                Select-Object -First $MaxRepos

            $repos = @()
            foreach ($name in $unique) {
                $repos += @{
                    name = $name
                    stars = 0
                    stars_today = 0
                    language = ''
                    description = ''
                    html_url = "https://github.com/$name"
                    collected_via = 'webfetch_partial_layer2'
                }
            }

            Write-Host "[Layer 2] 部分成功: $($repos.Count) repos (仅 name, 无 stars/language)" -ForegroundColor Yellow
            return @{
                collected_at = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                source = 'github.com/trending (Layer 2 web_fetch partial)'
                date = $Date
                total = $repos.Count
                note = 'Layer 2 部分数据 (SPA 骨架, 仅 name 字段); stars/language 需 Layer 0/1 补全'
                repos = $repos
            }
        } else {
            # 如果 HTML 中确实有 Box-row, 简单提取
            $rowMatches = [regex]::Matches($content, '<article[^>]*class="[^"]*Box-row[^"]*"[^>]*>(.*?)</article>', 'Singleline')
            $repos = @()
            foreach ($m in $rowMatches) {
                $block = $m.Groups[1].Value
                $nameMatch = [regex]::Match($block, '/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)(?:"|<|\s)')
                if ($nameMatch.Success) {
                    $name = $nameMatch.Groups[1].Value
                    $starMatch = [regex]::Match($block, '([\d,]+)\s*</span>')
                    $stars = 0
                    if ($starMatch.Success) { $stars = [int]($starMatch.Groups[1].Value -replace ',', '') }
                    $repos += @{
                        name = $name
                        stars = $stars
                        stars_today = 0
                        language = ''
                        description = ''
                        html_url = "https://github.com/$name"
                        collected_via = 'webfetch_regex_layer2'
                    }
                }
            }
            $repos = $repos | Select-Object -First $MaxRepos

            if ($repos.Count -eq 0) {
                $err = "Box-row 存在但 regex 提取失败"
                Write-Host "[Layer 2] $err" -ForegroundColor Yellow
                Write-ErrorArchive -Layer 'L2_webfetch' -ErrorMsg $err -Fallback 'try_L3_archive_only'
                return $null
            }

            Write-Host "[Layer 2] regex 提取成功: $($repos.Count) repos" -ForegroundColor Yellow
            return @{
                collected_at = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                source = 'github.com/trending (Layer 2 web_fetch regex)'
                date = $Date
                total = $repos.Count
                note = 'Layer 2 部分数据 (regex 提取, stars 可能不准确)'
                repos = $repos
            }
        }
    } catch {
        $err = $_.Exception.Message
        Write-Host "[Layer 2] 异常: $err" -ForegroundColor Yellow
        Write-ErrorArchive -Layer 'L2_webfetch' -ErrorMsg $err -Fallback 'try_L3_archive_only'
        return $null
    }
}

# ============== Layer 3: archive 错误 + 写空壳 ==============
function Write-Layer3Archive {
    Write-Host "[Layer 3] 全部层失败, 写入空壳 + 错误归档" -ForegroundColor Red
    $err = 'L1 (GitHub API) + L2 (web_fetch) 均失败'
    Write-ErrorArchive -Layer 'L3_archive' -ErrorMsg $err -Fallback 'none'
    Write-EmptyLatest

    # 也尝试写 archive (空)
    $empty = @{
        collected_at = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        source = 'gh-trending-v6-3layer-fallback (all layers failed)'
        date = $Date
        total = 0
        repos = @()
        note = '所有 3 层采集均失败, 见 data/system/gh-trending-errors.jsonl'
    }
    $empty | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputArchive -Encoding UTF8

    return $null
}

# ============== Main ==============
$result = $null
$usedLayer = 'none'

# Layer 1: GitHub API
$result = Get-TrendingViaAPI
if ($result) {
    $usedLayer = 'L1_GitHubAPI'
} else {
    # Layer 2: web_fetch
    Start-Sleep -Seconds 2
    $result = Get-TrendingViaFetch
    if ($result) {
        $usedLayer = 'L2_webfetch'
    } else {
        # Layer 3: archive
        Write-Layer3Archive | Out-Null
        $usedLayer = 'L3_archive'
    }
}

# 写主输出
if ($result) {
    $result | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputLatest -Encoding UTF8

    # 首次成功时, 创建日归档
    if (-not (Test-Path $OutputArchive)) {
        Copy-Item -Path $OutputLatest -Destination $OutputArchive -Force
        Write-Host "[OK] 日归档创建: $OutputArchive"
    } else {
        # 已有日归档, 覆盖 (同一日内多次采集, 取最新)
        Copy-Item -Path $OutputLatest -Destination $OutputArchive -Force
        Write-Host "[OK] 日归档更新: $OutputArchive"
    }

    $elapsed = ((Get-Date) - $StartTime).TotalSeconds
    Write-Host "[OK] github-trending-v6 success: $($result.total) repos (layer=$usedLayer, ${elapsed}s)" -ForegroundColor Green

    # 摘要输出 (cron 日志可 grep)
    Write-Host "[SUMMARY] date=$Date layer=$usedLayer total=$($result.total) output=$OutputLatest"
    exit 0
} else {
    $elapsed = ((Get-Date) - $StartTime).TotalSeconds
    Write-Host "[FAIL] github-trending-v6 全部失败 (${elapsed}s), 已写空壳 + 错误归档" -ForegroundColor Red
    Write-Host "[SUMMARY] date=$Date layer=$usedLayer total=0 output=$OutputLatest (empty)"
    exit 1
}
