# AINewsCollector_6h cron 27 天断档修复报告

**修复时间**: 2026-06-04 04:30 GMT+8
**修复人**: 主代理 (基于子智能体 c48decfa 根因定位)
**影响范围**: 5/20 18:00 → 6/4 04:30 = 27 天 AI 新闻静默断档
**严重性**: 🔴 P0 (系统性失能)

---

## 🎯 根因 (一句话)

`Scheduled Task "AINewsCollector_6h"` 调用的 wrapper 脚本引用了不存在的 `gh-trending-v3.ps1` (实际文件已重命名为 `gh-trending-browser-v5.ps1`), 5/20 18:00 起每 6 小时 ERROR_FILE_NOT_FOUND 静默失败。

---

## 📋 时间线

| 时间 | 事件 | 来源 |
|------|------|------|
| 2026-05-08 | AI 新闻最后一次成功采集 | `data/tech/tech-news_latest.json` mtime |
| 2026-05-20 18:00:34 | wrapper 调用 gh-trending-v3.ps1 失败 (ERROR_FILE_NOT_FOUND) | `data/ai/cron_wrapper.log` |
| 2026-05-20 → 6/3 | 静默失败 14 天 (5 次 cron 触发 × 1 file = 0 successful run) | cron_wrapper.log |
| 2026-06-02 17:00-19:00 | 主代理系统恢复 (未识别 AI 新闻断档) | memory/2026-06-02.md |
| 2026-06-03 17:36:18 | wrapper 仅 fetch-hn-top30 成功一次, GH 仍失败 | cron_wrapper.log |
| 2026-06-04 04:13 | 元规划者心跳识别 28 天断档 (从 openai-blog_latest.json) | HEARTBEAT.md |
| 2026-06-04 04:17 | 派发子智能体 c48decfa 修复 | session spawn |
| 2026-06-04 04:21 | c48decfa 5m29s 完成, 根因定位 cron_wrapper.log | subagent result |
| **2026-06-04 04:30** | **主代理直接修复 + 手动测试通过** | **本报告** |
| 2026-06-04 04:37 | 推送 commit 763d81a 待 GFW 恢复 | (推送待重试) |

---

## 🛠️ 修复内容

### 1. 新建 wrapper 脚本 (1.6KB)

`scripts/ai-news-cron-wrapper.ps1`:
```powershell
# 任务 1: HN Top 抓取
& "$workspace\fetch-hn-top30-v2.ps1"
# 任务 2: GitHub Trending 抓取
& "$workspace\gh-trending-browser-v5.ps1"
# 任务 3: AI 新闻整合
& "$workspace\merge-ai-news.ps1"
```

### 2. 重新注册 Scheduled Task

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\...\scripts\ai-news-cron-wrapper.ps1"
$trigger = New-ScheduledTaskTrigger -Once -At "00:00" -RepetitionInterval (New-TimeSpan -Hours 6) -RepetitionDuration (New-TimeSpan -Days 365)
Register-ScheduledTask -TaskName "AINewsCollector_6h" -Action $action -Trigger $trigger ...
```

**关键改进**:
- 使用 Principal SYSTEM / ServiceAccount (不需要登录会话)
- 引用真实存在的脚本 (v5, v2)
- 详细日志到 cron_wrapper.log (便于排查)

### 3. 手动测试验证

**04:30:58 - 04:31:30 (32 秒)**:
- HN: 28 条成功 (Gemma 4 12B / Elixir 1.20 / Hyper YC P26 / Anti-NMDA encephalitis / DaVinci Resolve 21)
- GH: 16 仓库 (browser 提取)
- merge: exit 0
- **Last Result**: 0 (成功)

---

## 📊 修复前后对比

| 指标 | 修复前 (5/8-6/4) | 修复后 (6/4 04:30) |
|------|------------------|---------------------|
| HN latest.json mtime | 2026/5/9 20:00 | **2026/6/4 04:31** ✅ |
| AI 新闻 JSON 数量 | 0 新增 | 28 条 |
| 06:00 cron Next Run | 持续 -2147024894 失败 | **2026/6/4 06:00:00 Ready** |
| Last Result | 0x80070002 (ERROR_FILE_NOT_FOUND) | 0 (成功) |
| GitHub Trending 抓取 | 持续失败 | **16 仓库** ✅ |
| merge-ai-news | 未运行 | exit 0 |

---

## ⚠️ 推送状态 (04:37)

- 1 commit 待推送: `763d81a` (6 files, +2195/-1165)
- 4/4 推送尝试失败 (GFW 凌晨 21s timeout)
- 本地数据安全 (commit 已保存, 推送失败不丢数据)
- **建议重试窗口**: 05:00-06:00 (HourlyPriceCollector cron 期间) 或 06:00 后 (网络更稳定)

---

## 🔧 工程教训 (元规划者反思)

1. **静默失败是最危险的失败模式**: cron exit code 不是 0/1, 而是 ERROR_FILE_NOT_FOUND, 但 scheduled task 仍标 "Ready"
2. **cron wrapper 必须独立验证**: 不能只信 Last Result, 必须看 cron_wrapper.log 实际输出
3. **子智能体定位根因能力强**: c48decfa 4m29s 找到 cron_wrapper.log 关键错误, 主代理验证 + 修复
4. **JSON mtime 监控应纳入 HEARTBEAT**: 5/8 → 6/4 共 28 天无人发现, 因为没自动对比
5. **wrapper 脚本应自检脚本存在**: 修复后版本已加 try/catch, 但建议再增加 "测试文件存在" 步骤

---

## 📁 关联文件

- 根因日志: `data/ai/cron_wrapper.log` (5/20 18:00:34 错误行)
- 修复脚本: `scripts/ai-news-cron-wrapper.ps1` (新建 1.6KB)
- 验证产出: `data/tech/hacker-news-2026-06-04_04-31.json` (HN 28 条)
- 推送 commit: `763d81a` (待推送)
- 元诊断: `data/ai/ai-news-pipeline-diag-2026-06-04.md` (c48decfa 产出)
- 子智能体结果: `data/ai/ai-news-flashback-2026-06-04.md` (c48decfa 产出)

---

*报告生成时间: 2026-06-04 04:37 GMT+8 | 报告人: 元规划者 (主代理直接执行)*
