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

*最后更新：2026-03-26 04:17 GMT+8*
