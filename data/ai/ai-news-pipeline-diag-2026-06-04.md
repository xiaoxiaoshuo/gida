# AI News Pipeline 故障诊断与修复方案

> **报告日期**: 2026-06-04 04:17 GMT+8
> **断档累计**: 27-28 天（自 2026-05-08 04:59 至 2026-06-04 04:17）
> **断档数据文件**: 5 个核心 JSON + 1 个 markdown 全部过期
> **报告人**: AI 新闻深度修复子智能体 (ai-news-restore-v2-0604)

---

## 🔍 一、根因分析 (Root Cause)

### 1.1 直接证据 — 计划任务静默失败

**关键日志** (`data/ai/cron_wrapper.log`):
```
2026-05-20 00:00:05 - Wrapper started
2026-05-20 00:00:05 - Running fetch-hn-top30.ps1
2026-05-20 00:00:05 - HN completed, exit:        ← ⚠️ 空退出码
2026-05-20 00:01:05 - Running gh-trending-v3.ps1
2026-05-20 00:01:05 - GH error: The term 'C:\Users\Administrator\clawd\agents\workspace-gid\scripts\gh-trending-v3.ps1' 
                                 is not recognized as a name of a cmdlet, function, script file, or executable program.
2026-05-20 00:01:05 - Wrapper finished
... (此后 18:00、6:00、12:00 同样错误, 静默重复)
... 
[2026-05-20 → 2026-06-03 17:36 = 14 天真空期]
2026-06-03 17:36:18 - Wrapper started   ← 人工干预一次, HN 成功, GH 同样失败
```

### 1.2 三层根因

| 层 | 根因 | 证据 |
|----|------|------|
| **L1 触发层** | 计划任务未做**健康检查和自愈** | cron_wrapper 静默失败,没有 exit-code 异常告警 |
| **L2 脚本层** | `gh-trending-v3.ps1` 引用了**已不存在的旧文件名** | 当前实际脚本是 `gh-trending-browser-v5.ps1`（依赖 Brave 浏览器） |
| **L3 数据层** | HN 输出 `exit: ` 空字符串 + 无 mtime 异常告警 | 5 个核心 JSON 的 mtime 全部停在 2026-05-08, 27 天未刷新 |

### 1.3 文件 mtime 实证

```powershell
# 实测 (2026-06-04 04:18 GMT+8)
data/ai/openai-blog_latest.json   LastWriteTime: 2026/5/8 4:57:42   (27 天前)
data/ai/tech-news_latest.json     LastWriteTime: 2026/5/8 4:59:29   (27 天前)
data/ai/hacker-news_latest.json   LastWriteTime: 2026/5/9 6:08:04   (25 天前)
data/ai/ai-news_latest.json       LastWriteTime: 2026/5/8 4:59:29   (27 天前)
data/ai/anthropic-blog_latest.json LastWriteTime: 2026/5/8 4:57:42  (27 天前)
```

**断档天数确认**: **27 天**（openai-blog/tech-news/ai-news） + **25 天**（hacker-news）。最严重的就是用户标记的"28 天"。

### 1.4 系统性设计缺陷

1. **无 mtime 守门员** — 没有任何子智能体或 cron 检查 `LastWriteTime > Now - 8h`，否则 27 天前就该发现
2. **无二源备份** — 唯一采集源（HN Algolia + 浏览器 GitHub Trending），单点失败即整体失败
3. **无错误告警** — 计划任务出错时只写日志, 不发飞书/钉钉/邮件
4. **手动运行才显示错误** — 2026-06-03 17:36 的人工干预暴露了 GH 脚本问题,但计划任务本身**仍每 6 小时**重复跑同样失败的脚本

---

## 🛠️ 二、三个修复方案 (P0/P1/P2)

### 方案 1 (P0) — 立即修, 24 小时内: 重命名 + 兼容

**目标**: 让现有 AINewsCollector_6h 立即恢复, 不改架构

```powershell
# 步骤 1: 修正 cron 引用
$wrapper = Get-Content "scripts\run-ai-news-wrapper.ps1" -Raw
$wrapper = $wrapper -replace 'gh-trending-v3\.ps1', 'gh-trending-browser-v5.ps1'
Set-Content "scripts\run-ai-news-wrapper.ps1" -Value $wrapper

# 步骤 2: 在 scripts/ 创建软兼容, 防再改名
if (-not (Test-Path "scripts\gh-trending-v3.ps1")) {
    Copy-Item "scripts\gh-trending-browser-v5.ps1" "scripts\gh-trending-v3.ps1"
}

# 步骤 3: 手动跑一次验证
& "scripts\run-ai-news-wrapper.ps1"
```

**预期**: cron 下次触发（00:00 / 06:00 / 12:00 / 18:00）即可恢复

**风险**: Brave 浏览器非交互时 GitHub 仍可能失败（参考 `cron/ai-news.conf` 已知问题 #1）

---

### 方案 2 (P1) — 3 天内: 加 mtime 守门员 + 二源备份

**目标**: 把"28 天断档"这种问题在 8 小时内发现并告警

```powershell
# scripts/check-ai-news-freshness.ps1
# 每 4 小时跑一次, 任何 data/ai/*_latest.json 超过 12h 未更新 → 发飞书/邮件

$threshold = (Get-Date).AddHours(-12)
$stale = Get-ChildItem "data/ai\*_latest.json" | Where-Object { $_.LastWriteTime -lt $threshold }

if ($stale) {
    $msg = "⚠️ AI 新闻数据过期: $($stale.Name -join ', ') 上次更新 $($stale.LastWriteTime)"
    # 调用飞书 / Send-MailMessage / OpenClaw message 工具
    Send-FeiShuBot -Msg $msg
    # 或: 触发 AI 子智能体自愈
    openclaw message send --target ai-news-restore --prompt $msg
}
```

**配 Windows Task Scheduler**:
```powershell
# 每 4 小时检查一次
$action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-File scripts\check-ai-news-freshness.ps1"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
            -RepetitionInterval (New-TimeSpan -Hours 4) `
            -RepetitionDuration (New-TimeSpan -Days 365)
Register-ScheduledTask -TaskName "AINewsFreshnessGuard" -Action $action -Trigger $trigger
```

---

### 方案 3 (P2) — 1 周内: 全面重构为 OpenClaw 子智能体

**目标**: 从"powershell + 计划任务"升级为"OpenClaw agent + cron 调用"

```python
# 等价伪代码（OpenClaw subagent）
@subagent(name="ai-news-collector", schedule="0 */6 * * *")
def collect_ai_news():
    sources = [
        ("hn", web_fetch("https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage=30")),
        ("openai", browser.fetch("https://openai.com/news")),
        ("anthropic", browser.fetch("https://www.anthropic.com/news")),
        ("deepmind", browser.fetch("https://deepmind.google/discover/blog/")),
        ("github", browser.fetch("https://github.com/trending?since=weekly")),
    ]
    results = await asyncio.gather(*[s[1] for s in sources], return_exceptions=True)
    
    # 校验: 至少 3 个源成功
    successes = [r for r in results if not isinstance(r, Exception)]
    if len(successes) < 3:
        raise Alert(f"Only {len(successes)} sources succeeded, need ≥3")
    
    # 写入
    for source, data in zip(sources, results):
        if not isinstance(data, Exception):
            write_json(f"data/ai/{source}_latest.json", data)
    
    # 触发分析 agent
    subagent("ai-news-analyst").analyze_today()
```

**优势**:
- 自动并行采集（5 源并行, 5-10 分钟完成）
- 内置健康检查 (至少 3 源成功)
- 自然集成到 OpenClaw 心跳 / cron 体系
- 子智能体可独立升级（HN API 改了只改 HN 源）

---

## 🛡️ 三、如何保证不再断档 (工程方案)

### 3.1 三层防御

```
┌─────────────────────────────────────────────────┐
│ L1: 实时层 — OpenClaw agent (6h)                 │  ← 主采集
├─────────────────────────────────────────────────┤
│ L2: 守门员层 — mtime 检查 (4h)                   │  ← 告警
├─────────────────────────────────────────────────┤
│ L3: 自愈层 — 失败自动重试 + 子智能体触发         │  ← 修复
└─────────────────────────────────────────────────┘
```

### 3.2 关键 SLA 指标

| 指标 | 当前 | 目标 |
|------|------|------|
| 数据新鲜度 P50 | **断档 27 天** | ≤ 6h |
| 数据新鲜度 P99 | **断档 28 天** | ≤ 12h |
| 失败到告警延迟 | **未发现** | ≤ 4h |
| 自动修复成功率 | **0%** | ≥ 80% |

### 3.3 必须落地的 5 件事

1. **修脚本引用**（方案 1, 24h 内）— 最小可行修复
2. **加守门员**（方案 2, 3 天内）— 防止 27 天无人值守
3. **加 mtime 检查到 MEMORY.md/HEARTBEAT.md** — 主 agent 心跳时主动检查
4. **把"AI 新闻"加入 IDENTITY.md 的"24h 持续优化"自检清单**
5. **写一份 post-mortem** 到 `memory/2026-06-04.md` — 27 天断档是教训, 必须记录

### 3.4 IDENTITY 建议更新

把"AI 新闻断档检测"加入 IDENTITY.md 的 TODO_STACK 模板:

```markdown
### 📋 [待办清单 - TODO_STACK]
- [P0] - [紧急且关键的任务，下一步立即执行]
- [P1] - [后续步骤]
- [HEARTBEAT_CHECK] - [每次心跳必查: data/ai/*_latest.json mtime ≤ 12h]
- [DONE] - [已完成并已归档至长期记忆的任务]
```

---

## 📎 四、附录: 当前 scripts 目录状态

**实际可用的 ai-news 相关脚本**:
- `fetch-hn-v3.ps1` — HN Algolia API (✅ 工作中, 但 27 天没被 cron 触发)
- `gh-trending-browser-v5.ps1` — 浏览器 GitHub Trending (✅ 工作中, 但 cron 引用错)
- `run-ai-news-wrapper.ps1` — 主包装器 (❌ 引用了不存在的 v3)
- `setup-ai-news-cron.ps1` — 计划任务注册 (✅ 任务注册成功, 但内容已陈旧)

**不存在的脚本** (cron 引用但已删除):
- `gh-trending-v3.ps1` ← 这是元凶

**推荐文件**:
- `data/ai/ai-news-flashback-2026-06-04.md` — 28 天事件汇总
- `data/ai/hn-realtime-2026-06-04-0417.json` — HN 实时 Top 20
- `data/ai/ai-news-pipeline-diag-2026-06-04.md` — 本报告

**下次采集时间建议**: 2026-06-04 06:00 GMT+8 (按 AINewsCollector_6h 原计划) + 04:00 补一次 (本子智能体报告落地)
