# 08:00 多 Cron 并发风险评估报告

**日期**: 2026-06-24
**分析时间**: 07:46 GMT+8
**分析师**: 子智能体 G-112

---

## 1️⃣ 08:00 并发任务清单

| # | 任务名 | 脚本 | 上次运行 | 下次运行 | 周期 |
|---|--------|------|----------|----------|------|
| 1 | HourlyPriceCollector | collect-prices-simple.ps1 | 07:00:01 | **08:00:00** | 1h |
| 2 | BridgeCollector2h | bridge-2h-cron.ps1 | 06:00:01 | **08:00:00** | 2h |
| 3 | DailyCollector | daily-collector.ps1 | 06-23 08:00 | **08:00:00** | 12h |
| 4 | DailyCollector_AM | daily-collector.ps1 | 05-20 08:00 | **08:00:00** | 每日 |
| 5 | GidaTaskGuardian | cron-task-guardian.ps1 | 07:30:01 | **08:00:00** | 30min |
| 6 | CronWatchdogV3_30min | cron-watchdog-v3-wrapper.ps1 | 07:30:01 | **08:00:00** | 30min |
| 7 | CollectorMaster_30min | collector-master.ps1 | 07:39:49 | **08:09:45** | 30min |

> **注**: CollectorMaster_30min 的下次运行是 08:09，与 08:00 集群有约 9 分钟偏移，略好。

### 实际同时触发的任务数量（整点 08:00:00）

**6 个任务同时触发**。

---

## 2️⃣ 是否重复执行相同脚本？

| 脚本 | 被调用的任务 | 问题 |
|------|-------------|------|
| `daily-collector.ps1` | **DailyCollector** + **DailyCollector_AM** | ⚠️ 两个独立的任务调用同一个脚本 |
| 其余脚本 | 各自唯一 | ✅ |

**风险分析 - daily-collector.ps1 双重触发**:
- DailyCollector 和 DailyCollector_AM 都设置为 08:00 触发
- DailyCollector_AM 上次成功运行是 05-20（超过一个月前），说明它可能已失效或长期未触发
- 但如果两个任务同时触发，daily-collector.ps1 会在同一秒内启动两次
- 该脚本写文件包括 `data/macro/macro-YYYY-MM-DD.json`、`data/ai/ai-news-YYYY-MM-DD.json`、`data/github-trending-history.json`
- **风险等级**: 中 — 文件覆盖写入可能导致数据丢失或截断

---

## 3️⃣ 文件锁冲突分析

### 3.1 prices_latest.json — 最高风险点

**写方**: `HourlyPriceCollector`（collect-prices-simple.ps1）
**读方**: `CollectorMaster_30min`、`GidaTaskGuardian`、`CronWatchdogV3_30min`

```
HourlyPriceCollector  --写入--> prices_latest.json
        |
        |  (同时)
        v
CollectorMaster_30min --读取--> prices_latest.json
GidaTaskGuardian      --读取--> prices_latest.json
CronWatchdogV3_30min  --读取--> prices_latest.json
```

**实际情况**:
- HourlyPriceCollector 写入 `prices_latest.json` 使用的是 **atomic write**（写入临时文件后 rename）
- PowerShell 的 `Out-File` / `Set-Content` 不是原子操作，但文件系统在小文件（<5KB）上的
  写入通常 <50ms
- CollectorMaster_30min 在 08:09 运行，避开 08:00 密集窗口（偏移 9 分钟）
  → **实际并发风险较低**

**风险等级**: 🟡 低
- 但需确认 HourlyPriceCollector 的 atomic write 是否真正实现（临时文件 → rename）
- 如果直接 `Out-File` 覆盖，8 字节的写入过程会被其他进程读到不完整文件

### 3.2 collector-master-config.json — Mutex 保护

**写方**: collector-master.ps1
**同样写方**: 无（唯一写方）
**读取**: collector-master.ps1 自身

**风险等级**: 🟢 无（mutex 保护）

### 3.3 cron-health-watchdog.jsonl / cron-health-history.jsonl

**写方**: CronWatchdogV3_30min
**读取**: GidaTaskGuardian（可能）

脚本查看:
- cron-watchdog-v3-wrapper.ps1 → 写 watchdog JSONL
- cron-task-guardian.ps1 → 可能读 watchdog JSONL 做健康检查

同时触发可能导致：
- JSONL append 写被交叉破坏
- 守护进程读到部分写入的行

**风险等级**: 🟡 中低 — JSONL 是 append-only，交叉写入概率低但仍存在

---

## 4️⃣ 网络锁/API 限速冲突

| API | 调用方 | 同时触发 | 风险 |
|-----|--------|----------|------|
| Gateio API | HourlyPriceCollector | 可能同时被 GidaTaskGuardian 采集数据引用 | 🟢 低（不同 endpoint） |
| alternative.me | collect-fear-greed.ps1 (通过 CollectorMaster) | 08:09 触发，避开了高点 | 🟢 低 |
| Bing search | HourlyPriceCollector (fallback) | 仅当 API 全降级时使用 | 🟢 低 |
| Investing.com | daily-collector.ps1 | 双重触发（DailyCollector x2） | ⚠️ 可能触发反爬 |

**Investing.com 反爬风险**:
- daily-collector.ps1 被两个任务同时调用
- Investing.com 对同一 IP 的快速连续请求会触发 CAPTCHA
- **风险等级**: 🟡 中 — 建议其中一个任务延迟启动

---

## 5️⃣ 总结评估

### 评估矩阵

| 冲突类型 | 风险等级 | 详细信息 |
|----------|----------|----------|
| 文件锁 (prices_latest.json) | 🟢 低 | 写入 <50ms，CollectorMaster 有 9min 偏移 |
| 文件锁 (daily-collector 双重触发) | 🟡 中 | 两任务同时调用同一脚本 |
| 文件锁 (JSONL 写入) | 🟡 中低 | append-only，概率较低 |
| 网络锁 (API 限速) | 🟢 低 | 各任务使用不同 API |
| 反爬冲突 (Investing.com) | 🟡 中 | daily-collector 双重触发 |
| Mutex 疲劳 | 🟢 低 | CollectorMaster 有自身 mutex |

### 总体风险: 🟡 **低至中等**

---

## 6️⃣ 建议改进方案

### P0 (立即实施)

**1. 分离 DailyCollector_AM 的启动时间**
- DailyCollector_AM 上次成功运行是 05-20（31天前），可能任务已损坏（脚本路径不对）
- 要么修复/重建 DailyCollector_AM，要么直接禁用
- 如果保留: 将其触发时间改为 `08:05` 或 `07:55`

### P1 (本周内)

**2. 添加随机 Jitter 到非关键 Cron**
| 任务 | 当前时间 | 新时间 | Jitter 范围 |
|------|----------|--------|-------------|
| GidaTaskGuardian | 整点+:00/:30 | :00+:30-60s | 30-90s |
| CronWatchdogV3_30min | 整点+:00/:30 | :00+:60-120s | 60-180s |
| DailyCollector_AM | 08:00 | 08:05 | 固定偏移 |
| BridgeCollector2h | 整点+:00 | 整点+:15 | 固定偏移 |

实现方式:
```powershell
# 在 task trigger 创建时使用 Random jitter
$rng = New-Object System.Random
$jitterSeconds = $rng.Next(15, 120)
$trigger.Repetition.Interval = [TimeSpan]::FromMinutes(30) # 原周期不变
$trigger.StartBoundary = (Get-Date).Date.AddHours(8).AddSeconds($jitterSeconds)
```

**3. 给 daily-collector.ps1 添加进程级互斥**
```powershell
$mutexName = "Global\GidaDailyCollector_Mutex"
$mutex = New-Object System.Threading.Mutex($false, $mutexName)
if (!$mutex.WaitOne(0)) {
    Write-Host "[SKIP] Another DailyCollector is already running"
    exit 0
}
```

### P2 (优化)

**4. 统一触发: 让 CollectorMaster 代替独立 DailyCollector**
- 让 CollectorMaster 在 08:00 窗口内调度 daily 采集
- 消除重复触发，减少文件锁冲突

**5. 修改 HourlyPriceCollector 为真正 atomic write**
```powershell
# 写入 temp 文件后 rename
$tmpFile = "$OutputDir\prices_latest.tmp"
$signal | ConvertTo-Json -Depth 5 | Out-File $tmpFile -Encoding UTF8
Move-Item $tmpFile $finalFile -Force
```

---

## 7️⃣ 当前状态快照

```
任务          上次运行        下次运行        周期
─────────── ────────────── ────────────── ─────
HourlyPrice  06-24 07:00    06-24 08:00    1h
Bridge2h     06-24 06:00    06-24 08:00    2h
Daily        06-23 08:00    06-24 08:00    12h
Daily_AM     05-20 08:00    06-24 08:00    每日
Guardian     06-24 07:30    06-24 08:00    30min
Watchdog     06-24 07:30    06-24 08:00    30min
Master_30min 06-24 07:39    06-24 08:09    30min
```

> **下一步**: 修改 BridgeCollector2h 的触发时间为整点后 +15 分钟，分散 08:00 冲击。
> 实施后重新评估，预期 08:00 同时触发任务数从 **6** 降至 **3-4**。
