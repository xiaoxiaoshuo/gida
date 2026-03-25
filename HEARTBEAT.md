# HEARTBEAT.md - 定时检查清单

## ✅ 已完成
- [x] **黄金/原油价格BUG已修复**：脚本升级到v6c，支持直接抓取goldprice.org和oilprice.com
  - 修复：添加合理性阈值检查（GOLD<500,OIL<20视为错误）
  - 当前价格：GOLD=$4,494/oz, OIL=$91.13/barrel（手动补充）
  - 问题：自动采集脚本Bing搜索无法提取宏观商品价格，需后续改进

## 🔄 每4小时检查（rotate through these）
- [ ] **GitHub推送状态**：检查是否还有502，尝试手动推送
- [ ] **加密货币价格**：读取 `prices_latest.json`，BTC/ETH/SOL 趋势是否合理
- [ ] **F&G指数**：读取 `prices_latest.json` 中 alternative.me FNG 值，评估市场情绪
- [ ] **简报更新**：检查 `DAILY/briefings.md` 是否在最近4小时内更新

## 📝 每次心跳
- [ ] 检查 `memory/YYYY-MM-DD.md` 是否有新的工作记录需要提炼到 MEMORY.md
- [ ] 是否有新commit但未推送成功？（检查 git log vs origin/main）

## 🚨 告警触发条件
- BTC 24h波动 > 5% → 记录异常
- Fear&Greed > 80（极度贪婪）或 < 20（极度恐慌）→ 记录预警
- Git推送连续失败 > 5次 → 发出ALERT

---

*最后更新：2026-03-26 04:17 GMT+8*
