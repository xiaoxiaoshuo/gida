# fetch-github-trending-recent.ps1
# 拉取 GitHub 上"近期创建 + 有热度"的 trending 仓库 (5月1日之后)
# 解决 GWF 无法直接访问 github.com 的问题 — 通过 api.github.com (已被验证可达)
[CmdletBinding()]
param(
    [string]$Query = "created:>2026-05-01+stars:>50",
    [int]$PerPage = 30
)

$headers = @{
    "User-Agent" = "gida-meta-planner"
    "Accept"     = "application/vnd.github+json"
}
$url = "https://api.github.com/search/repositories?q=$Query&sort=stars&order=desc&per_page=$PerPage"

try {
    $resp = Invoke-RestMethod -Uri $url -TimeoutSec 30 -Headers $headers
    Write-Host "[OK] total: $($resp.total_count)  returned: $($resp.items.Count)"

    $items = @()
    foreach ($x in $resp.items) {
        $items += @{
            repo     = $x.full_name
            stars    = $x.stargazers_count
            forks    = $x.forks_count
            language = $x.language
            desc     = if ($x.description) { $x.description.Substring(0, [Math]::Min(120, $x.description.Length)) } else { "" }
            topics   = $x.topics
            created  = $x.created_at
            pushed   = $x.pushed_at
            html_url = $x.html_url
        }
    }

    $output = @{
        采集时间 = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss+08:00")
        总量     = $resp.total_count
        query    = "$Query sort:stars desc"
        items    = $items
    } | ConvertTo-Json -Depth 6

    $ts = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $archPath = "C:\Users\Administrator\clawd\agents\workspace-gid\data\tech\github-trending-2026-05-created-$ts.json"
    $latestPath = "C:\Users\Administrator\clawd\agents\workspace-gid\data\tech\github-trending_latest.json"
    $output | Out-File -FilePath $archPath -Encoding UTF8
    $output | Out-File -FilePath $latestPath -Encoding UTF8
    Write-Host "[OK] saved: $archPath"
    Write-Host "[OK] saved: $latestPath"
    Write-Host ""
    Write-Host "=== Top 10 ==="
    $items | Select-Object -First 10 | ForEach-Object {
        Write-Host ("  ★{0,7} {1,-50} ({2})" -f $_.stars, $_.repo, $_.language)
    }
}
catch {
    Write-Host "[FAIL] $($_.Exception.Message)"
    exit 1
}
