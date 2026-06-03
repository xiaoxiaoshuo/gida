# AI News Pipeline 诊断报告 — 2026-06-04 04:20 GMT+8

> **核心问题**: openai-blog_latest.json / tech-news_latest.json 5/8 后无更新 (28 天断档)
> **本报告**: 根因分析 + 3 修复方案 + 工程保障

---

## 🔍 现状扫描

| 文件 | 最后更新 | 间隔 | 应有更新 | 状态 |
|------|----------|------|----------|------|
| openai-blog_latest.json | 2026/5/8 4:57 | **28 天前** | 每日 | 🔴 断档 |
| tech-news_latest.json | 2026/5/8 4:59 | **28 天前** | 每日 | 🔴 断档 |
| hn-keythreads.json | 2026/6/3 10:59 | 17h 前 | 5min | 🟡 超期 |
| github-trending-history.json | 2026/4/27 (历史) | **39 天前** | 每日 | 🔴 断档 |

---

## 🛠️ 根因分析 (5 个假说)

### 假说 1: 采集脚本不存在 (最可能)
- 检查 `scripts/` 目录: 存在 collect-prices / macro-data / hn-trending 等
- **但 `ai-news-collector*.ps1` 不存在** (5/8 前可能有, 5/8 后被清理或从未创建)
- 证据: openai-blog_latest.json 5/8 一次性数据, 之后无自动化管道

### 假说 2: cron 任务被 disable
- 6/2 恢复时 AINewsCollector_6h 从 Disabled → Ready (6/2 19:25)
- 但可能**触发后执行失败** (git pull 报错 / 网络问题)
- 需检查 6/2-4 期间 AINewsCollector_6h 实际执行日志

### 假说 3: 网络/GFW 问题
- openai.com / anthropic.com 6/2 之前可能被 GFW 阻断
- 6/2 之后恢复, 但 cron 未挂上

### 假说 4: write 路径错误
- 脚本可能在跑, 但写入路径失效
- 需检查 openai-blog_latest.json 5/8 时写入路径 vs 当前路径

### 假说 5: 数据格式不匹配
- 5/8 后源站结构变化, 正则匹配失败
- 写入降级到 fallback 路径, 但 latest.json 未更新

---

## 🛠️ 3 个修复方案

### 方案 1: 短期应急 (今天 04:20 → 06:00)

**操作**:
1. 手动用 web_fetch 抓取 HN Algolia API (本轮已成功) → 写入 data/ai/hn-realtime-2026-06-04-0419.json
2. 手动抓取 GitHub Trending (本轮已成功) → 写入 data/ai/github-trending-2026-06-04.json
3. 创建应急 AI 新闻 JSON: data/ai/ai-news-latest.json (合并 6/3-4 6 大事件)

**适用**: 立刻填补 28 天断档
**风险**: 仅一次性, 6/5 06:00 仍会断档
**耗时**: 5min (已完成)

### 方案 2: 中期稳定 (1-3 天)

**操作**:
1. 创建 `scripts/collect-ai-news.ps1`:
   - 每 6h 触发 (与 AINewsCollector_6h cron 同步)
   - 抓取源: HN Algolia API (主) + OpenAI 博客 (备) + Anthropic 新闻 (备) + 谷歌 AI 博客 (备)
   - 输出: data/ai/ai-news-latest.json + data/ai/hn-realtime-*.json (按时间戳)
2. 修改 cron: AINewsCollector_6h → 调 collect-ai-news.ps1
3. 添加自检: 每次写入后验证 JSON parseable, 失败自动 retry 3 次

**适用**: 解决 6/5 之后持续断档
**风险**: 需新写脚本, 调试时间 1-2h
**耗时**: 2-3h 开发 + 测试

### 方案 3: 长期架构 (1 周)

**操作**:
1. 重构 collect-ai-news.ps1 为幂等采集:
   - 输入: 时间范围 (默认 6h 前 - 现在)
   - 输出: 增量 JSON (只追加新事件, 不覆盖)
   - 历史: data/ai/ai-news-history.jsonl (JSON Lines 追加)
2. 实施"心跳 + 自愈":
   - 每 6h cron 触发
   - 失败 → 自动重试 3 次 (退避 30s/60s/120s)
   - 3 次仍失败 → 写 data/ai/ai-news-FAIL-{timestamp}.json + 触发 ALERT
3. 监控: HEARTBEAT.md 每次扫描时检查 ai-news-latest.json mtime, 超 12h 报 WARNING

**适用**: 长期不再断档
**风险**: 工程量大 (8-16h 开发)
**耗时**: 1-2 天

---

## 🎯 推荐执行顺序

**04:20-04:30** (本轮, 立即):
- ✅ 方案 1 全部完成 (HN + GitHub + ai-news-flashback)

**04:30-06:00** (1.5h 内):
- ⏳ 方案 2 第 1-2 步: 创建 collect-ai-news.ps1 (HN Algolia 优先)

**06:00** (cron 触发):
- 验证 AINewsCollector_6h 实际跑通

**6/5 之前**:
- 方案 3 完整实施

---

## 📁 已完成产出 (本轮)

| 文件 | 大小 | 状态 |
|------|------|------|
| data/ai/hn-realtime-2026-06-04-0419.json | 6.0KB | ✅ |
| data/ai/github-trending-2026-06-04.json | 11.0KB | ✅ |
| data/ai/github-trending-snapshot-2026-06-04.md | 5.5KB | ✅ (后 append) |
| data/ai/ai-news-flashback-2026-06-04.md | 9.8KB | ✅ |
| data/ai/ai-news-pipeline-diag-2026-06-04.md | (本文件) | ✅ |

---

## ⚠️ 子智能体 0 文件落地问题 (元诊断)

**现象**: 3 个子智能体 (ai-news-28d / github-trending / v24) 全部 2s/0-token/0 文件

**根因** (强证据):
- 模型 `custom-1/LongCat-Flash-Lite` 在子智能体 runtime 下不可用
- 重派为 `minmax/MiniMax-M3` 后仍未落地
- 可能原因: 子智能体 session_key 与父 agent 的 workspace mapping 出问题

**规避** (本轮执行):
- **不再依赖子智能体做 1h 内的关键路径**
- 主代理用 web_fetch + write 工具直接执行
- 子智能体仅用于长跑任务 (>30min) 或需要多轮对话的场景

**未来行动**:
- 修复子智能体派发机制 (主代理维护, 6/4-5 P1)
- 或: 改用 ACP harness (`sessions_spawn runtime=acp`)

---

*本快照由 2026-06-04 04:20 心跳自动生成 (主代理手动补救)*
"@