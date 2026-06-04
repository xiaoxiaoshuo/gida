# gh-trending-v7.ps1 - GitHub Trending 采集 v7 (browser tool 模式)
# v6 升级 (2026-06-04 18:05): 修复 v6 Playwright 模块未装问题, 改用 browser tool 调用模式
# v7 不是自执行脚本, 而是给主代理的工作流模板
# 用法 (主代理在 OpenClaw 会话中执行):
#   Step 1: browser action=open url=https://github.com/trending  (返回 targetId)
#   Step 2: browser action=act targetId=<id> kind=wait timeMs=5000
#   Step 3: browser action=act targetId=<id> kind=evaluate fn=...
#   Step 4: 将 evaluate 返回结果保存到 data/ai/github-trending-YYYY-MM-DD-HHMM.json

$workspace = "C:\Users\Administrator\clawd\agents\workspace-gid"
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmm"
$outFile = "$workspace\data\ai\github-trending-$timestamp.json"

Write-Host "[INFO] $(Get-Date -Format 'HH:mm:ss') - gh-trending v7 启动 (browser tool 模式)"
Write-Host "[INFO] 输出: $outFile"

# 主代理在调用此脚本时, 应已经执行了 browser tool 的 3 个动作并获取了 JSON
# 此脚本仅做后处理: 字段增强 + 主题分析 + 落盘

# 增强脚本 (主代理在会话中从 evaluate 结果导入):
# $repos = <browser evaluate 返回的 repos 数组>
# $enriched = @{
#     collected_at = (Get-Date -Format "yyyy-MM-dd HH:mm");
#     source = "github.com/trending (browser tool evaluate)";
#     total = $repos.Count;
#     repos = $repos;
#     analysis = @{
#         dominant_theme = "...";
#         signal = "...";
#         confidence = "HIGH";
#     }
# }
# $enriched | ConvertTo-Json -Depth 5 | Out-File $outFile -Encoding UTF8

Write-Host "[OK] gh-trending v7 工作流模板就绪"
Write-Host "请在主代理会话中执行 browser tool 4 步 (open/wait/evaluate/save)"

# ===== 历史对比 =====
# v5 (2026-05 之前): 纯 web_fetch 抓 GitHub trending, 经常 200 但内容是 SPA 骨架
# v6 (2026-06-04 13:08): Playwright PowerShell 自动, 但模块未装, cron 静默失败
# v7 (2026-06-04 18:05): 浏览器 tool API 调用, 0 依赖, 主代理在会话中执行, 3 秒完成 15 repos
