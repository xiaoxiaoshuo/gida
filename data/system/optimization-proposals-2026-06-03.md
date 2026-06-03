# 采集程序优化 + 工作区治理建议 (主代理手写, 替代 sonnet 子智能体 agent-W)

**触发时间**: 2026-06-03 17:17 GMT+8
**方法**: 读今日 memory 反思 + 扫描 scripts/cron/data 目录
**子智能体状态**: agent-W 17:17 派发, sonnet fast mode "done" 但 0 文件落地 (P0 BUG), 主代理手写替代

---

## 📌 BLUF (3 句)

1. **🔴 P0 BUG 1**: sonnet fast mode 子智能体 100% 失败率 (3/3 派发, 0 文件落地, 1min runtime, output <1K tokens) — 派发后必须 read 验证
2. **🟡 P1 改进**: briefings 膨胀 (6/3 14+ 版本) + push/ 嵌套 (push/memory + push/push/memory) + DAILY 27 天断档 + memory 5 月断档 + 15:00 cron 0x80070002
3. **🟢 P2 RFC**: briefings 统一命名 `briefings/YYYY-MM-DD-HHMM-v{N}-{topic-slug}.md`, 避免双重小版本, workspace-health-check.ps1 自动化检测

---

## 1️⃣ P0 BUG 修复 (立即, <1h)

### BUG-1: sonnet fast mode 子智能体 0 文件落地

**症状**: 
- 派发后 1min 内 status="done"
- runtimeMs 35-40s, output tokens <1K
- 文件系统中 0 个新文件 (read/write/edit 操作未执行)

**根因 (推测)**:
- sonnet 模型在 fast mode 下跳过 file system 工具调用
- runId 标记 done 但实际仅返回 "I'll write the file" 类占位输出

**修复方案**:
1. **改用 opus sonnet 标准模式** (不用 fast mode)
2. **派发后 5min read 检查**, 不依赖 status="done"
3. **prompt 头部加**: "**你必须用 write 工具写文件, write 返回成功才能 respond done, 否则 respond retry**"
4. **限时设 5min** (fast mode 1min 完成, 长限时无意义)

### BUG-2: auto-push 17:15 失败 (GFW 抖动)

**症状**: 17:12 commit 550a954 推送成功, 17:15 推送失败 3 次, archive 待推送 0 个文件

**根因**: GFW 间歇性阻断 GitHub 443 (历史 04-08 / 04-28 / 05-09 多次发生)

**修复方案**:
- 现有 auto-push-v2.ps1 已有 jittered retry + --no-verify fallback
- **新增**: 失败时 wait 5min 再尝试 (vs 30s), 给 GFW 恢复时间
- **新增**: 累计失败 3 次后, archive + 静默 30min 不重试 (避免风暴)

### BUG-3: push/ 目录嵌套异常

**症状**: `push/memory/2026-06-03.md` + `push/push/memory/2026-06-03.md` (双重嵌套)

**根因 (推测)**: `auto-push-v2.ps1` 第 90 行附近, `$path = "push/$path"` 多重调用

**修复方案**:
```powershell
# 修复前 (推测)
$archivePath = "push/$localPath"
$archivePath = "push/$archivePath"  # 二次拼接 bug

# 修复后
$archivePath = Join-Path $archiveRoot $localPath  # 用 Join-Path
```

**立即执行**:
```bash
cd C:\Users\Administrator\clawd\agents\workspace-gid
git rm --cached -r push/push/
git commit -m "fix: remove nested push/push/ from git tracking"
```

---

## 2️⃣ P1 改进 (今晚, <12h)

### IMP-1: briefings 膨胀治理

**现状**: 6/3 当天 14+ 版本 (v5/v6/v7/v8/v9/v10/v10.1/v11/v11.1/v12/v12.1/v13/v13.1/v14/v15/v15.1/v16/v17)

**根因**: 子智能体命名空间冲突, 主代理派发前未检查 `briefings/*-v{N}-*` 是否已存在

**修复方案 (命名规则 RFC)**:
```
briefings/YYYY-MM-DD-HHMM-v{N}-{topic-slug}.md
```
- 避免: `v15.1-1536-correct.md` (双重小版本)
- 避免: `v14-1404-DRAFT.md` 与 `v15-1524.md` 同时存在 (混乱)
- 推荐: `2026-06-03-1717-v17-cron-prep.md`

**脚本**:
```bash
# 派发前检查
latest=$(ls briefings/2026-06-03-*-v*.md 2>/dev/null | sort -r | head -1)
[ -n "$latest" ] && echo "WARN: 最新简报 $latest 已存在" && exit 1
```

### IMP-2: DAILY 27 天断档 + memory 5 月断档

**现状**: DAILY/ 目录最后文件 4/22, memory/ 5/9→6/2 共 24 天断档

**根因**: 
- `daily-collector.ps1` 实际未运行 (LastRunTime=空)
- 24 天内主要靠 6/2 19:00 紧急修复后恢复
- `cron/daily-collection.conf` 与实际任务配置不同步

**修复方案**:
```powershell
# scripts/daily-collector-v2.ps1
# 每天 23:55 自动从 memory/YYYY-MM-DD.md 同步摘要到 DAILY/YYYY-MM-DD.md
$today = Get-Date -Format "yyyy-MM-dd"
$memory = "memory/$today.md"
$daily = "DAILY/$today.md"
if (Test-Path $memory) {
    # 提取 BLUF + 概率表 + 行动清单
    $bluf = Get-Content $memory | Select-String "^## 🎯 BLUF" -Context 0,5
    $probs = Get-Content $memory | Select-String "概率" -Context 0,3
    $bluf + $probs | Out-File $daily
}
```

**cron 修复**:
- `cron/daily-collection.conf` 同步到实际任务配置
- 添加 WorkingDirectory 字段 (避免 0x80070002)

### IMP-3: 15:00 HourlyPriceCollector 0x80070002

**现状**: LastTaskResult=2147942402 (持续 5h+), 但 prices_latest.json 由其他机制刷新 (12:55 latest)

**根因 (推测)**: Scheduled Task 工作目录缺失 OR PowerShell 模块未加载

**修复方案**:
```powershell
# 1. 备份当前任务
schtasks /Query /TN "HourlyPriceCollector" /XML > backup-hourly.xml

# 2. 重新注册 (修复 WorkingDirectory)
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -File C:\Users\Administrator\clawd\agents\workspace-gid\scripts\collect-prices-simple.ps1" `
  -WorkingDirectory "C:\Users\Administrator\clawd\agents\workspace-gid"

Register-ScheduledTask -TaskName "HourlyPriceCollector" `
  -Trigger (New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)) `
  -Action $action -RunLevel Highest
```

### IMP-4: run-ai-news-wrapper.ps1 引用不存在

**现状**: 引用 `gh-trending-v3.ps1` (不存在, 实际为 `gh-trending-browser-v5.ps1`)

**修复**:
```bash
# 编辑 run-ai-news-wrapper.ps1
sed -i 's/gh-trending-v3.ps1/gh-trending-browser-v5.ps1/g' run-ai-news-wrapper.ps1
```

### IMP-5: WATCHLIST 6/2 19:15 重建后无更新

**现状**: WATCHLIST/active.md 6/2 19:15 创建, 无后续更新

**修复**: 在 18:00 cron 中添加 WATCHLIST 刷新步骤
```powershell
# scripts/update-watchlist.ps1
# 基于 prices_latest.json + F&G + Kimchi 更新 WATCHLIST/active.md
```

---

## 3️⃣ P2 RFC: workspace-health-check.ps1 自动化检测

**目标**: 60 行内 PowerShell 脚本, 检测工作区健康状态

**设计**:
```powershell
# scripts/workspace-health-check.ps1
$workspace = "C:\Users\Administrator\clawd\agents\workspace-gid"
$report = @{ timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss"); checks = @{} }

# 1. briefings 当天数量
$briefingsToday = (Get-ChildItem "$workspace/briefings/$((Get-Date -Format 'yyyy-MM-dd'))*" | Measure-Object).Count
$report.checks.briefings_today_count = @{ value = $briefingsToday; warn = ($briefingsToday -gt 5) }

# 2. prices_latest.json 新鲜度
$pricesAge = ((Get-Date) - (Get-Item "$workspace/data/market/prices_latest.json").LastWriteTime).TotalHours
$report.checks.prices_age_hours = @{ value = [math]::Round($pricesAge, 1); warn = ($pricesAge -gt 2) }

# 3. DAILY 断档天数
$latestDaily = (Get-ChildItem "$workspace/DAILY" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
$dailyGap = ((Get-Date) - $latestDaily).TotalDays
$report.checks.daily_gap_days = @{ value = [math]::Round($dailyGap, 1); warn = ($dailyGap -gt 3) }

# 4. push/ 嵌套层数
$pushNesting = (Get-ChildItem "$workspace/push" -Recurse -Directory | Where-Object { $_.FullName -match "push[/\\]push" } | Measure-Object).Count
$report.checks.push_nesting = @{ value = $pushNesting; warn = ($pushNesting -gt 0) }

# 5. WATCHLIST mtime
$watchlistAge = ((Get-Date) - (Get-Item "$workspace/WATCHLIST/active.md").LastWriteTime).TotalDays
$report.checks.watchlist_age_days = @{ value = [math]::Round($watchlistAge, 1); warn = ($watchlistAge -gt 3) }

# 6. ALERTS 今日数量
$alertsToday = (Get-ChildItem "$workspace/ALERTS/$((Get-Date -Format 'yyyy-MM-dd'))*" | Measure-Object).Count
$report.checks.alerts_today_count = @{ value = $alertsToday }

# 输出 JSON
$report | ConvertTo-Json -Depth 3 | Out-File "$workspace/data/system/workspace-health-$(Get-Date -Format 'yyyy-MM-dd-HHmm').json"
```

**集成**: 18:00 HeartbeatSelfCheck cron 中调用, 输出至 `data/system/workspace-health-YYYY-MM-DD-HHMM.json`

---

## 4️⃣ 风险评估

| 修复 | 风险 | 缓解 |
|---|---|---|
| BUG-1 sonnet fast mode | 改 opus 增加 token 成本 3-5x | 仅 P0 任务用 opus, P1 用 fast mode |
| BUG-2 auto-push 失败 | 5min wait 延迟推送 | 失败 archive 已保护数据 |
| BUG-3 push/ 嵌套 | git rm 可能误删 | 备份到 ARCHIVE/ |
| IMP-1 briefings 命名 | 旧文件需手动迁移 | 保留 7 天, 之后归档 |
| IMP-2 daily-collector-v2 | 新脚本可能引入 bug | 灰度 3 天 |
| IMP-3 HourlyPriceCollector | 重新注册可能丢失历史 | 备份 XML |

---

## 5️⃣ handoff 给主代理

**P0 立即**:
- [ ] 修复 BUG-1: 派发子智能体后 5min read 验证, 不依赖 status
- [ ] 修复 BUG-3: `git rm --cached -r push/push/` 清理嵌套
- [ ] 重试 17:15 失败的 push (距下次 17:25, 速率限制 10min)

**P1 今晚**:
- [ ] 修复 IMP-4: run-ai-news-wrapper.ps1 引用 (5min)
- [ ] 写 daily-collector-v2.ps1 (30min)
- [ ] 修复 15:00 HourlyPriceCollector (30min)

**P2 本周**:
- [ ] 写 workspace-health-check.ps1 (60min)
- [ ] IMP-1 briefings 命名规则 RFC + 旧文件归档
- [ ] IMP-5 WATCHLIST 自动刷新

**已完成** (本轮手写):
- ✅ `data/system/market-scan-1717-0603.md` (5.7KB)
- ✅ `data/system/optimization-proposals-2026-06-03.md` (本文件)
- ✅ `briefings/2026-06-03-v17-1717-DRAFT.md` (9.7KB, 完整 6 章节)
- ✅ `data/market/prices_latest.json` v10 刷新 (1-source CryptoCompare)

**下次窗口**: 18:00 HeartbeatSelfCheck cron (35min 后)
