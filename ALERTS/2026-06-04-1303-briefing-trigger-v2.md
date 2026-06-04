# 简报生成触发 v2.0 — 2026-06-04 13:03

**Status**: FULL 简报
**Target**: briefings/v30
**Action**: 主代理读取简报骨架后填充

## 流程
1. 读取 C:\Users\Administrator\clawd\agents\workspace-gid\briefings\2026-06-04-v30-1303.md
2. 调 web_fetch 抓 prices_latest.json / HN / AI news
3. 检查 INTEL/ 5 报告 (gemma4-anthropic-fs / anthropic-fs / ai-economics / amoc / esp32-s31)
4. 检查 WATCHLIST/active.md 当前状态
5. 整合写入 C:\Users\Administrator\clawd\agents\workspace-gid\briefings\2026-06-04-v30-1303.md
6. 同步 DAILY/ 增量
7. 触发 auto-push (如有新 commit)

## 数据源检查
- **prices_latest.json**: OK (age 3m)
- **hacker-news_latest.json**: OK (age 63m)
- **ai-news_latest.json**: OK (age 63m)
- **farside-etf-6-3**: OK (age 266m)
- **middle-east-snapshot**: OK (age 254m)
- **INTEL dir**: OK (age 8m)
- **memory_today**: OK (age 6m)
- **WATCHLIST**: OK (age 331m)

---
*由 briefing-generator.ps1 v2.0 自动生成*
