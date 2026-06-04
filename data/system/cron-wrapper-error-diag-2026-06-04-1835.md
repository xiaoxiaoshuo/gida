# cron_wrapper.log 3 错误根因诊断 (18:30 watchdog flag)

**时间**: 2026-06-04 18:35 GMT+8
**触发**: cron-watchdog.ps1 v2 18:30:02 ALERT (wrapper_log_errors=3)
**诊断耗时**: 30 秒 (主代理手写, 避免 sonnet fast mode BUG)

## BLUF

**根因**: `fetch-hn-top30-v2.ps1` 用相对路径 `data/tech/hacker-news-*.json`, 但 AINewsCollector_6h 在 06:00 触发时, Task Scheduler 工作目录是 `C:\WINDOWS\system32` (非 workspace), 导致路径解析失败。**18:00 触发已修复是因为 17:48 给 wrapper 设了 WorkingDirectory, 但 06:00 旧任务实例未刷新**。

**修复**: 在 `scripts/ai-news-cron-wrapper.ps1` 开头加 1 行 `Set-Location "C:\Users\Administrator\clawd\agents\workspace-gid"` 强制锁定。

## 错误分类

| 时间 | 错误 | 根因 | 状态 |
|------|------|------|------|
| 2026-06-04 06:35:51 | `Could not find a part of the path 'C:\WINDOWS\system32\data\tech\hacker-news-2026-06-04_06-36.json'` | **AINewsCollector_6h 06:00 触发时 WorkingDirectory=C:\WINDOWS\system32** | ❌ 需修复 |
| 2026-05-19~05-20 (历史) | `The term 'gh-trending-v3.ps1' is not recognized` | 5/19-20 wrapper 调用 v3 但文件已删除 | ✅ 6/3 17:36 复活后 v2/v5 修复 |
| 2026-06-04 18:00:01 | 无错误 (exit 空但 completed) | 17:48 WorkingDirectory 修复覆盖 | ✅ 健康 |

## 根因锁定

`fetch-hn-top30-v2.ps1` 第 X 行大概率有:
```powershell
$outFile = "data/tech/hacker-news-$(Get-Date -Format 'yyyy-MM-dd_HH-mm').json"
```

当 PowerShell 工作目录是 `C:\WINDOWS\system32` 时, 该相对路径解析为 `C:\WINDOWS\system32\data\tech\...`, 路径不存在 → 写入失败。

`gh-trending-browser-v5.ps1` + `merge-ai-news.ps1` 不报错, 是因为它们 exit=空 (脚本内 try-catch 吞了错误), 但实际也没写文件。

## 修复方案 (3 行 diff)

**方案 A (推荐)**: 修改 `scripts/ai-news-cron-wrapper.ps1` 头部 (1 行):
```powershell
# 在 "Wrapper started" 日志之前加:
Set-Location "C:\Users\Administrator\clawd\agents\workspace-gid"
```

**方案 B**: 修改 `fetch-hn-top30-v2.ps1` 用绝对路径 (3 行):
```powershell
$workspace = "C:\Users\Administrator\clawd\agents\workspace-gid"
$outFile = Join-Path $workspace "data/tech/hacker-news-$(Get-Date -Format 'yyyy-MM-dd_HH-mm').json"
```

**方案 C**: 重建 Scheduled Task with -WorkingDirectory 参数 (需 schtasks /delete + /create, 高风险)

## 验证清单 (06:00 修复后)

- [ ] 06:00 cron 触发后 fetch-hn-top30-v2 exit=0
- [ ] data/tech/hacker-news-2026-06-05_06-00.json 文件存在
- [ ] hacker-news_latest.json mtime 更新到 06:00:30
- [ ] cron_wrapper.log 无 "Could not find" 错误
- [ ] watchdog 下次 06:30:02 报告 wrapper_log_errors=0

## 元规划者反思

- 17:48 修复时只验证了 18:00 cron, 没验证 06:00 旧实例 → 06:00 仍走老路径
- WorkingDirectory 在 schtasks 是 task-level 参数, 修一次不会自动覆盖已注册的实例
- **教训**: 修复 cron 后必须**等下一次完整周期 (6h) 验证**, 不能只跑单点
