# COLLECTION_STATUS.md - 数据采集系统状态报告

**生成时间**: 2026-05-06 13:04 GMT+8
**版本**: v8+
**运行环境**: Windows Server / PowerShell + Brave Browser + web_fetch

---

## 一、脚本清单（按功能分类）

### 1.1 价格采集（加密货币/VIX/黄金/原油）

| 脚本 | 版本 | 最后更新 | 功能 | 状态 |
|------|------|----------|------|------|
| `collect-prices-simple.ps1` | v8 | 2026-04-11 | BTC/ETH/SOL + VIX + 黄金 + 原油，多源降级 | ✅ 主力脚本 |
| `hourly-price-collector.ps1` | - | 2026-04-09 | 每小时价格采集 | ✅ 定时任务 |
| `macro-data-collector.ps1` | - | 2026-04-30 | 黄金/原油/F&G指数，Brave Browser | ✅ 主力宏采 |
| `browser-price-collector.ps1` | - | 2026-03-30 | 浏览器价格采集备用 | ⚠️ 备用 |
| `collect-macro-playwright.ps1` | v2 | 2026-04-11 | IE COM宏采备用（已废弃） | ❌ 仅供参考 |
| `collect-optimized-v2.ps1` | v2 | 2026-03-30 | 优化版采集 | ⚠️ 已整合 |

> **v8改进**: OKX API因GFW SSL问题移除，保留Gate.io备用；VIX采集逻辑修复

### 1.2 AI新闻采集

| 脚本 | 版本 | 最后更新 | 功能 | 状态 |
|------|------|----------|------|------|
| `collect-ai-news-rss.ps1` | - | 2026-04-27 | 多源RSS（TC/MIT/VB/Verge/Ars/Wired/Slashdot） | ✅ 主力 |
| `fetch-hn-top30.ps1` | - | 2026-04-21 | Hacker News Top30 | ✅ 备用 |
| `collect-tech-news.ps1` | - | 2026-04-21 | 科技新闻汇总 | ⚠️ 备用 |
| `sync-ai-news-md.ps1` | - | 2026-04-28 | AI新闻同步Markdown | ✅ |

> **RSS源**（7个）: TechCrunch AI, MIT Technology Review, VentureBeat AI, The Verge, Ars Technica, Wired Science, Slashdot
> ⚠️ **注意**: `tech-news_latest.json` 最后更新 2026-04-28（8天前），采集可能已中断

### 1.3 GitHub Trending

| 脚本 | 版本 | 最后更新 | 功能 | 状态 |
|------|------|----------|------|------|
| `gh-trending-browser-v5.ps1` | v5 | 2026-04-28 | Playwright浏览器真实Trending页面 | ✅ 最新主力 |
| `gh-trending-v4.ps1` | v4 | 2026-04-27 | GitHub API (browser tool) | ✅ 备用 |
| `gh-trending-v3.ps1` | v3 | 2026-04-27 | Bing搜索降级 | ⚠️ 已废弃 |
| `gh-trending-from-browser.ps1` | - | 2026-04-22 | 浏览器采集 | ⚠️ 已废弃 |
| `gh-trending-v2.ps1` | v2 | 2026-03-26 | 早期版本 | ❌ 已废弃 |
| `gh-trending-bgithub.ps1` | - | 2026-03-30 | bgithub镜像（不可用） | ❌ 已废弃 |
| `sync-github-md.ps1` | - | 2026-04-21 | GitHub Trending同步Markdown | ✅ |

> **v5说明**: 使用Playwright MCP直接访问 `github.com/trending`，采集真实stars_today字段

### 1.4 宏观数据

| 脚本 | 版本 | 最后更新 | 功能 | 状态 |
|------|------|----------|------|------|
| `macro-data-collector.ps1` | - | 2026-04-30 | 黄金/原油/F&G指数，Brave Browser | ✅ 主力 |
| `collect-macro-playwright.ps1` | - | 2026-04-11 | IE COM备用 | ❌ 仅供参考 |

### 1.5 简报生成

| 脚本 | 版本 | 最后更新 | 功能 | 状态 |
|------|------|----------|------|------|
| `daily-collector.ps1` | - | 2026-04-28 | 每日AM/PM采集+推送一体化 | ✅ 主力 |
| `hourly-briefing.ps1` | - | 2026-03-26 | 每小时简报生成 | ⚠️ 备用 |

### 1.6 推送/归档

| 脚本 | 版本 | 最后更新 | 功能 | 状态 |
|------|------|----------|------|------|
| `auto-push.ps1` | v2+ | 2026-04-28 | Git推送+归档集成 | ✅ |
| `incremental-backup.ps1` | v1 | 2026-03-25 | 增量归档+清理 | ✅ |

> **已废弃/重复脚本**（建议清理）:
> `browser-realtime-collector.ps1`, `collect-policy.ps1`, `debug-*.ps1`, `test-*.ps1`, `fix-*.ps1`, `gh-trending-v2.ps1`, `gh-trending-v3.ps1`, `gh-trending-bgithub.ps1`, `simple_price_collector.ps1`, `network-test.ps1`, `update-briefing-1113.ps1`

---

## 二、Cron任务状态表（Windows Task Scheduler）

| 任务名称 | 类型 | 下次执行 | 最后结果 | 状态 |
|----------|------|----------|----------|------|
| `AINewsCollector_6h` | AI新闻 | 2026-05-06 18:00 | Ready | ⚠️ 需确认执行情况 |
| `DailyCollector_AM` | 每日采集 | 2026-05-07 08:00 | Ready | ✅ |
| `DailyCollector_PM` | 每日采集 | 2026-05-06 20:00 | Ready | ✅ |
| `HourlyPriceCollector` | 每小时价格 | 2026-05-06 13:06 | Ready | ✅ |

> **注意**: `openclaw cron` CLI 不可用，所有定时任务通过 `schtasks` 管理

---

## 三、数据文件清单

| 目录 | 文件数 | 最新数据 | 备注 |
|------|--------|----------|------|
| `data/market/` | 299 | 2026-05-06 12:06 | prices_latest.json + 时间戳版本 |
| `data/prices/` | 205 | 2026-05-06 12:00 | 独立价格存档 |
| `data/ai/` | 48 | ⚠️ 2026-04-28 | tech-news_latest.json 陈旧（8天），github-trending-2026-05-06 已更新 |
| `data/tech/` | 56 | 2026-05-06 | GitHub Trending相关文件 |
| `data/briefing/` | 2 | - | 简报文件 |
| `data/DAILY/` | 0 | - | 空目录 |
| `data/logs/` | 0 | - | 空目录（日志在其他位置） |

**最新数据文件**:
- `data/market/prices_latest.json` - 2026-05-06 12:06
- `data/market/prices_2026-05-06_12-06.json`
- `data/ai/github-trending-2026-05-06.json` / `.md` - 2026-05-06
- `data/ai/tech-news_latest.json` - ⚠️ **2026-04-28** (严重陈旧)

---

## 四、当前数据质量状态

| 数据类型 | 数据源 | 采集方式 | 质量 | 备注 |
|----------|--------|----------|------|------|
| BTC/ETH/SOL | OKX API / CryptoCompare / Gate.io | fetch | 高 | 多源降级，v8移除OKX主源 |
| VIX | CBOE / Yahoo Finance / alternative.me | fetch | 高 | v8修复采集逻辑 |
| 黄金 | goldprice.org / Kitco | Brave Browser CDP | 高 | JS渲染，必须浏览器 |
| 原油 | TradingEconomics / oilprice.com | fetch/Browser | 高 | JS渲染降级方案 |
| Fear&Greed | alternative.me API | fetch | 中 | 置信度低于VIX |
| AI新闻 | TechCrunch/MIT/VentureBeat等7源 | RSS fetch | 高 | ⚠️ 最新数据4/28，需确认采集状态 |
| GitHub Trending | github.com (Playwright) | Browser | 高 | v5直接访问真实页面 |
| Hacker News | news.ycombinator.com | fetch | 高 | Top30采集 |

---

## 五、已知问题列表

| # | 问题 | 影响 | 状态 | 修复方案 |
|---|------|------|------|----------|
| 1 | **AI新闻采集中断** | tech-news_latest.json 最后更新 2026-04-28（8天前） | ⚠️ 需排查 | 检查 `AINewsCollector_6h` 任务执行日志；检查RSS源是否被屏蔽 |
| 2 | **GitHub Trending今日数据** | github-trending-2026-05-06.json/md 已存在，但需确认是否由cron自动触发 | ⚠️ 待确认 | 验证 `DailyCollector_PM` 是否正确调用 v5 脚本 |
| 3 | **OKX API SSL阻断** | api.okx.com 在中国SSL握手失败 | ✅ 已修复(v8) | OKX不再作为主源，保留Gate.io备用 |
| 4 | **GitHub直连阻断** | github.com 被GFW屏蔽 | ✅ 已修复(v5) | Playwright浏览器绕过；browser tool访问GitHub API |
| 5 | **Binance API阻断** | api.binance.com 在中国不可访问 | ✅ 已修复(v8) | OKX/Gate.io/CryptoCompare 替代 |
| 6 | **黄金/原油JS渲染** | goldprice.org/oilprice.com 内容动态生成 | ✅ 已修复(v5) | Brave Browser CDP 提取 |
| 7 | **VIX采集失效（历史）** | cn.bing.com VIX搜索结果失效 | ✅ 已修复(v8) | CBOE/Yahoo Finance/alternative.me 降级路径 |
| 8 | **Gitee内容有限** | Gitee热榜内容有限 | ✅ 已知限制 | 仅作GitHub最后备选 |
| 9 | **openclaw cron CLI不可用** | 无法使用 `openclaw cron list` | ⚠️ 环境问题 | 使用 `schtasks /query` 替代 |
| 10 | **data/ai/tech-news陈旧** | AI新闻最新数据4/28，距今8天 | ⚠️ 需处理 | 见问题#1 |

---

## 六、推荐 Cron 调度（当前）

| 时间 | 任务 | 脚本 | 备注 |
|------|------|------|------|
| 每小时 | `HourlyPriceCollector` | `collect-prices-simple.ps1` | 加密货币+VIX实时监控 |
| 每6小时 | `AINewsCollector_6h` | `collect-ai-news-rss.ps1` | AI新闻RSS采集 |
| 08:00 | `DailyCollector_AM` | `daily-collector.ps1` | 宏采+AI新闻+GitHub+推送 |
| 20:00 | `DailyCollector_PM` | `daily-collector.ps1` | 晚间版 |

---

## 七、架构演进备注（v6 → v8+）

- **v7**: OKX API SSL问题发现，移除OKX主源地位
- **v8**: VIX采集逻辑完全重写；Gate.io保留备用；CryptoCompare备选
- **GitHub采集演进**: v2(Bing) → v3(Bing优化) → v4(GitHub API browser tool) → **v5(Playwright真实Trending页面)**
- **AI新闻演进**: 单源 → 多源RSS(7源)；当前问题：最新数据陈旧

---

*报告更新: 2026-05-06 13:04 - v8+ 状态全面更新*
