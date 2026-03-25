# 数据采集管道文档 (COLLECTION_PIPELINE)

> 创建时间：2026-03-26
> 版本：v1
> 维护者：OpenClaw Intelligence System

---

## 一、脚本清单与功能

| 脚本 | 版本 | 输入 | 输出 | 依赖 |
|------|------|------|------|------|
| `collect-prices-simple.ps1` | v6 | 无（自动采集） | `data/market/prices_*.json` | OKX/CryptoCompare/Gate.io API, cn.bing.com, alternative.me |
| `gh-trending-v2.ps1` | v2 | 无（自动采集） | `data/tech/github-trending_*.json` | cn.bing.com搜索, Gitee API |
| `collect-tech-news.ps1` | 原版 | 无 | `data/tech/*.json` | DeepSeek/OpenAI博客, cn.bing.com |
| `collect-policy.ps1` | 原版 | 无 | `data/policy/*.json` | federalreserve.gov, cn.bing.com |
| `auto-push.ps1` | v2 | 所有采集数据 | GitHub仓库 | git CLI |
| `incremental-backup.ps1` | v1 | 推送失败文件 | `data/archive/` | git CLI |
| `hourly-briefing.ps1` | 原版 | 所有data文件 | `DAILY/briefings.md` | 内置 |

---

## 二、数据流向图（文本版）

```
[外部数据源]
     │
     ├── OKX API ──────────────┐
     ├── CryptoCompare API ───┤
     ├── Gate.io API ──────────┤
     ├── alternative.me FNG ──┤
     ├── cn.bing.com ──────────┤
     ├── federalreserve.gov ───┤
     ├── DeepSeek/OpenAI博客 ──┤
     └── Gitee API ────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│  scripts/collect-*.ps1               │
│  (采集脚本，每个负责一个数据域)         │
└─────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│  data/                              │
│  ├── market/prices_*.json           │
│  │   (加密货币、VIX、黄金、原油)        │
│  ├── market/prices_latest.json      │
│  ├── tech/github-trending_*.json    │
│  ├── tech/github-trending_latest.json│
│  ├── tech/*.json (AI/量子新闻)        │
│  └── policy/*.json (FOMC/政策)       │
└─────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│  scripts/auto-push.ps1               │
│  (推送至GitHub，含归档保护)           │
└─────────────────────────────────────┘
        │                    │
        ▼ (成功)             ▼ (失败/502)
┌──────────────┐    ┌─────────────────────┐
│ GitHub ✅    │    │ git reset           │
│              │    │ → data/archive/     │
│              │    │ (下次恢复推送)       │
└──────────────┘    └─────────────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│  DAILY/briefings.md                 │
│  (每日简报，自动聚合)                 │
└─────────────────────────────────────┘
```

---

## 三、依赖关系详解

### 3.1 collect-prices-simple.ps1（价格采集）

**数据源降级路径：**
```
加密货币:
  OKX API → CryptoCompare API → Gate.io API → cn.bing.com搜索

VIX:
  Yahoo Finance API → alternative.me F&G Index → cn.bing.com搜索

黄金/原油:
  cn.bing.com搜索（主要来源）
```

**输出文件：**
- `data/market/prices_YYYY-MM-DD_HH-mm.json`（带时间戳）
- `data/market/prices_latest.json`（最新数据软链接）
- `data/market/raw_search_*.txt`（Bing搜索原始结果）

**质量评分：**
- 高（≥70分）：API权威来源 + 完整字段
- 中（40-69分）：Bing摘要 + 基础字段
- 低（<40分）：Bing搜索 + 不完整

---

### 3.2 gh-trending-v2.ps1（GitHub热榜）

**采集策略（三级降级）：**
```
模式1 (mirror): githubfast.com → hub.fastgit.xyz
模式2 (bing_optimized): cn.bing.com 优化查询
模式3 (gitee_backup): Gitee API
```

**输出文件：**
- `data/tech/github-trending_YYYY-MM-DD_HH-mm.json`
- `data/tech/github-trending_YYYY-MM-DD_HH-mm.md`
- `data/tech/github-trending_latest.json`
- `data/tech/github-trending_latest.md`

---

### 3.3 collect-tech-news.ps1（科技新闻）

**数据源：**
- DeepSeek博客：deepseek.com/blog
- OpenAI新闻：openai.com/news
- 量子计算：Bing搜索聚合
- 其他AI博客：Bing搜索

**输出文件：**
- `data/tech/` 下的 JSON 文件

---

### 3.4 collect-policy.ps1（政策数据）

**数据源：**
- FOMC日历：federalreserve.gov/monetarypolicy/fomccalendars.htm
- 央行政策：Bing搜索
- 出口管制：Bing搜索聚合

**输出文件：**
- `data/policy/` 下的 JSON 文件

---

### 3.5 auto-push.ps1（GitHub推送）

**流程：**
```
1. git add --all
2. git commit -m "auto: YYYY-MM-DD HH-mm"
3. git push
   ├── 成功 → 记录到日志 ✅
   └── 失败 → git reset --soft HEAD~1
              → 将未推送文件归档到 data/archive/
              → 记录错误日志
```

**归档机制：**
- manifest文件：`data/archive/_manifest.json`
- 恢复命令：`.\incremental-backup.ps1 restore`
- 保留策略：7天后自动清理

---

## 四、GWF网络限制应对

| 数据源 | 直连状态 | 替代方案 | 备注 |
|--------|----------|----------|------|
| github.com | ❌ 完全屏蔽 | cn.bing.com搜索/Gitee | 主力方案 |
| api.binance.com | ❌ 屏蔽 | OKX/CryptoCompare/Gate.io | 主力方案 |
| Yahoo Finance | ❌ 部分屏蔽 | alternative.me F&G | VIX替代 |
| cn.bing.com | ✅ 可用 | 搜索聚合主力 | 主力方案 |
| federalreserve.gov | ✅ 可用 | 直连 | FOMC日历 |
| deepseek.com | ✅ 可用 | 直连 | AI博客 |
| openai.com | ✅ 可用 | 直连 | OpenAI博客 |
| alternative.me | ✅ 可用 | 直连 | 无需认证 |

---

## 五、推荐调度

| 时间 | 脚本 | 说明 |
|------|------|------|
| 每小时 | `collect-prices-simple.ps1` | 加密货币+VIX实时 |
| 09:30 | `collect-policy.ps1` | 政策/FOMC |
| 10:00 | `gh-trending-v2.ps1` | GitHub热榜 |
| 10:30 | `collect-tech-news.ps1` | AI博客/量子 |
| 21:00 | `collect-prices-simple.ps1` | 晚间价格 |
| 21:30 | `collect-policy.ps1` | 政策晚间版 |
| 22:00 | `auto-push.ps1` | 每日推送 |

---

*文档更新：2026-03-26 04:13 GMT+8*
