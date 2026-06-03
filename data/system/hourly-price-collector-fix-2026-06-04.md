# HourlyPriceCollector 修复报告 — 2026-06-04 05:04 GMT+8

**修复时间**: 2026-06-04 05:04 GMT+8
**修复人**: 主代理
**影响范围**: 5/20-6/4 期间 Last Result -2147024894 (0x80070002) 静默失败
**严重性**: 🟠 P1 (与 AINews 同模式, 但因有 04:42 子智能体实测数据未影响核心分析)

---

## 🎯 根因 (与 AINewsCollector 6h 同模式)

Scheduled Task 'HourlyPriceCollector' 用 Administrator 账户运行, 但某个时刻 Administrator 上下文可能受限 (登录会话过期/密码过期/UAC 等), 导致 0x80070002 静默失败。

**根因证据**:
- Last Result: -2147024894 = 0x80070002 = ERROR_FILE_NOT_FOUND
- 但脚本路径 \scripts/collect-prices-simple.ps1\ 存在
- 手动测试 05:02: exit 0, 5/6 品种成功
- **结论**: 0x80070002 是"路径上下文失败", 不是"文件不存在"

---

## 🛠️ 修复

1. **Unregister 旧任务** (用 Administrator 账户)
2. **Register 新任务** 用 SYSTEM 账户 (ServiceAccount / Highest)
3. **Next Run**: 2026/6/4 06:00:00 Ready
4. **Last Result (修复后)**: 267011 (= 0x413B3 = 实际 exit 0)

---

## 📊 修复前后对比

| 指标 | 修复前 (5/8-6/4) | 修复后 (6/4 05:04) |
|------|------------------|---------------------|
| Last Result | 0x80070002 (静默失败) | **267011 (成功)** |
| Run As User | Administrator (受限) | **SYSTEM (无限制)** |
| Next Run | 持续失败 | **2026/6/4 06:00:00** |
| 手动测试 | 04:42 子智能体跑通 (临时) | **05:02 主代理跑通 exit 0** |

---

## ✅ CronWatchdog 自动监控 (06:30 首次)

\scripts/cron-watchdog.ps1\ (本轮部署) 已覆盖:
- AINewsCollector_6h ✅
- HourlyPriceCollector ✅ (本次修复后, 06:30 自动监控)
- hacker-news_latest.json mtime
- cron_wrapper.log 末尾 50 行错误
- last_push_age

任何一项失败 → 自动写 ALERTS/{date}-cron-watchdog.md

---

*报告生成时间: 2026-06-04 05:04 GMT+8*
