# ============================================================
# cron-ainews-0400.ps1
# 凌晨 04:00 AI News 补采脚本 (真空期填补)
#
# 设计背景 (2026-06-05):
#   - AINewsCollector_6h 在 00:00/06:00/12:00/18:00 触发
#   - 02:00-06:00 4h 真空期, 无 AI News 采集
#   - 6/4 04:31 + 6/5 02:27 主代理 fallback 手动补采 (不可持续)
#   - 本脚本目标: 每天 04:00 自动补采, 填补真空期
#
# 数据源 (与 AINewsCollector_6h 互补, 不重复):
#   1. Hacker News top 30 (实时, API 已验证稳定)
#   2. 4 家 AI 官方博客 RSS (尝试, 失败可降级)
#      - OpenAI: https://openai.com/blog/rss.xml
#      - Anthropic: https://www.anthropic.com/news/rss.xml
#      - Google AI: https://blog.google/technology/ai/rss/
#      - DeepSeek: https://api-docs.deepseek.com/news/rss (备选, 经常 404)
#   3. (可选) GitHub AI 趋势 (调用 gh-trending-v6-3layer-fallback)
#
# 失败降级:
#   - RSS 全部失败 → 保留 HN top 30, RSS 字段写空数组
#   - HN 失败 → 退出码 2
#   - HN + RSS 全失败 → 退出码 3, archive 错误
#
# 用法:
#   powershell -File C:\...\scripts\cron-ainews-0400.ps1
#   powershell -File ...\cron-ainews-0400.ps1 -Date "2026-06-05_04-00"
#   powershell -File ...\cron-ainews-0400.ps1 -SkipRSS   # 跳过 RSS, 只采 HN
#
# 输出:
#   - data/ai/ai-news_latest.json  (主输出, 始终覆盖, 下游读取)
#   - data/ai/ai-news_latest.md  (Markdown 摘要, 主代理分析用)
#   - data/ai/ai-news-YYYY-MM-DD_HH-mm.json  (按次归档)
#   - data/system/ainews-0400-errors.jsonl  (失败日志, 追加)
#
# 注册到 Task Scheduler (PowerShell 管理员):
#   $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
#     -Argument '-NoProfile -File "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\cron-ainews-0400.ps1"'
#   $trigger = New-ScheduledTaskTrigger -Daily -At '04:00'
#   Register-ScheduledTask -TaskName 'AINewsCollector_0400' `
#     -Action $action -Trigger $trigger -Description '凌晨 04:00 AI News 补采 (真空期填补)'
#
# 测试命令:
#   pwsh -File scripts/cron-ainews-0400.ps1
#   pwsh -File scripts/cron-ainews-0400.ps1 -Date "2026-06-05_04-00" -SkipRSS
# ============================================================

param(
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd_HH-mm'),
    [switch]$SkipRSS,
    [int]$MaxHN = 30
)

$ErrorActionPreference = 'Continue'

# ============== 路径配置 ==============
$RepoRoot = 'C:\Users\Administrator\clawd\agents\workspace-gid'
$OutputJson = Join-Path $RepoRoot 'data\ai\ai-news_latest.json'
$OutputMd = Join-Path $RepoRoot 'data\ai\ai-news_latest.md'
$OutputSnapshot = Join-Path $RepoRoot ("data\ai\ai-news-$Date.json")
$ErrorLog = Join-Path $RepoRoot 'data\system\ainews-0400-errors.jsonl'

# 确保目录存在
foreach ($dir in @((Split-Path $OutputJson -Parent), (Split-Path $ErrorLog -Parent))) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

$Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$StartTime = Get-Date
$Source = 'cron-ainews-0400'

Write-Host "[$Timestamp] $Source 启动 (date=$Date, maxHN=$MaxHN, skipRSS=$SkipRSS)"

# ============== 工具函数 ==============
function Write-ErrorArchive {
    param(
        [string]$Layer,
        [string]$ErrorMsg,
        [string]$Status = 'partial'
    )
    $entry = @{
        timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
        layer = $Layer
        error = $ErrorMsg.Substring(0, [Math]::Min(500, $ErrorMsg.Length))
        status = $Status
        date_param = $Date
    }
    $line = ($entry | ConvertTo-Json -Compress)
    Add-Content -Path $ErrorLog -Value $line -Encoding UTF8
    Write-Host "[ARCHIVE] ${Layer}: ${ErrorMsg}" -ForegroundColor Red
}

# ============== 1. Hacker News Top N ==============
function Get-HNTop {
    Write-Host "[HN] 拉取 Hacker News top $MaxHN..."

    $baseUrl = 'https://hacker-news.firebaseio.com/v0/'
    $items = @()
    $failCount = 0

    try {
        $ids = Invoke-RestMethod -Uri ($baseUrl + 'topstories.json') -TimeoutSec 15
        if (-not $ids -or $ids.Count -eq 0) {
            Write-ErrorArchive -Layer 'HN_topstories' -ErrorMsg 'topstories.json 返回空' -Status 'fail'
            return $null
        }
        Write-Host "[HN] topstories 返回 $($ids.Count) 个 ID, 取前 $MaxN"

        $topIds = $ids | Select-Object -First $MaxHN
        $i = 0
        foreach ($id in $topIds) {
            $i++
            $url = $baseUrl + "item/$id.json"
            try {
                $item = Invoke-RestMethod -Uri $url -TimeoutSec 8
                if ($item) {
                    $items += @{
                        id = $item.id
                        title = $item.title
                        url = $item.url
                        score = $item.score
                        by = $item.by
                        time = $item.time
                        descendants = $item.descendants
                        type = $item.type
                        source = 'Hacker News'
                    }
                }
            } catch {
                $failCount++
                Write-Host "[HN] item $id 失败: $_" -ForegroundColor Yellow
            }
            # 节流, 避免 API 限流
            if ($i % 10 -eq 0) { Start-Sleep -Milliseconds 200 }
        }

        if ($items.Count -eq 0) {
            Write-ErrorArchive -Layer 'HN_all_items' -ErrorMsg "30 个 item 全部失败 (failCount=$failCount)" -Status 'fail'
            return $null
        }

        Write-Host "[HN] 成功: $($items.Count) items (fail=$failCount)" -ForegroundColor Green
        return $items
    } catch {
        $err = $_.Exception.Message
        Write-Host "[HN] 异常: $err" -ForegroundColor Red
        Write-ErrorArchive -Layer 'HN_topstories' -ErrorMsg $err -Status 'fail'
        return $null
    }
}

# ============== 2. AI 官方博客 RSS (4 家) ==============
$rssUrls = @(
    @{ name = 'OpenAI'; url = 'https://openai.com/blog/rss.xml' },
    @{ name = 'Anthropic'; url = 'https://www.anthropic.com/news/rss.xml' },
    @{ name = 'GoogleAI'; url = 'https://blog.google/technology/ai/rss/' },
    @{ name = 'DeepSeek'; url = 'https://api-docs.deepseek.com/news/rss' }
)

function Get-AIRss {
    param([array]$Urls)

    if ($SkipRSS) {
        Write-Host "[RSS] 跳过 (SkipRSS 标志)"
        return @()
    }

    Write-Host "[RSS] 尝试 $($Urls.Count) 家 AI 官方博客..."
    $rssItems = @()
    $successCount = 0

    foreach ($entry in $Urls) {
        $name = $entry.name
        $url = $entry.url
        Write-Host "[RSS] $name ($url)..."

        try {
            $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15
            if ($resp.StatusCode -ne 200) {
                Write-Host "[RSS] $name HTTP $($resp.StatusCode)" -ForegroundColor Yellow
                Write-ErrorArchive -Layer "RSS_$name" -ErrorMsg "HTTP $($resp.StatusCode)" -Status 'partial'
                continue
            }

            $xml = [xml]$resp.Content
            $channel = $xml.rss.channel
            if (-not $channel) {
                Write-Host "[RSS] $name 无 channel 节点" -ForegroundColor Yellow
                Write-ErrorArchive -Layer "RSS_$name" -ErrorMsg '无 rss.channel 节点' -Status 'partial'
                continue
            }

            $count = 0
            foreach ($item in $channel.item) {
                if ($count -ge 10) { break }   # 每家最多 10 条
                $rssItems += @{
                    title = $item.title
                    link = $item.link
                    pubDate = $item.pubDate
                    description = if ($item.description) { ($item.description -replace '<[^>]+>', '').Trim() } else { '' }
                    source = "$name Blog"
                }
                $count++
            }
            $successCount++
            Write-Host "[RSS] ${name}: ${count} items" -ForegroundColor Green
        } catch {
            $err = $_.Exception.Message
            Write-Host "[RSS] $name 异常: $err" -ForegroundColor Yellow
            Write-ErrorArchive -Layer "RSS_$name" -ErrorMsg $err -Status 'partial'
        }
        Start-Sleep -Milliseconds 500
    }

    Write-Host "[RSS] 总结: $successCount/$($Urls.Count) 家成功, 共 $($rssItems.Count) items" -ForegroundColor $(if ($successCount -gt 0) { 'Green' } else { 'Yellow' })
    return $rssItems
}

# ============== 3. 合并 + 排序 + 写文件 ==============
function Merge-And-Save {
    param(
        [array]$HnItems,
        [array]$RssItems
    )

    $allItems = @()
    foreach ($h in $HnItems) { $allItems += $h }
    foreach ($r in $RssItems) { $allItems += $r }

    $total = $allItems.Count
    $hnCount = $HnItems.Count
    $rssCount = $RssItems.Count

    # 按发布时间降序 (HN 用 unix time, RSS 用 string, 分别排序后合并)
    $hnSorted = $HnItems | Sort-Object -Property { if ($_.time) { $_.time } else { 0 } } -Descending
    $rssSorted = @()
    foreach ($r in $RssItems) {
        $ts = 0
        if ($r.pubDate) {
            try { $ts = [DateTimeOffset]::Parse($r.pubDate).ToUnixTimeSeconds() } catch { $ts = 0 }
        }
        $rssSorted += @{ item = $r; ts = $ts }
    }
    $rssSorted = $rssSorted | Sort-Object -Property ts -Descending | ForEach-Object { $_.item }

    $output = @{
        采集时间 = $Timestamp
        来源 = $Source
        触发时间 = $Date
        总量 = $total
        分类统计 = @{
            hn = $hnCount
            rss = $rssCount
        }
        hn_items = $hnSorted
        rss_items = $rssSorted
        note = "凌晨 04:00 补采, 与 AINewsCollector_6h 互补; RSS 失败时仅保留 HN top $MaxHN"
    }

    # JSON
    $output | ConvertTo-Json -Depth 6 | Out-File -FilePath $OutputJson -Encoding UTF8
    Write-Host "[OK] JSON 写入: $OutputJson ($total items)"

    # 按次归档
    $output | ConvertTo-Json -Depth 6 | Out-File -FilePath $OutputSnapshot -Encoding UTF8
    Write-Host "[OK] 归档写入: $OutputSnapshot"

    # Markdown 摘要
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# AI News 凌晨补采 | $Date")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("**采集时间**: $Timestamp GMT+8")
    [void]$sb.AppendLine("**数据源**: Hacker News top $hnCount + AI 博客 RSS $rssCount")
    [void]$sb.AppendLine("**总量**: $total items")
    [void]$sb.AppendLine("")

    if ($hnSorted.Count -gt 0) {
        [void]$sb.AppendLine("## 🔥 Hacker News Top $hnCount")
        [void]$sb.AppendLine("")
        $i = 0
        foreach ($h in ($hnSorted | Select-Object -First 15)) {
            $i++
            $title = if ($h.title.Length -gt 80) { $h.title.Substring(0, 80) + '...' } else { $h.title }
            $url = if ($h.url) { $h.url } else { "https://news.ycombinator.com/item?id=$($h.id)" }
            $score = if ($h.score) { "★$($h.score)" } else { '' }
            $comments = if ($h.descendants) { "💬$($h.descendants)" } else { '' }
            [void]$sb.AppendLine("$i. [$title]($url) $score $comments")
        }
        [void]$sb.AppendLine("")
    }

    if ($rssSorted.Count -gt 0) {
        [void]$sb.AppendLine("## 📰 AI 官方博客 ($rssCount 条)")
        [void]$sb.AppendLine("")
        foreach ($r in ($rssSorted | Select-Object -First 20)) {
            $title = if ($r.title.Length -gt 80) { $r.title.Substring(0, 80) + '...' } else { $r.title }
            [void]$sb.AppendLine("- **$($r.source)**: [$title]($($r.link))")
        }
        [void]$sb.AppendLine("")
    }

    if ($total -eq 0) {
        [void]$sb.AppendLine("⚠️ **本轮无数据**, 详见 data/system/ainews-0400-errors.jsonl")
    }

    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("*来源: cron-ainews-0400 自动采集 | $Timestamp*")

    $mdContent = $sb.ToString()
    $mdContent | Out-File -FilePath $OutputMd -Encoding UTF8
    Write-Host "[OK] Markdown 写入: $OutputMd"

    return $total
}

# ============== Main ==============
$hnItems = Get-HNTop
$rssItems = Get-AIRss -Urls $rssUrls

if (-not $hnItems -and $rssItems.Count -eq 0) {
    # 全失败
    $err = 'HN + RSS 全部失败'
    Write-ErrorArchive -Layer 'main_all' -ErrorMsg $err -Status 'fail'

    # 写空壳, 避免下游 read 失败
    $empty = @{
        采集时间 = $Timestamp
        来源 = $Source
        触发时间 = $Date
        总量 = 0
        hn_items = @()
        rss_items = @()
        note = 'HN + RSS 全部失败, 见 data/system/ainews-0400-errors.jsonl'
    }
    $empty | ConvertTo-Json -Depth 4 | Out-File -FilePath $OutputJson -Encoding UTF8
    $empty | ConvertTo-Json -Depth 4 | Out-File -FilePath $OutputSnapshot -Encoding UTF8
    Write-Host "[FAIL] 全部失败, 已写空壳" -ForegroundColor Red
    exit 3
}

$total = Merge-And-Save -HnItems $hnItems -RssItems $rssItems

$elapsed = ((Get-Date) - $StartTime).TotalSeconds
if ($total -gt 0) {
    Write-Host "[OK] $Source success: $total items (hn=$($hnItems.Count), rss=$($rssItems.Count), ${elapsed}s)" -ForegroundColor Green
    Write-Host "[SUMMARY] date=$Date total=$total output=$OutputJson"
    exit 0
} else {
    Write-Host "[WARN] $Source 无数据 (${elapsed}s)" -ForegroundColor Yellow
    exit 2
}
