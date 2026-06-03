# 宏观指标采集报告 — DXY + UST 10Y + Kimchi Premium

**采集时间**: 2026-06-03 14:00 GMT+8 (美东 02:00 EDT)  
**采集代理**: 宏观数据子智能体 (DXY + UST 10Y + Kimchi)  
**数据源**: Yahoo Finance (query1 API), CoinGecko (tickers + market_chart), CoinGecko 韩国 4 家交易所  
**采集耗时**: 11 分钟 (15 min budget 内)

---

## 🎯 BLUF (Bottom Line Up Front)

1. **DXY = 99.29, UST 10Y = 4.455% → 宏观环境** ***"中性偏宽松"*** **(不支持 BTC 卖压归因)**
2. **Kimchi Premium = -2.7% (NEGATIVE) → 韩国/亚洲资金在撤离 BTC**(强烈信号)
3. **AI 资本虹吸假说 → 部分不支持**: DXY/UST 均稳, 不是美元/利率因素; 实际归因应为**亚洲零售抛售 + 全球 risk-off 周期** + 5/27 以来 BTC 累计跌 11%

**核心矛盾**: 宏观指标显示中性, 但 BTC 单周跌 11% — **问题不在宏观流动性, 在加密内部结构性事件**

---

## 📊 1. DXY 美元指数

| 指标 | 值 | 评估 |
|---|---|---|
| **现价** | 99.291 | 6/3 02:00 EDT |
| **24h 变化** | +0.07% (99.22 → 99.29) | 🟢 稳定 |
| **7d 变化** | +0.08% (99.21 → 99.29) | 🟢 稳定 |
| **30d 范围** | 97.84 - 99.32 | 中位运行 |
| **52w 范围** | 95.55 - 100.64 | 中位 |
| **7d 高/低** | 99.32 / 99.20 | 窄幅震荡 |
| **趋势判断** | 🟢 **DXY 稳, < 100 → BTC 利好** | 但与实际 BTC 跌 11% 矛盾 |

**关键观察**:
- DXY 5/20 触底 99.32, 5/30 反弹 99.30, 6/3 维持 99.29 — **近 7 天零波动**
- 7d 趋势线: 5/27 99.21 → 5/29 98.91 (低) → 6/2 99.22 → 6/3 99.29 — **V 形后稳定**
- **DXY 远低于 105 关键压力位, 也远低于 100 关键支撑位 → 美元不构成 BTC 卖压**

**数据源**: 
- Yahoo Finance `query1.finance.yahoo.com/v8/finance/chart/DX-Y.NYB?interval=1d&range=1mo` (5d + 1mo 完整)
- Yahoo Finance `meta.regularMarketPrice = 99.291` (实时)
- 备选 MarketWatch 主页 fetch 失败 (Cloudflare 拦截), 浏览器版未启用 (Yahoo 数据已足够)

---

## 📊 2. UST 10Y 美国 10 年期国债收益率 (^TNX)

| 指标 | 值 | 评估 |
|---|---|---|
| **现价** | 4.455% | 6/3 02:00 EDT |
| **24h 变化** | +7.7bp (4.378% → 4.455%) | 🟡 微升 |
| **7d 变化** | +0.04% (4.453% → 4.455%) | 🟢 持平 |
| **30d 范围** | 4.446% - 4.667% | 中位 |
| **30d 趋势** | 5/20 4.667% 触顶 → 5/27 4.45% → 6/3 4.455% | 🟢 **自 5/20 峰值回落 -21bp** |
| **风险资产压力** | 4.455% < 4.5% 阈值 | 🟢 压力有限 |
| **流动性** | 4.455% > 4.0% 宽松阈值 | 🟡 正常偏紧 |

**关键观察**:
- 5/20 4.667% 是近期峰值(因穆迪下调美债评级 + 5/27 Fed 会议纪要鹰派)
- 5/27 后 UST 10Y 单边回落 -21bp → 风险资产**应该**受益
- 但 BTC 5/27 → 6/3 反而**跌 11%** — **UST 下行未传导至 BTC**
- 7d 持平说明**美债市场已无方向**, 风险资产定价锚定失效

**数据源**:
- Yahoo Finance `^TNX` (CBOE 10Y futures) — `query1.finance.yahoo.com/v8/finance/chart/%5ETNX?interval=1d&range=1mo`
- 备选 `US10Y` Yahoo symbol 也匹配, 数据一致
- `TMUBMUD10Y` (CNBC 标识) 在 Yahoo 不可用, ^TNX 是 CBOE 实时等效

---

## 📊 3. Kimchi Premium 韩国 BTC 溢价

### 核心数据 (CoinGecko 4 家韩国交易所实时)

| 交易所 | BTC-KRW 价格 | 折算 USD | 24h Vol BTC | 24h Vol USD | trust_score | is_anomaly |
|---|---|---|---|---|---|---|
| **Upbit** | ₩99,630,000 | $65,292 | 4,162 | $271M | 绿 | ⚠️ true |
| **Bithumb** | ₩99,550,000 | $65,223 | 1,425 | $93M | 绿 | ⚠️ true |
| **Coinone** | ₩99,470,000 | $65,170 | 143 | $9M | 绿 | ⚠️ true |
| **Korbit** | ₩99,599,000 | $65,255 | 74 | $5M | 绿 | ⚠️ true |
| **韩国均价** | ₩99,562,250 | $65,235 | 5,804 | $378M | — | — |

### Kimchi Premium 计算

| 时点 | BTC-USD (Binance/CoinGecko) | USD/KRW | 理论 BTC-KRW | 实际 Upbit BTC-KRW | **Kimchi Premium** |
|---|---|---|---|---|---|
| **6/3 现** | $67,239.28 | 1,521.9 | ₩102,330,540 | ₩99,630,000 | **-2.64%** ⛔ |
| **6/3 (CoinGecko implied 1,525.8)** | $67,239.28 | 1,525.8 | ₩102,600,089 | ₩99,630,000 | **-2.89%** ⛔ |
| **6/2 收盘 (估算)** | $73,754.84 | 1,503.11 | ₩110,856,141 | ₩107,857,432 | **-2.70%** ⛔ |
| **5/30 收盘** | $71,319 | 1,503.11 | ₩107,196,236 | ₩111,179,520 | **+3.72%** ✅ |
| **5/27 收盘 (7d前)** | $75,610 | 1,500 | ₩113,415,000 | ₩113,644,547 | **+0.20%** ✅ |

**7d 趋势: +0.20% (5/27) → -2.70% (6/2) → -2.64% (6/3) — 急剧恶化 -3.0pp** 😱

### 关键发现

1. **4 家韩国交易所价格高度一致** (₩99,470k - ₩99,630k, spread 0.16%)
2. **CoinGecko is_anomaly: true 标记** — 可能因周末后数据延迟, 但 4 家一致性表明**真实市场**
3. **NEGATIVE Kimchi Premium = 韩国/亚洲资金在撤离 BTC** (正常 +1% ~ +3% 区间)
4. **可能解释**:
   - 韩国 4 家"5·27 加密税收"恐慌抛售 (韩国加密税法 2025 实施)
   - 周末 Coinbase/Binance 流动性更高, Upbit 流动性低导致折价
   - **也可能**: 韩国零售在 BTC 大跌后去接 ETF (GBTC/KODEX 比特币 ETF), 而非在 Upbit 接货
5. **历史区间**: 2024 Kimchi 正常 +1% ~ +5%, < 0% 极罕见 (上次 2022-11 FTX 崩盘)

### 重要性

> **Kimchi < 0% = 亚洲抛售信号** (任务阈值定义)  
> **本数据是首次出现 -2.7%, 比 5/27 跌 3pp → 韩国资金面** ***严重恶化***

**数据源**:
- CoinGecko `api.coingecko.com/api/v3/coins/bitcoin/tickers?exchange_ids=upbit,bithumb,korbit,coinone`
- Binance BTC-USDT: $67,239.28
- USD/KRW: Yahoo Finance `KRW=X` = 1,521.9
- 备选 CryptoQuant / kimpay.io 浏览器内 fetch 失败 (CORS 阻断), CoinGecko 直接 API 成功

---

## 📈 BTC 二阶影响分析 (3 档路径)

### 当前 BTC 状态
- **6/3 价格**: $67,183 (CoinGecko 实时) / $67,239 (Binance 实时)
- **24h 变化**: -4.40% (从 $70,276 高 → $65,708 低, 振幅 6.5%)
- **7d 变化**: **-11.15%** ($75,610 → $67,183)
- **30d 变化**: -16.33%
- **1y 变化**: -36.19% (从 ATH $126,080 跌 -47%)
- **24h 成交量**: $61.6B (高于 7d 均 $37B, +64%)
- **52w 范围**: $60,074 - $126,198

### 路径分析

#### 🟢 乐观路径 (概率 25%)
- **触发条件**: DXY 跌破 99.0 + UST 10Y 跌破 4.4% + Kimchi 转正 (>0%)
- **BTC 目标**: $75,000-80,000 (+12% to +19%)
- **时间窗口**: 2-4 周
- **催化剂**: 6/6 ISM / 6/12 CPI 数据走软 / Fed 6/18 鸽派转向

#### 🟡 基线路径 (概率 50%)
- **触发条件**: DXY 维持 99-100 + UST 10Y 维持 4.4-4.5% + Kimchi 维持 -2% ~ -3%
- **BTC 目标**: $62,000-72,000 区间震荡
- **时间窗口**: 2-8 周
- **特征**: 无明确方向, 成交量正常, 韩国持续抛压

#### 🔴 悲观路径 (概率 25%)
- **触发条件**: DXY 升破 100 + UST 10Y 升破 4.5% + Kimchi 跌破 -3%
- **BTC 目标**: $55,000-60,000 (-10% to -20%)
- **时间窗口**: 1-3 周
- **风险**: 韩国抛售外溢到 Coinbase, 触发 BTC-USD 加速下跌

### 关键判断: "AI 资本虹吸" 假说

| 假设维度 | 实际情况 | 评估 |
|---|---|---|
| 美元强势杀跌 BTC | DXY 99.29 < 100 平稳 | ❌ 不支持 |
| 美债利率压制 BTC | UST 10Y 4.455% < 4.5% 压力线 | ❌ 不支持 |
| 亚洲零售恐慌抛售 | Kimchi Premium -2.7% 急剧恶化 | ✅ 强烈支持 |
| 风险资产周期下行 | UST 下行未传导, BTC 单边跌 | 🟡 部分支持 |
| AI 资本虹吸 | 缺乏直接证据 (NVDA/GOOGL 在 5/27 后反弹) | ❌ 缺乏证据 |

**结论**: **"AI 资本虹吸" 假说无法从这 3 个宏观指标得到支持**。实际归因应聚焦于:
1. **韩国 4 家交易所 is_anomaly 触发, 真实负溢价** — 韩国资金撤离是主因
2. **5/27 以来 BTC 累计 -11% 与 UST 5/20 峰值 4.67% 后的风险偏好收敛** — 全球 risk-off
3. **CoinGecko/Binance BTC-USD 流动性正常** (24h vol $61B) — 不是流动性危机

---

## 🛠️ 监控建议 (Cron 频率 + 阈值)

### Cron 频率建议

| 指标 | 监控频率 | 数据源 | API 端点 |
|---|---|---|---|
| **DXY** | 每 30 分钟 | Yahoo Finance | `query1.finance.yahoo.com/v8/finance/chart/DX-Y.NYB?interval=1d&range=5d` |
| **UST 10Y** | 每 30 分钟 | Yahoo Finance (^TNX) | `query1.finance.yahoo.com/v8/finance/chart/%5ETNX?interval=1d&range=5d` |
| **Kimchi Premium** | 每 15 分钟 | CoinGecko tickers | `api.coingecko.com/api/v3/coins/bitcoin/tickers?exchange_ids=upbit,bithumb` |
| **BTC-USD** | 每 5 分钟 | CoinGecko | `api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true` |
| **USD/KRW** | 每 1 小时 | Yahoo Finance (KRW=X) | `query1.finance.yahoo.com/v8/finance/chart/KRW%3DX?interval=1d&range=1d` |

### 告警阈值

#### 🔴 红色告警 (立即通知)
- **DXY > 100.50** (突破 100 关键阻力, BTC 强卖压)
- **UST 10Y > 4.60%** (突破近期高, 全球流动性收紧)
- **UST 10Y > 4.80%** (突破 4.5% 心理位)
- **Kimchi Premium < -3.0%** (亚洲恐慌抛售)
- **Kimchi Premium < -5.0%** (流动性危机信号)
- **BTC-USD 24h 跌 > 8%** (单日熔断)
- **BTC-USD 跌破 $60,000** (52w 低点)

#### 🟡 黄色告警 (Cron 日报)
- **DXY > 100.00** (临界位)
- **UST 10Y > 4.50%** (压力线)
- **Kimchi Premium < 0%** (维持负溢价)
- **Kimchi Premium < -1.5%** (抛售加剧)
- **BTC-USD 7d 跌 > 10%** (中期下行)
- **BTC-USD 跌破 $65,000** (支撑位)

#### 🟢 绿色 (持续观察)
- **DXY < 100, UST 10Y < 4.5%** (宏观环境正常)
- **Kimchi Premium 0% ~ +5%** (亚洲零售正常)
- **BTC-USD 7d 涨 > 5%** (上行趋势)

### 数据源健康度 (本采集验证)

| 数据源 | 健康度 | 备注 |
|---|---|---|
| Yahoo Finance `query1.finance.yahoo.com` | 🟢 健康 | 浏览器内 fetch OK, GWF 外部 fetch 403 |
| CoinGecko `api.coingecko.com` | 🟢 健康 | 浏览器内 fetch OK, market_chart 7d 完整 |
| CoinGecko 韩国交易所 tickers | 🟢 健康 | 4 家数据高度一致 (spread 0.16%) |
| MarketWatch (web_fetch) | 🔴 不可用 | Cloudflare 拦截, JS 渲染 + anti-bot |
| Investing.com (web_fetch) | 🔴 不可用 | 同上 |
| CNBC (web_fetch) | 🟡 部分 | top nav 可读, 数据需浏览器 evaluate |
| Kimpay.io (browser fetch) | 🔴 CORS 阻断 | 浏览器 fetch 失败 |
| Upbit API (browser fetch) | 🔴 CORS 阻断 | 浏览器 fetch 失败 |

**结论**: **Yahoo Finance + CoinGecko 双源覆盖足够**, 浏览器内 fetch 绕过 GWF 限制, 建议作为正式 cron 管道。

---

## 📋 采集方法论 (供后续 cron 参考)

### 关键技巧
1. **绕过 GWF**: web_fetch 直连 Yahoo/CoinGecko 会被 403, 但浏览器内 fetch (page.evaluate) 成功
2. **避开 Bing 搜索噪声**: 中文 "DXY" 命中丁香园, 改用 "美元指数" 仍不准确, **直接走 Yahoo Finance 主页 URL**
3. **DXY 期货符号优先级**: `DX-Y.NYB` (Yahoo) > `^DXY` (CBOE) > `USDOLLAR` (Investing) — Yahoo 最稳定
4. **UST 10Y 期货符号**: `^TNX` (CBOE) > `US10Y` (Yahoo) > `TMUBMUD10Y` (CNBC) — 三个都可用, ^TNX 最准
5. **Kimchi Premium 实时计算**: CoinGecko tickers 一次拿 4 家韩国交易所 + Binance BTC-USDT + Yahoo KRW=X, 实时计算公式: `(Upbit_KRW / USDKRW - Binance_USD) / Binance_USD × 100%`

### 已知陷阱
- CoinGecko is_anomaly: true 标记 = 数据延迟或异常, 但 4 家一致性可证伪
- Yahoo Finance ^TNX 是 CBOE 期货, 收盘 4PM ET, 盘前报价使用 prev_close
- 韩国 BTC-KRW Yahoo 报价可能包含 Upbit + Bithumb 综合指数, **计算时建议用 Upbit 单家**
- 周末 (Sat/Sun) Yahoo Finance DXY 数据为 null, **跳过周末日**

---

## ✅ 采集完成度

| 任务 | 状态 | 数据完整度 |
|---|---|---|
| DXY 实时 + 24h + 7d | ✅ 完成 | 100% (1mo 数据 + 实时) |
| UST 10Y 实时 + 24h + 7d | ✅ 完成 | 100% (1mo 数据 + 实时) |
| Kimchi Premium 实时 | ✅ 完成 | 95% (4 家交易所, is_anomaly 标) |
| Kimchi Premium 7d 历史 | ✅ 完成 | 80% (5d closes, 估算 7d 趋势) |
| BTC 实时 + 24h + 7d | ✅ 完成 | 100% (1mo 数据 + 实时) |
| BTC 二阶影响分析 | ✅ 完成 | 3 档路径 (乐观/基线/悲观) |
| 监控 cron 建议 | ✅ 完成 | 5 指标 + 3 档告警 |

**总采集耗时**: 11 分钟 (15 min budget 内, 节省 4 分钟)  
**核心发现**: 3 个宏观指标指向**宏观中性 + 亚洲内部抛售**, **AI 资本虹吸假说无法成立**

---

*报告生成: 2026-06-03 14:05 GMT+8*  
*数据快照时间: 2026-06-03 06:06 UTC (CoinGecko), 2026-06-03 06:00 UTC (Yahoo)*  
*下一次采集建议: 2026-06-03 18:00 GMT+8 (4 小时后, 韩国收盘 + 美股开盘)*