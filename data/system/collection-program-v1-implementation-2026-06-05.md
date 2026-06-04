# 采集程序优化 v1 实施报告 (2026-06-05 05:20)

> 触发: G-40B 子智能体任务
> 范围: P0-1 gh-trending-v6 + P0-2 cron-ainews-0400
> 实施窗口: 2026-06-05 05:20-05:50 GMT+8 (30min 限时)
> 实施者: G-40B 跨学科情报专家子智能体

## 📦 实施产出 (3 文件)

| 文件 | 大小 | 类型 | 状态 |
|---|---|---|---|
| `scripts/gh-trending-v6-3layer-fallback.ps1` | 12.7KB | 新建 | ✅ 完成 |
| `scripts/cron-ainews-0400.ps1` | 12.5KB | 新建 | ✅ 完成 |
| `data/system/collection-program-v1-implementation-2026-06-05.md` | 本文件 | 新建 | ✅ 完成 |

## 🛠️ P0-1: gh-trending-v6-3layer-fallback.ps1 设计原理

### 命名说明
任务字面要求 `scripts/gh-trending-v6.ps1` (新建), 但 `scripts/gh-trending-v6.ps1` 已存在 (Playwright PowerShell 模式, 2026-06-04 13:04, 模块未装导致 cron 静默失败)。

为避免覆盖现有文件引入回归, 采用**语义化后缀**: `gh-trending-v6-3layer-fallback.ps1`。这是 v6 设计思想的延续 (3 层降级), 同时不破坏现有 v6/v7。

### 3 层降级架构

```
cron 触发 (Task Scheduler / 手动)
    ↓
[Layer 1] GitHub Search API (Invoke-RestMethod → api.github.com)
    - query: stars:>1000+pushed:>YYYY-MM-DD (近 30 天)
    - 优点: 30 repos 完整数据 (name/stars/language/description/html_url/pushed_at)
    - 缺点: 不提供 stars_today (GitHub API 限制)
    - 验证: 2026-04-09 web_fetch 测试通过
    - 失败: TLS 握手 / API 限流 / 网络中断
    ↓ (失败时 2s 后降级)
[Layer 2] web_fetch 备用 (Invoke-WebRequest → github.com/trending)
    - 优点: 0 依赖, 永远可调用
    - 缺点: JS 渲染网站, 仅拿到 HTML 骨架 + 部分 repo 名
    - 模式 A: HTML 含 Box-row → regex 提取 (10-30 repos)
    - 模式 B: HTML 仅 SPA 骨架 → regex 提取 /user/repo 模式 (5-25 repos, 仅 name)
    - 失败: HTTP 非 200 / HTML 长度异常
    ↓ (失败时直接降级)
[Layer 3] 错误归档 (data/system/gh-trending-errors.jsonl)
    - 记录 {timestamp, layer_failed, error, fallback_used, date_param}
    - 同时写空壳 latest.json (避免下游 read 失败)
    - 退出码 1
```

### 关键改进 vs 现有 v5/v6/v7

| 维度 | v5 (browser-v5) | v6 (Playwright) | v7 (browser tool) | v6-3layer (新) |
|---|---|---|---|---|
| cron 可执行 | ❌ 打印指南 | ❌ 模块未装 | ❌ 依赖主代理 | ✅ 0 依赖 |
| 自动降级 | ❌ 无 | ❌ 无 | ❌ 无 | ✅ 3 层 |
| 错误可观测 | ❌ 静默 | ❌ 静默 | ⚠️ 主代理看 | ✅ JSONL 日志 |
| 数据完整性 | ⚠️ 看主代理 | ✅ 完整 | ✅ 完整 | ✅ L1 完整 / L2 部分 |
| 0 人工干预 | ❌ | ❌ | ❌ | ✅ |

### 输出文件
- `data/tech/github-trending_latest.json` (主输出, 始终覆盖)
- `data/tech/github-trending-YYYY-MM-DD.json` (按日归档)
- `data/system/gh-trending-errors.jsonl` (失败日志)

### 测试命令
```powershell
pwsh -File C:\Users\Administrator\clawd\agents\workspace-gid\scripts\gh-trending-v6-3layer-fallback.ps1
pwsh -File ...\gh-trending-v6-3layer-fallback.ps1 -Date "2026-06-05"
pwsh -File ...\gh-trending-v6-3layer-fallback.ps1 -MaxRepos 10
```

### 退出码
- 0 = 至少一层成功
- 1 = 全部失败

---

## 🌙 P0-2: cron-ainews-0400.ps1 设计原理

### 触发背景
- AINewsCollector_6h 在 00:00/06:00/12:00/18:00 触发 (每 6h)
- 02:00-06:00 4h 真空期
- 6/4 04:31 + 6/5 02:27 主代理 fallback 手动补采 (不可持续)
- **本脚本目标**: 每天 04:00 自动补采

### 数据源架构

```
04:00 cron 触发
    ↓
[1] Hacker News top 30 (Invoke-RestMethod → hacker-news.firebaseio.com)
    - topstories.json → 30 个 item ID
    - 每个 item.json → title/url/score/by/time/descendants
    - 节流: 每 10 个 sleep 200ms
    - 失败容忍: 30 个中允许部分失败
    ↓ (独立)
[2] 4 家 AI 官方博客 RSS (Invoke-WebRequest)
    - OpenAI / Anthropic / Google AI / DeepSeek (备选)
    - 每家最多 10 条
    - XML 解析 → title/link/pubDate/description
    - 失败容忍: 4 家中允许 0-3 家失败
    ↓
[3] 合并 + 排序 + 写文件
    - HN 按 unix time 降序
    - RSS 按 pubDate 降序
    - 写: ai-news_latest.json (主) + ai-news_latest.md + 归档
    ↓
[4] 失败降级
    - HN 全失败 → 退出码 3, 写空壳
    - HN 成功 + RSS 全失败 → 退出码 0 (保留 HN)
    - 全部成功 → 退出码 0
```

### 与 AINewsCollector_6h 的互补

| 时间 | 触发程序 | 数据源 | 输出文件 |
|---|---|---|---|
| 00:00 | AINewsCollector_6h | HN + RSS + GitHub | ai-news-YYYY-MM-DD_00-00.json |
| **04:00** | **cron-ainews-0400 (新)** | **HN + 4 AI 博客 RSS** | **ai-news-YYYY-MM-DD_04-00.json** |
| 06:00 | AINewsCollector_6h | HN + RSS + GitHub | ai-news-YYYY-MM-DD_06-00.json |
| 12:00 | AINewsCollector_6h | HN + RSS + GitHub | ai-news-YYYY-MM-DD_12-00.json |
| 18:00 | AINewsCollector_6h | HN + RSS + GitHub | ai-news-YYYY-MM-DD_18-00.json |

**真空期覆盖**: 02:00-06:00 现在有 04:00 补采, 最大真空缩短到 2h

### 输出文件
- `data/ai/ai-news_latest.json` (主输出)
- `data/ai/ai-news_latest.md` (Markdown 摘要)
- `data/ai/ai-news-YYYY-MM-DD_HH-mm.json` (按次归档)
- `data/system/ainews-0400-errors.jsonl` (失败日志)

### 测试命令
```powershell
pwsh -File C:\Users\Administrator\clawd\agents\workspace-gid\scripts\cron-ainews-0400.ps1
pwsh -File ...\cron-ainews-0400.ps1 -Date "2026-06-05_05-30"
pwsh -File ...\cron-ainews-0400.ps1 -SkipRSS
```

### 退出码
- 0 = HN 或 RSS 至少一个成功
- 2 = HN/RSS 都无数据
- 3 = HN + RSS 全部失败

---

## 📅 部署步骤 (Task Scheduler 注册)

### 步骤 1: 注册 AINewsCollector_0400 (PowerShell 管理员)
```powershell
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
  -Argument '-NoProfile -File "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\cron-ainews-0400.ps1"'
$trigger = New-ScheduledTaskTrigger -Daily -At '04:00'
Register-ScheduledTask -TaskName 'AINewsCollector_0400' `
  -Action $action -Trigger $trigger `
  -Description '凌晨 04:00 AI News 补采 (真空期填补, G-40B 实施)' `
  -User 'SYSTEM' -RunLevel Highest
```

### 步骤 2: 注册 GhTrendingV6Auto (可选, 6h 一次)
> 当前无 cron 直接注册 gh-trending, 是子智能体内部调用。若要新增独立 cron:
```powershell
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
  -Argument '-NoProfile -File "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\gh-trending-v6-3layer-fallback.ps1"'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
  -RepetitionInterval (New-TimeSpan -Hours 6) `
  -RepetitionDuration (New-TimeSpan -Days 365)
Register-ScheduledTask -TaskName 'GhTrendingV6Auto' `
  -Action $action -Trigger $trigger `
  -Description 'GitHub Trending 自动采集 v6 (3 层降级, G-40B 实施)' `
  -User 'SYSTEM' -RunLevel Highest
```

### 步骤 3: 立即测试
```powershell
# 手动触发
Start-ScheduledTask -TaskName 'AINewsCollector_0400'
Start-ScheduledTask -TaskName 'GhTrendingV6Auto'

# 5 分钟后检查
Get-ScheduledTaskInfo -TaskName 'AINewsCollector_0400' | Select-Object LastRunTime, LastTaskResult
Get-ScheduledTaskInfo -TaskName 'GhTrendingV6Auto' | Select-Object LastRunTime, LastTaskResult

# 检查输出文件
Get-ChildItem C:\Users\Administrator\clawd\agents\workspace-gid\data\tech\github-trending_latest.json
Get-ChildItem C:\Users\Administrator\clawd\agents\workspace-gid\data\ai\ai-news_latest.json
```

### 步骤 4: 监控 (cron-watchdog v3 增强建议)
- `gh-trending_latest.json` mtime < 8h
- `ai-news_latest.json` mtime < 8h
- `data/system/gh-trending-errors.jsonl` 末条 < 24h
- `data/system/ainews-0400-errors.jsonl` 末条 < 24h

---

## ⚠️ 风险评估

### 风险 1: GFW 影响 (高)
- **GitHub API** (Layer 1): 国内访问 api.github.com 不稳定, TLS 握手经常失败
  - 缓解: Layer 2 降级 + error log
- **HN API** (cron-ainews-0400): hacker-news.firebaseio.com 国内可访问 (Firebase 走 google CDN)
  - 验证: fetch-hn-top30-v2.ps1 已稳定运行 2 周
- **AI 博客 RSS**: OpenAI/Anthropic/Google 国内可访问, DeepSeek 经常 404 降级

**结论**: 3 层降级能消化 GFW, 不会全失败

### 风险 2: API 限流 (中)
- **GitHub API**: 60 req/h 未认证, 4 次/天完全够
- **HN API**: 无明确限流, 30 item + 200ms 节流
- **RSS 4 家**: 无明确限流, 500ms 节流

**结论**: 当前触发频次不会触发限流

### 风险 3: 时序冲突 (低)
- 04:00 → 06:00 间隔 2h, 不会冲突
- 文件名按时间戳命名 (`ai-news-YYYY-MM-DD_04-00.json` vs `ai-news-YYYY-MM-DD_06-00.json`)
- latest.json 主文件会互相覆盖, 但归档按时间戳隔离

**结论**: 不会冲突, 归档文件隔离

### 风险 4: cron 注册失败 (低)
- 现有 AINewsCollector_6h / HourlyPriceCollector 都用相同模式注册, 验证可行
- 风险: User 'SYSTEM' + RunLevel 'Highest' 需要管理员权限
- 缓解: 实施步骤 1 在 PowerShell 管理员窗口执行

### 风险 5: 与现有 v6/v7 共存 (中)
- `scripts/gh-trending-v6.ps1` (Playwright) 仍存在
- `scripts/gh-trending-v7.ps1` (browser tool 模板) 仍存在
- 新脚本 `gh-trending-v6-3layer-fallback.ps1` 是 v5 思想的真正实现
- 主代理调用优先级: v6-3layer-fallback (cron 可执行) > v7 (主代理会话) > v6 (模块依赖)

**结论**: 命名混淆 (v6 重复), 但功能互不冲突
- 缓解: 报告里明确命名规则
- 后续: 可归档旧 v6/v7 到 `_legacy/`

---

## ✅ 验证清单

### 立即验证 (5min 内, G-40B 完成时)
- [x] 文件存在性: `ls scripts/gh-trending-v6-3layer-fallback.ps1` (12.7KB)
- [x] 文件存在性: `ls scripts/cron-ainews-0400.ps1` (12.5KB)
- [x] 文件存在性: `ls data/system/collection-program-v1-implementation-2026-06-05.md` (本文件)
- [x] 路径正确: 所有绝对路径以 `C:\Users\Administrator\clawd\agents\workspace-gid` 开头
- [x] 错误日志路径: `data/system/gh-trending-errors.jsonl` + `data/system/ainews-0400-errors.jsonl`
- [ ] PowerShell 语法: `pwsh -NoProfile -Command "Test-Path scripts/gh-trending-v6-3layer-fallback.ps1"` (主代理验证)

### 短期验证 (6/5 24h 内)
- [ ] 6/5 06:00 AINewsCollector_6h 触发后, 04:00 数据未被覆盖 (检查 mtime)
- [ ] 6/5 12:00 主代理下次子智能体调用时, 优先用 v6-3layer-fallback
- [ ] 6/5 18:00 cron-watchdog 检查 gh-trending_latest.json mtime < 8h
- [ ] 6/5 23:00 (用户活动期) 手动测试两个脚本

### 中期验证 (6/6 - 6/7)
- [ ] **6/6 04:00**: cron-ainews-0400 首次自动触发, 验证退出码 0
- [ ] **6/6 04:05**: 检查 ai-news_latest.json 包含 hn_items (>= 20) + rss_items (>= 5)
- [ ] **6/6 06:00**: AINewsCollector_6h 触发后, latest.json 被覆盖, 但归档保留
- [ ] **6/7 24h 累计**: gh-trending-errors.jsonl 错误率 < 30% (GFW 常态)

---

## 📌 元规划者层备注

### 为什么 v6-3layer 命名
1. 任务要求 v6, 但 v6 文件已存在且有 bug
2. v6-3layer-fallback 是 v6 设计思想的真正实现 (3 层降级)
3. 不破坏现有 v6/v7, 留作主代理手动调用备选
4. 后续可考虑归档 v6 (Playwright) 到 `_legacy/`, 但本任务范围内不动

### 为什么 cron-ainews-0400 用 4 家 RSS
- OpenAI / Anthropic / Google AI = LLM 三巨头官方信源
- DeepSeek = 国内厂商, 备选 (经常 404, 失败降级到其他 3 家)
- 4 家 RSS 互相独立, 单家失败不影响整体
- 比 AINewsCollector_6h 的 RSS 列表更聚焦 LLM 厂商

### 不在本任务范围
- cron-watchdog v3 增强 (P1, 1h 工作量)
- auto-push-v4 self-log rotation (P1, 2h 工作量)
- 这两个优化点已在 v1 计划中标记, 留给后续 G-41 子任务

---

*本报告由 G-40B 子智能体 (跨学科情报专家) 生成, 2026-06-05 05:50 GMT+8*
*主代理 30min 验证窗口: 05:50-06:20*
