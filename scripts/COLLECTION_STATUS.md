# COLLECTION_STATUS.md - 数据采集系统状态报告

**生成时间**: 2026-03-26 01:18 GMT+8
**版本**: v6b (GOLD/OIL合理性检查修复版)
**运行环境**: Windows Server / PowerShell + web_fetch

---

## 一、脚本清单

| 脚本 | 版本 | 功能 | 状态 |
|------|------|------|------|
| `collect-prices-simple.ps1` | v6 | 加密货币+VIX+黄金+原油 | ✅ 新增alternative.me FNG |
| `gh-trending-v2.ps1` | v2 | GitHub Trending深度采集 | ✅ 主力脚本 |
| `collect-tech-news.ps1` | (原版) | AI博客/量子计算 | ✅ 兼容 |
| `collect-policy.ps1` | (原版) | FOMC/央行/出口管制 | ✅ 兼容 |
| `auto-push.ps1` | v2 | 推送(含归档集成) | ✅ 升级 |
| `incremental-backup.ps1` | v1 | 增量归档+清理 | ✅ 新建 |
| `hourly-briefing.ps1` | (原版) | 每小时简报生成 | ✅ 兼容 |

> **已删除重复脚本** (2026-03-26): `gh-trending-collector.ps1` (被v2覆盖), `collect-market-data.ps1` (被collect-prices-simple覆盖), `extract-prices.ps1` (功能重复)

---

## 二、数据源可用性清单

### 加密货币价格 (2026-03-25 测试结果)

| 数据源 | URL | 状态 | 备注 |
|--------|-----|------|------|
| OKX API | `okx.com/api/v5/market/ticker?instId=BTC-USDT` | ✅ 成功 (~349ms) | **主推荐** |
| CryptoCompare API | `min-api.cryptocompare.com/data/price` | ✅ 成功 (~1865ms) | 备选 |
| Gate.io API | `api.gateio.ws/api/v4/spot/tickers` | ✅ 成功 (~2649ms) | 备选 |
| Binance API | `api.binance.com` | ❌ 失败 (~8s超时) | GFW屏蔽 |
| CoinGecko API | `api.coingecko.com` | ❌ 失败 | GFW屏蔽 |
| cn.bing.com | 搜索摘要 | ✅ 兜底 | 低置信度 |

### GitHub Trending

| 方式 | URL | 状态 | 备注 |
|------|-----|------|------|
| githubfast.com | `githubfast.com/trending` | ❌ 403 Forbidden | 已测试失败 |
| ghp.ci | - | ❌ DNS解析失败 | 域名不可用 |
| gitmirror.com | - | ❌ DNS解析失败 | 域名不可用 |
| hub.fastgit.xyz | `hub.fastgit.xyz/trending` | ❌ 超时 (~8s) | 不可用 |
| cn.bing.com 优化查询 | 搜索策略 | ✅ 75% | **当前主力方案** |
| Gitee API | `gitee.com/api/v5/explore_rank/hottest` | ✅ 可用 | 备选镜像 |

### 其他数据源

| 数据源 | 直连 | Bing代理 | 备注 |
|--------|------|----------|------|
| federalreserve.gov | ✅ 90% | - | FOMC日历 |
| deepseek.com/blog | ✅ 90% | - | DeepSeek博客 |
| openai.com/news | ✅ 90% | - | OpenAI |
| google.com | ❌ | ✅ 75% | 走cn.bing.com |
| github.com | ❌ | ✅ 75% | 走cn.bing.com |

---

## 三、v4 改进详情

### 任务1: collect-prices-simple.ps1 (重写)

**改进点**:
1. **多源降级**: OKX API → CryptoCompare → Gate.io → cn.bing.com
2. **JSON结构化输出**: 价格 + source + confidence + timestamp + raw snippet
3. **数据质量评分**: 高/中/低 三档 (基于来源权威性+字段完整性)
4. **输出格式**: `data/market/prices_YYYY-MM-DD_HH-mm.json` (带时间戳)
5. **详细日志**: 每一步都有日志记录

**数据结构**:
```json
{
  "timestamp": "2026-03-25 20:00:00",
  "timestamp_iso": "2026-03-25T12:00:00Z",
  "collection_version": "v4",
  "crypto": {
    "BTC": { "price": 71712.9, "source": "OKX_API", "confidence": "high", "raw": "..." }
  },
  "macro": {
    "VIX": { "value": 18.5, "source": "cn.bing.com", "confidence": "medium" }
  },
  "quality_report": {
    "BTC": { "score": 95, "label": "高", "factors": "API权威来源 + 价格字段 + 来源标注 + 时间戳 + 原始数据" },
    "_overall": { "average_score": 82.5, "label": "高", "total_items": 6 }
  }
}
```

### 任务2: gh-trending-collector.ps1 (新建)

**改进点**:
1. **镜像探测**: 启动时自动测试 githubfast.com / hub.fastgit.xyz
2. **多语言采集**: Python/JS/AI/Go/Rust 各语言trending
3. **智能去重**: 基于repo path去重，累计采集
4. **Markdown报告**: 生成结构化MD报告(AI/ML优先)
5. **三种模式**: `mirror` → `bing_optimized` → `gitee_backup`

**输出**:
- `data/tech/github-trending_YYYY-MM-DD_HH-mm.json` (原始数据)
- `data/tech/github-trending_YYYY-MM-DD_HH-mm.md` (可读报告)

### 任务3: incremental-backup.ps1 (新建) + auto-push.ps1 (升级)

**改进点**:
1. **归档触发**: 推送失败时自动将新文件移动到 `data/archive/`
2. **manifest追踪**: `_manifest.json` 记录所有归档文件状态
3. **恢复机制**: `incremental-backup.ps1 restore` 可恢复归档文件
4. **自动清理**: 推送成功后清理archive已推送记录(保留7天)
5. **git reset保护**: 推送失败时 `git reset --soft HEAD~1` 保留变更

**流程**:
```
采集 → auto-push → 推送成功 → 清理archive ✅
                → 推送失败 → git reset → 归档到data/archive/ → 下次恢复推送
```

### 任务4: 数据质量评分

**评分维度**:
| 维度 | 高分条件 | 分值 |
|------|----------|------|
| 来源权威性 | API接口返回 | +40 |
| 来源权威性 | Bing搜索摘要 | +25 |
| 来源权威性 | Bing搜索(无结构) | +10 |
| 字段完整性 | 价格/value字段 | +20 |
| 字段完整性 | source来源标注 | +15 |
| 字段完整性 | timestamp时间戳 | +10 |
| 字段完整性 | raw原始数据 | +15 |

**评分标签**:
- 高 (≥70分): API接口来源，字段完整
- 中 (40-69分): Bing搜索摘要，基础字段
- 低 (<40分): Bing搜索，内容不完整

---

## 四、推荐 cron 调度

| 时间 | 脚本 | 备注 |
|------|------|------|
| 09:00 | `collect-prices-simple.ps1` | 早间价格 |
| 09:30 | `collect-policy.ps1` | 政策/FOMC |
| 10:00 | `gh-trending-collector.ps1` | GitHub热榜 |
| 10:30 | `collect-tech-news.ps1` | AI博客/量子 |
| 21:00 | `collect-prices-simple.ps1` | 晚间价格 |
| 21:30 | `collect-policy.ps1` | 政策晚间版 |
| 22:00 | `auto-push.ps1` | 每日推送 |
| 每小时 | `collect-prices-simple.ps1` | `price-refresh-hourly` | 加密货币+VIX实时监控 |

---

## 五、已知限制

1. **GitHub直连**: github.com 被GFW完全屏蔽，镜像站也不稳定，Bing搜索是主要方案
2. **Binance API**: api.binance.com 在中国不可访问，改用OKX/CryptoCompare替代
3. **数据质量**: Bing搜索来源的价格数据置信度为"低"，仅供趋势参考
4. **Gitee内容**: Gitee热榜内容有限，主要作为GitHub的最后备选

---

## 六、data/archive/ 说明

- **用途**: 推送失败时临时保存数据，确保不丢失
- **恢复**: `.\incremental-backup.ps1 restore` 可恢复
- **清理**: 推送成功后自动清理7天前记录
- **manifest**: `data/archive/_manifest.json` 追踪归档状态

---

## 七、已知问题

| 问题 | 原因 | 状态 | 修复方案 |
|------|------|------|----------|
| VIX采集失败 (2026-03-25 20:15起) | cn.bing.com搜索VIX结果失效 | ✅ 已修复(v5) | 改用Yahoo Finance API `^VIX` + CNN Fear&Greed降级 |

---

*报告更新: 2026-03-26 01:18 - VIX采集修复 + cron任务更新*
