# 遗忘点报告 | 2026-03-31

> 扫描时间: 2026-03-31 06:35 AM (Asia/Shanghai)
> 扫描模块: deep-audit-0633

---

## 1. 数据新鲜度检查

| 文件 | 最后更新 | 距今 | 状态 |
|------|----------|------|------|
| data/tech/ai-news_latest.json | 06:33 AM | ~2分钟 | ✅ 正常 |
| data/tech/hackernews_latest.json | 06:31 AM | ~4分钟 | ✅ 正常 |
| data/tech/github-trending_latest.json | 06:31 AM | ~4分钟 | ✅ 正常 |
| data/market/prices_latest.json | 06:30 AM | ~5分钟 | ✅ 正常 |
| data/market/fear-greed_latest.json | 06:30 AM | ~5分钟 | ✅ 正常 |
| DAILY/briefings.md | 05:18 AM | ~77分钟 | ✅ 正常 |

**结论**: 无遗忘点。所有核心数据源均正常运行。

---

## 2. 历史遗忘点追溯

- `forgotten-items-2026-03-30.md`: **不存在** (今日扫描遗漏)
- `forgotten-items-2026-03-29.md`: **不存在** (文件丢失)
- `memory/2026-03-29.md`: **不存在**

**问题**: 历史遗忘点追踪链已断裂，建议在 MEMORY.md 中建立长期遗忘点追踪表。

---

## 3. 宏观数据采集：黄金/原油

### 黄金 (Gold)

| 检查项 | 结果 |
|--------|------|
| goldprice.org | ⚠️ 浏览器加载成功，但价格数据为JS渲染，`web_fetch` 抓到空壳 |
| collect-prices-simple.ps1 | ❌ 宏对象 `macro: {}` 为空 — 黄金采集失败 |
| 手动浏览器验证 | ⚠️ goldprice.org 页面有 TradingView 图表，但价格数值在 iframe 内无法直接提取 |

**实测黄金价格**: 新闻显示 2026-02 黄金在 $5,000 附近，2026-03 月新闻显示 Gold Slides 但未明确价格。

**根本原因**: `collect-prices-simple.ps1` 的 `Get-MacroPrice` 函数对 goldprice.org 的正则无法匹配当前页面结构。

### 原油 (WTI)

| 检查项 | 结果 |
|--------|------|
| oilprice.com | ✅ 浏览器成功！WTI Crude: **$104.64** (+1.72%) |
| 数据延迟 | 11分钟延迟（可接受） |
| collect-prices-simple.ps1 | ⚠️ 宏对象为空 — 原油采集也失败 |

**WTI 当前价格: $104.64 /桶**

---

## 4. 采集程序审查

### 4.1 collect-prices-simple.ps1

**发现的问题**:

1. **P0 - 宏对象采集失败**: `prices_latest.json` 中 `"macro": {}` 完全为空。VIX、黄金、原油均未采集。

2. **P1 - 黄金正则失效**: goldprice.org 当前页面结构中，价格数据在 `<iframe>` 内（TradingView图表），正则 `>([4-9],[0-9]{3}\.[0-9]{2})<` 无法匹配。

3. **P1 - 原油 oilprice.com 正则**: 虽然有正则 `'WTI Crude[\s\n]+([0-9]+\.[0-9]{2})'`，但实际HTML中是 `<cell>WTI Crude</cell><cell>104.64</cell>`，中间有table结构，`\s\n` 无法跨行匹配 `td`。

4. **P2 - SSL证书绕过**: 脚本使用 `[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }` 静默跳过证书验证，可能在某些环境下产生静默失败。

**修复建议**:
- 黄金：改用 `https://data.goldprice.org/dbXRates/USD` JSON API
- 原油：改用 `https://oilprice.com` 页面 table cell 直接提取

### 4.2 gh-trending-v2.ps1

**审查结果**: 无明显BUG，代码结构清晰，使用 GitHub API + 镜像站双降级策略。API token支持已实现。

### 4.3 alternative.me 采集逻辑

在 `collect-prices-simple.ps1` 中通过 `Get-VIXPrice` 函数调用：
```
https://api.alternative.me/fng/
```
该逻辑正常，fear-greed_latest.json 显示 value=8（极度恐慌），采集成功。

---

## 5. 发现的关键问题

### P0（紧急）
1. **宏数据采集静默失败**: `prices_latest.json` 的 `macro: {}` 全空，采集脚本报告无错误但实际采集失败。需要修复黄金/原油采集逻辑。

### P1（重要）
2. **黄金价格盲区**: goldprice.org 当前无法通过脚本采集，宏观数据缺失。
3. **历史遗忘点文件丢失**: forgotten-items-2026-03-29.md 和 forgotten-items-2026-03-30.md 均不存在。

### P2（改进）
4. **推送状态不一致**: GitHub Push 间歇性 502，但部分推送成功。incremental-backup.ps1 在推送成功后误报"工作区变更: 无"。
5. **auto-push.ps1 exit code 假阳性**: PowerShell exit code 1 在推送实际成功时仍出现。

---

## 6. 今日采集数据快照

```
BTC:  $66,848.9  (OKX_Web, 06:28)
ETH:  $2,037.66  (OKX_Web, 06:28)
SOL:  $82.94     (OKX_Web, 06:28)
F&G:  8 极度恐慌 (alternative.me, 06:30)
WTI:  $104.64/桶 (+1.72%)  (oilprice.com, 06:35)
黄金: 无法采集 (待修复)
```

---

## 7. 建议行动

- [ ] 修复 `collect-prices-simple.ps1` 黄金采集：改用 `data.goldprice.org/dbXRates/USD` JSON API
- [ ] 修复 `collect-prices-simple.ps1` 原油采集：改用 oilprice.com 表格 cell 直接提取
- [ ] 重建历史遗忘点追踪机制
- [ ] 验证 WTI 合理性（$104 vs 历史 $70-90，偏高但在地缘冲突背景下合理）

---

*报告生成时间: 2026-03-31 06:35 AM | deep-audit-0633*
