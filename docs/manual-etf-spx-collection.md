# ETF / SPX / 合约浏览器采集 — 手动操作说明

> **背景**: Farside (BTC ETF 流入/流出)、Investing.com (SPX 指数)、CoinGlass (多空比/合约) 均为重度 JS 渲染页面，`web_fetch` 无法提取数据。需通过浏览器子智能体或手动采集。
>
> **建议频率**: 每周 1-2 次（美东周五收盘后，北京时间周六早 07:00）
> **紧急触发**: BTC 单日波动 >3% 或突发宏观事件（FOMC、NFP）时立即采集

---

## 1️⃣ BTC ETF 流入/流出数据

### 数据源: Farside Investors

- **URL**: [https://farside.co.uk/btc/](https://farside.co.uk/btc/)
- **备用 URL**: [https://farside.co.uk/](https://farside.co.uk/) → 点 "BTC" 选项卡

### 要采集的字段

| 字段 | 说明 | 示例 |
|------|------|------|
| `daily_flow` | 当天每只 ETF 的净流入/流出 ($M) | IBIT: +47.7, FBTC: -5.5 |
| `total_daily` | 当天总净流量 | +3.2M |
| `cumulative_total` | 每只 ETF 上线以来累计净流量 | IBIT: 61898 |
| `fund_details` | 费率和管理人 | IBIT (Blackrock, 0.25%) |

**注意**:
- 页面表格每天 08:30 ET (北京时间 20:30) 更新前一日数据
- 部分基金截至北京时间早 08:00 可能尚未公布（显示 "—"）
- IBIT (Blackrock) 和 GBTC (Grayscale) 是最大的两只，重点关注

### 参考输出格式

```json
{
  "source": "Farside Investors",
  "source_url": "https://farside.co.uk/btc/",
  "scan_time": "2026-06-24T07:38:00+08:00",
  "funds": {
    "IBIT": { "name": "iShares Bitcoin Trust (Blackrock)", "fee": "0.25%", "cumulative_total": 61898 },
    "FBTC": { "name": "Fidelity Wise Origin Bitcoin Fund", "fee": "0.25%", "cumulative_total": 10525 }
  },
  "daily_flows": [
    { "date": "2026-06-22", "IBIT": -172.0, "FBTC": 57.4, "total": -68.3 }
  ]
}
```

**存储位置**: `data/market/etf-spx-contract-{YYYY-MM-DD-HHMM}.json`

---

## 2️⃣ 美股指数 (SPX/DJI/NDX/VIX)

### 数据源: Investing.com

- **SPX**: [https://www.investing.com/indices/us-spx-500](https://www.investing.com/indices/us-spx-500)
- **DJI**: [https://www.investing.com/indices/us-30](https://www.investing.com/indices/us-30)
- **VIX**: [https://www.investing.com/indices/volatility-s-p-500](https://www.investing.com/indices/volatility-s-p-500)
- **DXY**: [https://www.investing.com/indices/us-dollar-index](https://www.investing.com/indices/us-dollar-index)

### 要采集的字段

| 字段 | 说明 | 示例 |
|------|------|------|
| `value` | 当前点位 | 7365.48 |
| `change` | 绝对变化 | -107.31 |
| `change_pct` | 百分比变化 | -1.44% |
| `prev_close` | 前一日收盘 | 7365.48 |
| `open` | 今日开盘 | 7366.51 |
| `day_range` | 日内区间 | 7347.60 - 7424.17 |
| `52w_range` | 52周区间 | 6059.25 - 7620.90 |
| `status` | 盘态 | Open / Closed / After-hours |
| `last_updated` | 最后更新时间 | 2026-06-23 close (15:59:57 ET) |

### 额外指数（同一页面可获取）

- **SPX 期货**: 盘后期货价格
- **SPY**: SPX ETF 对应价格
- **VIX**: 恐慌指数（VHSI 也可关注）
- **DXY**: 美元指数

**注意**:
- VIX 在 Investing.com 页面中通常显示在右侧 "Market Summary" 板块
- SPX 期货在页面下方 "Futures" 板块
- 美股盘后数据从北京时间 04:00 起可用
- 页面有反爬机制，过于频繁刷新可能会触发 CAPTCHA

---

## 3️⃣ BTC/ETH 合约多空比 & 爆仓数据

### 数据源: CoinGlass

- **URL**: [https://www.coinglass.com/LongShortRatio](https://www.coinglass.com/LongShortRatio)
- **备用**: [https://www.coinglass.com/](https://www.coinglass.com/) → 点 "Long/Short Ratio"

### 要采集的字段

**全局数据**:
| 字段 | 说明 | 示例 |
|------|------|------|
| `global_24h_ls` | 全局 24h 多空比 | 49.41% / 50.59% |
| `taker_buy_sell_4h` | 4h Taker 买卖量 | 50.26% / 49.74% |
| `24h_volume` | 24h 合约交易量 | $178B |
| `open_interest` | 未平仓合约 | $104B |
| `24h_liquidation` | 24h 爆仓量 | $573M |

**交易所维度** (至少采集 Top 5):
| 字段 | 说明 | 示例 |
|------|------|------|
| `exchange` | 交易所名 | Binance |
| `long_pct` | 多头占比 | 48.93% |
| `short_pct` | 空头占比 | 51.07% |
| `long_volume` | 多头交易量 | $378M |
| `short_volume` | 空头交易量 | $395M |

**OKX/Binance/Bybit 聪明钱信号** (最关键):
| 字段 | 说明 | 示例 |
|------|------|------|
| `smart_money_sentiment` | 聪明钱偏 | Extremely Bearish 🔥 |
| `whale_ls_ratio` | 鲸鱼多空比 | 0.68 |
| `retail_sentiment` | 散户偏 | Bullish |

**BTC 地址仓位** (optional):
| 字段 | 说明 | 示例 |
|------|------|------|
| `address_ls_ratio_4h` | 4h 地址多空 | 1.49 |
| `very_bullish / bullish / neutral / bearish / very_bearish` | 情绪分布 | 32% / 21% / 20% / 18% / 8% |

**注意**:
- CoinGlass 默认显示 BTC 数据，需点 ETH 选项卡才看到 ETH 合约数据
- 页面有实时 WebSocket 推送，截取时注意时间戳
- 大额订单（Large Trades）在页面底部，具有参考价值
- 数据每小时更新一次，多空比在重大行情前往往有极端值

---

## 4️⃣ 采集频率建议

| 数据 | 推荐频率 | 说明 |
|------|----------|------|
| BTC ETF 流入/流出 | 每周 1-2 次 | Farside 在盘前 20:30 更新，周五收盘后最适合 |
| US 股指 (SPX/DJI/VIX) | 每周 1-2 次 | 跟随 ETF 一起采集，美东周五收盘后 |
| BTC 合约多空比 | 每周 1-2 次 | 跟随 ETF 一起采集 |
| ETH 合约多空比 | 每周 1 次 | 跟随 BTC 合约一起采集 |

**建议批量采集周期**:
- **常规**: 每周六北京时间早 07:00-08:00（对应美东周五 19:00-20:00，美股已收盘，数据完整）
- **事件触发**: FOMC 决议日、CPI/NFP 发布日、BTC 单日波动 >3% 
- **可省略周中**：如果没有重大行情，周中数据参考意义有限

---

## 5️⃣ 数据存储规范

### 文件命名
```
data/market/etf-spx-contract-{YYYY-MM-DD-HHMM}.json
```
示例: `data/market/etf-spx-contract-2026-06-24-0738.json`

### JSON 结构
```json
{
  "meta": {
    "scan_time": "2026-06-24T07:38:00+08:00",
    "scan_time_utc": "2026-06-23T23:38:00Z",
    "scanner": "browser_manual | subagent G-xxx",
    "note": "optional context"
  },
  "sections": {
    "btc_etf_flows": { ... },
    "us_stock_indices": { ... },
    "btc_contract_long_short_ratio": { ... },
    "eth_contract_long_short_ratio": { ... }
  },
  "gaps_and_notes": [ "any issues or pending data" ]
}
```

### 引用规范
简报引用时使用 `data/market/etf-spx-contract-YYYY-MM-DD-HHMM.json`。

---

## 6️⃣ 浏览器操作步骤（子智能体或手动）

### 采集步骤

1. **打开 Farside** → `https://farside.co.uk/btc/`
   - 等待表格渲染完成
   - 识别每日流量表（Daily Flow Table）
   - 从上到下逐行记录每只 ETF 当日流量和累计流量

2. **打开 Investing.com SPX** → `https://www.investing.com/indices/us-spx-500`
   - 等待页面完全加载（注意右上角报价面板）
   - 提取: 当前价、涨跌、涨跌幅、开盘价、日内区间、52周区间
   - 检查 "Futures" 板块获取 SPX 期货价格

3. **打开 CoinGlass** → `https://www.coinglass.com/LongShortRatio`
   - 等待页面渲染（多空仪表盘会闪烁，耐心等待 3-5 秒）
   - 提取: 全局多空比、Top 5 交易所多空比、聪明钱偏
   - 下拉查看 Address Sentiment 区块

4. **保存数据** → 写入 `data/market/etf-spx-contract-{timestamp}.json`

**自动化提示**: 可用 playwright-mcp Skill 中的 `browser tool` 实现半自动化采集。Playwright 脚本位于 `data/market/` 目录可参考现有的 `etf-spx-contract-*.json` 格式。

---

## 7️⃣ 参考实现

现有的 `data/market/etf-spx-contract-2026-06-24-0738.json` 是完整的示例输出，包含:
- BTC ETF 12 只基金、13 天每日流量
- SPX/DJI/NDX/VIX 全指数
- BTC 合约 24 个交易所多空比、聪明钱信号
- ETH 合约概览（部分）

新采集的 JSON 应维持相同的 schema 结构，以便简报系统直接读取。
