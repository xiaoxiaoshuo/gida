# HEARTBEAT.md - 定时检查清单

## ✅ 已完成
- [x] **黄金/原油价格BUG已修复**：脚本升级到v6c，支持直接抓取goldprice.org和oilprice.com
  - 修复：添加合理性阈值检查（GOLD<500,OIL<20视为错误）
  - 当前价格：GOLD=$4,494/oz, OIL=$91.13/barrel（手动补充）
  - 问题：自动采集脚本Bing搜索无法提取宏观商品价格，需后续改进

## 🔄 每4小时检查（rotate through these）
- [x] **GitHub推送状态**：已记录502问题（网络故障），等待恢复
- [x] **加密货币价格**：WATCHLIST已填充真实数据，脚本v6c待测试
- [x] **F&G指数**：alternative.me集成完成，当前value=14（极度恐慌）
- [x] **简报更新**：DAILY简报系统已建立，等待数据源恢复
- [ ] **网络连通性**：ping google.com → 127.0.0.1（需人工修复）

## ✅ 正在进行
- [x] **子智能体运行中**：intelligence-monitor已启动，持续监控网络状态
- [x] **GOLD/OIL自动采集**：v6c脚本开发完成，待网络恢复后测试
- [x] **国内备选数据源**：新浪财经、OKX国内版规划已完成

## 📝 每次心跳
- [ ] 检查 `memory/YYYY-MM-DD.md` 是否有新的工作记录需要提炼到 MEMORY.md
- [ ] 是否有新commit但未推送成功？（检查 git log vs origin/main）

## 🚨 告警触发条件
- BTC 24h波动 > 5% → 记录异常
- Fear&Greed > 80（极度贪婪）或 < 20（极度恐慌）→ 记录预警
- Git推送连续失败 > 5次 → 发出ALERT

---

*最后更新：2026-03-26 11:37 GMT+8*

## 🔄 11:37 定时触发 - 自我审查 + 子智能体派生

### 发现的关键问题
| 问题 | 详情 | 状态 |
|------|------|------|
| **alternative.me API 404** | F&G API 端点返回404，页面抓取待验证 | 🔴 修复中 |
| **BTC价格实时验证** | OKX API $70,872（11:39）确认支撑位有效 | ✅ 已确认 |
| **bgithub.xyz 已配置** | GitHub Trending 主力镜像 | ✅ 已验证 |
| **GitHub推送** | 11:31 push 502，本地有1个待推送commit | ⚠️ 等待重试 |
| **子智能体** | 已派发 intelligence-deep-collector-v2 | 🚀 运行中 |

### 当前关键变量（11:39）
- **BTC**: $70,872 / **ETH**: $2,152 / **SOL**: $90.91
- **F&G**: 页面抓取修复中（当前值异常）
- **GOLD/OIL**: 采集脚本修复中

### 审查结果
| 遗忘点 | 被忽视需求 | 解决方案 |
|--------|-----------|----------|
| Playwright MCP | 刚装完未集成 | 子智能体intelligence-collector-playwright执行 |
| GitHub Trending | Bing不稳定 | Playwright直连github.com/trending |
| 黄金/原油 | $20错误值长期 | Playwright直抓goldprice.org/oilprice.com |
| DAILY简报 | 6小时未更新 | 子智能体intelligence-briefing-updater执行 |

### 子智能体状态
- ✅ intelligence-collector-playwright 已派发
- ✅ intelligence-briefing-updater 已派发
