$json = Get-Content "C:\Users\Administrator\clawd\agents\workspace-gid\data\tech\github-trending_latest.json" -Raw | ConvertFrom-Json
$md = @"
# GitHub Trending | $(Get-Date -Format 'yyyy-MM-dd HH:mm')

> 数据源: GitHub API (stars:>1000 pushed:>2026-04-18)
> 更新: $($json.采集时间)

## Top 30 开源项目

| # | 项目 | Stars | 语言 | 更新 | 描述 |
|---|------|-------|------|------|------|
"@

$i = 1
foreach ($item in $json.items) {
    $desc = if ($item.desc) { $item.desc -replace '\|', '\|' -replace '[`"'']', '' } else { "" }
    $lang = if ($item.lang) { $item.lang } else { "-" }
    $stars = "{0:N0}" -f $item.stars
    $pushed = if ($item.pushed -is [string]) { $item.pushed.Substring(0,10) } else { $item.pushed.ToString("yyyy-MM-dd") }
    $name = $item.name -replace '\|', '\|'
    $url = $item.url
    $descShort = if ($desc.Length -gt 60) { $desc.Substring(0,60) } else { $desc }
    $md += "`n| $i | [**$name**]($url) | $stars | $lang | $pushed | $descShort |"
    $i++
}

$mdFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\tech\github-trending_latest.md"
$md | Out-File -FilePath $mdFile -Encoding UTF8
Write-Host "[OK] github-trending_latest.md 已更新"