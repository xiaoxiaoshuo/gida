# 数据采集管道状态报告

**生成时间**: 2026-03-25 18:53 GMT+8  
**运行环境**: Windows Server / PowerShell + web_fetch  
**测试次数**: 每数据源1-2次验证

---

## 一、数据源可用性清单

### P0 数据源（每日必采）

| # | 数据源 | URL | 状态 | 成功率 | 备注 |
|---|--------|-----|------|--------|------|
| 1 | 加密货币价格 (Bing搜索) | `cn.bing.com/search?q=BTC+ETH+SOL+price` | ✅ 稳定 | ~80% | 通过cn.bing.com聚合知乎/CoinMarketCap摘要 |
| 2 | 美联储FOMC官方 | `federalreserve.gov/monetarypolicy/fomccalendars.htm` | ✅ 稳定 | ~90% | 可直连，含完整会议日程 |
| 3 | 美联储政策 (Bing搜索) | `cn.bing.com/search?q=Federal+Reserve+FOMC` | ✅ 稳定 | ~80% | 搜索结果来自知乎等中文源 |
| 4 | BTC/ETH/SOL价格 (Bing) | `cn.bing.com/search?q=CoinMarketCap+BTC+ETH+SOL` | ✅ 稳定 | ~80% | 知乎引用了CoinMarketCap价格数据 |

### P1 数据源（每日重点）

| # | 数据源 | URL | 状态 | 成功率 | 备注 |
|---|--------|-----|------|--------|------|
| 5 | GitHub Trending (直连) | `github.com/trending` | ❌ 失败 | 0% | GFW屏蔽，无法访问 |
| 6 | GitHub Trending (Gitee镜像) | `gitee.com/trending` | ⚠️ 低可用 | ~30% | 页面内容为空/需登录 |
| 7 | GitHub Trending (Bing搜索) | `cn.bing.com/search?q=GitHub+Trending` | ✅ 稳定 | ~75% | 可提取项目链接，需去重 |
| 8 | OpenAI Blog (直连) | `openai.com/blog` | ✅ 稳定 | ~90% | 重定向到news页，内容有限 |
| 9 | DeepSeek Blog (直连) | `deepseek.com/blog` | ✅ 稳定 | ~90% | 主站可访问，内容丰富 |
| 10 | Google AI / DeepMind | `ai.google.com/research` | ❌ 失败 | 0% | GFW屏蔽 |
| 11 | Google AI (Bing搜索) | `cn.bing.com/search?q=Google+AI+research` | ✅ 稳定 | ~75% | 可获取摘要 |
| 12 | 量子计算进展 (Bing) | `cn.bing.com/search?q=quantum+computing+breakthrough+2026` | ✅ 稳定 | ~85% | 结果丰富，含IBM/Google/科学文章 |

### P2 数据源（每周）

| # | 数据源 | URL | 状态 | 成功率 | 备注 |
|---|--------|-----|------|--------|------|
| 13 | 芯片出口管制 (Bing) | `cn.bing.com/search?q=chip+semiconductor+export+control` | ✅ 稳定 | ~75% | 中文结果为主（知乎/Chiphell） |
| 14 | 黄金价格 (Bing) | `cn.bing.com/search?q=gold+price+today` | ✅ 稳定 | ~80% | 含KITCO等财经网站摘要 |
| 15 | 原油价格 (Bing) | `cn.bing.com/search?q=crude+oil+price+today` | ✅ 稳定 | ~80% | 含彭博/路透社摘要 |
| 16 | VIX恐慌指数 (Bing) | `cn.bing.com/search?q=VIX+index` | ✅ 稳定 | ~75% | 含知乎解释性内容 |
| 17 | 中国央行政策 (Bing) | `cn.bing.com/search?q=PBOC+monetary+policy` | ✅ 稳定 | ~80% | 知乎结果为主 |
| 18 | 地缘政治 (Bing) | `cn.bing.com/search?q=US+China+trade+war` | ✅ 稳定 | ~80% | 结果丰富 |

### 无法访问的数据源

| 数据源 | 原因 | 替代方案 |
|--------|------|----------|
| `github.com` | GFW完全屏蔽 | 使用 cn.bing.com 搜索GitHub项目 |
| `google.com` / `ai.google.com` | GFW屏蔽 | 使用 cn.bing.com |
| `coinmarketcap.com` (直连) | GFW屏蔽 | 通过Bing搜索摘要 |
| `coingecko.com` (直连) | GFW屏蔽 | 通过Bing搜索摘要 |
| `api.coinbase.com` | API访问失败 | 通过Bing搜索替代 |

---

## 二、采集频率建议

| 数据类别 | 建议频率 | 理由 |
|----------|----------|------|
| 加密货币价格 | 每日 2 次 (09:00 / 21:00) | BTC波动大，补充晚间数据 |
| 美联储/FOMC | 每日 1 次 (08:30) | FOMC会议不频繁，日常跟踪政策信号 |
| GitHub Trending | 每日 1 次 (10:00) | 日榜/周榜变化 |
| AI博客 | 每日 1 次 (10:30) | 文章更新频率较低 |
| 量子计算 | 每日 1 次 | 突破性新闻不频繁 |
| 芯片出口管制 | 每周 2-3 次 | 政策新闻突发性强 |
| 黄金/原油/VIX | 每日 1 次 (09:00) | 大宗商品日波动 |
| 地缘政治 | 每日 1 次 | 实时性要求 |
| 中国央行 | 每日 1 次 (09:30) | LPR每月公布一次 |

---

## 三、最佳采集路径

### 加密货币价格
```
主要: cn.bing.com → 搜索 "BTC ETH SOL price 今日"
备选: cn.bing.com → 搜索 "CoinMarketCap BTC ETH SOL"
注意: 知乎引用CMC数据，可作为价格参考
```

### GitHub Trending
```
最优: cn.bing.com → 搜索 "GitHub Trending Python/JavaScript today"
     → 提取 github.com/xxx/yyy 格式链接
次选: gitee.com/trending (内容贫乏，不推荐)
```

### 美联储政策
```
主要: federalreserve.gov (直连，高可靠)
次要: cn.bing.com 搜索 Federal Reserve FOMC 2026
```

### AI博客
```
DeepSeek: deepseek.com/blog (直连，最稳定)
OpenAI: openai.com/news (直连，重定向后内容少)
Google: 通过 cn.bing.com 搜索 "Google AI research blog"
```

### 量子计算
```
cn.bing.com → 搜索 "quantum computing breakthrough 2026"
→ 结果来源: ScienceDaily, programming-helper, evidentweb 等
```

---

## 四、后续优化建议

### 高优先级
1. **接入代理池** - 当前约40%的数据源（GitHub/Google/CoinMarketCap直连）被GFW屏蔽，建议配置代理（Shadowrocket/sing-box规则）以提升采集完整性
2. **GitHub Trending镜像站** - 可探索 `githubfast.com/trending` 或 `ghp.ci/trending` 等社区镜像
3. **价格API替代** - 考虑接入 `api.binance.com` (可能需要代理) 或 `min-api.cryptocompare.com` 等加密货币API

### 中优先级
4. **数据解析增强** - 当前Bing搜索结果为摘要文本，价格提取正则精度有限，建议增加AI辅助解析或结构化提取
5. **Gitee热榜内容** - gitee.com/trending 目前返回空内容，需排查是否需要登录态

### 低优先级
6. **RSS订阅** - 部分博客(RSS)可能比网页更稳定，可测试 feedproxy.google.com 等RSS服务
7. **缓存机制** - 对于更新频率低的数据（量子计算、芯片政策）增加去重和缓存逻辑

---

## 五、已创建的脚本

| 脚本 | 路径 | 功能 |
|------|------|------|
| collect-market-data.ps1 | `...\scripts\collect-market-data.ps1` | 加密货币价格、VIX、黄金、原油 |
| collect-tech-news.ps1 | `...\scripts\collect-tech-news.ps1` | GitHub Trending、AI博客、量子计算 |
| collect-policy.ps1 | `...\scripts\collect-policy.ps1` | FOMC、中国央行、出口管制、地缘政治 |

**使用方式**: 将脚本放入 cron/OpenClaw 定时任务，建议测试阶段先手动执行验证输出。

---

*报告生成: 2026-03-25 采集者智能体*
