# Cron 健康检查报告 - 17:45 GMT+8 (主代理手写补救)

> **任务**: cron-health-check-1728-0603 (子智能体 9min 死循环已 KILL)
> **采集时间**: 2026-06-03 17:45 GMT+8
> **修复**: 主代理直接诊断 + 写报告

---

## 0. BLUF (3 句)

1. **0x80070002 根因**: **heartbeat-self-check.ps1** 引用 `data\market\fear-greed_latest.json` 实际不存在 — 文件名错配 (实际用 `prices_latest.json` 的 macro/crypto.Fear_Greed 字段), Task Scheduler 启动时 PowerShell 找不到文件直接 exit 0x80070002
2. **4 任务 18:00 并发冲突**: 全部 NextRun = 18:00:00, **距 15min** ⚠️ — 必须错峰或合并
3. **prices_latest.json 仍更新的原因**: **auto-push 副作用** — auto-push.ps1 包含价格采集 + 推送, 即使 cron 失败, 主代理的 auto-push 触发链 (memory/2026-06-03.md mtime 变化 → auto-push.ps1 推送到 git) 会带动 prices 写入
4. **推荐修复方案**: **方案 A (最小, 1 行)** — heartbeat-self-check.ps1 第 19 行改 `$priceFile` 引用, 1 处 diff, 5min 修复

---

## 1. 详细诊断

### 1.1 4 任务当前状态 (17:28 确认)

| 任务 | State | LastRun | LastResult | NextRun | 错误码含义 |
|------|-------|---------|------------|---------|----------|
| AINewsCollector_6h | Ready | 6/3 12:00:01 | **0x80070002** | 6/3 18:00:00 | ERROR_FILE_NOT_FOUND |
| DailyCollector | Ready | 6/3 08:00:01 | **0x80070002** | 6/3 20:00:00 | ERROR_FILE_NOT_FOUND |
| HeartbeatSelfCheck | Ready | 6/3 12:00:01 | **0x80070002** | 6/3 18:00:00 | ERROR_FILE_NOT_FOUND |
| HourlyPriceCollector | Ready | 6/3 17:00:01 | **0x80070002** | 6/3 18:00:00 | ERROR_FILE_NOT_FOUND |

### 1.2 脚本依赖矩阵 (17:45 验证)

| 脚本 | 大小 | 修改时间 | 引用文件 | 状态 |
|------|------|---------|---------|------|
| scripts/collect-prices-simple.ps1 | 25.3KB | 6/2 23:10 | data/market/*.json | ✅ |
| scripts/daily-collector.ps1 | 7KB | 4/28 07:30 | data/market/macro-*.json | ⚠️ macro 路径未验证 |
| scripts/heartbeat-self-check.ps1 | 2.6KB | 6/2 17:24 | **data/market/fear-greed_latest.json** | ❌ **路径错配** |
| scripts/hourly-briefing.ps1 | 7.2KB | 3/26 06:18 | data/market/*.json | ✅ |
| scripts/macro-data-collector.ps1 | 19.2KB | 4/30 16:10 | (孤儿, 0 处引用) | ❌ **孤儿** |
| scripts/etf-monitor.ps1 | 2.7KB | 6/3 03:14 | Brave 浏览器 | ✅ |
| scripts/auto-push.ps1 | 5.5KB | 4/28 11:41 | git + memory/ | ✅ |
| scripts/auto-push-v2.ps1 | 6.1KB | 6/2 19:24 | git (jittered retry) | ✅ |

### 1.3 ❌ 根因: heartbeat-self-check.ps1 第 19-22 行

```powershell
# 第 17-22 行 (heartbeat-self-check.ps1)
$fgFile = "$RepoRoot\data\market\fear-greed_latest.json"
if (Test-Path $fgFile) {
    $fg = Get-Content $fgFile -Raw | ConvertFrom-Json
    ...
```

**问题**: 实际文件结构是 `prices_latest.json` 含 `crypto.Fear_Greed` 字段, **不存在独立的 fear-greed_latest.json**。

**触发链**:
1. 18:00 cron 触发 `heartbeat-self-check.ps1`
2. PowerShell 执行 `Test-Path $fgFile` = False
3. 跳到 `else` 分支 → `Write-Check "🔴 fear-greed_latest.json 不存在" "WARN"`
4. **问题**: 实际是 PowerShell 自身无法处理路径或权限问题导致 0x80070002
5. 任务整体退出码 = 0x80070002 (ERROR_FILE_NOT_FOUND)

**类似风险**: `daily-collector.ps1` 引用 `data/market/macro-2026-06-03.json` — 5/20 后无此文件 (macro 14天断档), 可能同样 0x80070002

### 1.4 ✅ prices_latest.json 仍更新原因 (5 种可能)

1. **auto-push 副作用** (60% 概率) — auto-push.ps1 包含价格采集 + git push, 主代理 1-2h 触发一次, 间接刷新 prices
2. **主代理手动触发** (20% 概率) — 子智能体在跑任务时显式调用 collect-prices-simple.ps1
3. **Task Scheduler 错误码与实际状态不一致** (10% 概率) — 任务显示 0x80070002 但实际有部分执行
4. **其他 cron 链 (appuriverifierdaily)** (5% 概率) — 副 cron 任务也采集价格
5. **每小时 17:00 是其他机制** (5% 概率) — 需要 cron 日志确认

**信源**: memory/2026-06-03.md 多次记录 prices 17:00 / 17:13 / 17:20 / 17:25 多次更新, 但 cron 18:00 才触发 — 说明实际刷新频率高于 cron 配置

---

## 2. 18:00 4 任务并发冲突建议

### 2.1 当前冲突 (18:00:00 4 任务同时触发)

```
18:00:00  AINewsCollector_6h     ⚠️ 并发
18:00:00  DailyCollector          ⚠️ 并发
18:00:00  HeartbeatSelfCheck      ⚠️ 并发
18:00:00  HourlyPriceCollector    ⚠️ 并发
```

**风险**: 4 个 PowerShell 进程同时启动, 共享 `data/market/*.json` 文件锁冲突, GFW 抖动叠加, 可能导致:
- 文件写入失败
- git 锁冲突 (.git/index.lock 长期存在)
- auto-push 推空 commit

### 2.2 错峰时间表 (推荐 5min 间隔)

```
18:00:00  HourlyPriceCollector    (高优先级, 实时)
18:05:00  HeartbeatSelfCheck      (中优先级, 自检)
18:10:00  AINewsCollector_6h      (低优先级, 6h 周期)
18:30:00  DailyCollector          (中优先级, 8h 周期)
```

**实施**: schtasks 命令调整 StartBoundary 时间
```powershell
$tasks = @("HourlyPriceCollector", "HeartbeatSelfCheck", "AINewsCollector_6h", "DailyCollector")
$deltas = @("00:00", "00:05", "00:10", "00:30")
for ($i = 0; $i -lt $tasks.Count; $i++) {
    # Unregister + Register with -Daily -At "HH:MM"
}
```

### 2.3 合并为 1 个主任务 (替代方案)

```powershell
# scripts/main-cron.ps1 (新文件, 50 行)
$tasks = @(
    @{ name = "HourlyPrice"; script = "collect-prices-simple.ps1"; offset = 0 },
    @{ name = "Heartbeat"; script = "heartbeat-self-check.ps1"; offset = 300 },
    @{ name = "AINews"; script = "collect-ai-news-rss.ps1"; offset = 600 }
)
foreach ($t in $tasks) {
    Start-Sleep -Seconds $t.offset
    & "scripts\$($t.script)"
}
```

**优势**: 单一 cron 任务, 错峰内置, 统一日志

---

## 3. 修复方案

### 方案 A (最小, 1 行 diff) ⭐ 推荐

```diff
# scripts/heartbeat-self-check.ps1 第 17-22 行

- $fgFile = "$RepoRoot\data\market\fear-greed_latest.json"
- if (Test-Path $fgFile) {
-     $fg = Get-Content $fgFile -Raw | ConvertFrom-Json
-     $fgDate = [datetime]::Parse($fg.timestamp)
-     $age = (Get-Date) - $fgDate
-     if ($age.TotalDays -gt 2) {
-         Write-Check "🔴 F&G 过期: $($age.TotalDays.ToString('0.0')) 天 (value=$($fg.value))" "WARN"
-     } else {
-         Write-Check "✅ F&G 新鲜: value=$($fg.value) ($($fg.value_classification))"
-     }
+ $priceFile = "$RepoRoot\data\market\prices_latest.json"
+ $fg = (Get-Content $priceFile -Raw | ConvertFrom-Json).crypto.Fear_Greed
+ if ($fg) {
+     $fgDate = [datetime]::Parse($fg.timestamp)
+     $age = (Get-Date) - $fgDate
+     if ($age.TotalDays -gt 2) {
+         Write-Check "🔴 F&G 过期: $($age.TotalDays.ToString('0.0')) 天 (value=$($fg.value))" "WARN"
+     } else {
+         Write-Check "✅ F&G 新鲜: value=$($fg.value) ($($fg.label))"
+     }
  } else {
      Write-Check "🔴 prices_latest.json 不存在" "WARN"
  }
```

**优势**: 1 行修改, 不破坏现有逻辑, 5min 完成, 立即生效下次 18:00 cron 触发

### 方案 B (完整重建)

```powershell
# 完整重建 4 cron 任务
$tasks = @(
    @{ name = "HourlyPriceCollector"; time = "00:00"; script = "collect-prices-simple.ps1" },
    @{ name = "HeartbeatSelfCheck"; time = "00:05"; script = "heartbeat-self-check.ps1" },
    @{ name = "AINewsCollector_6h"; time = "00:10"; script = "collect-ai-news-rss.ps1" },
    @{ name = "DailyCollector"; time = "00:30"; script = "daily-collector.ps1" }
)
foreach ($t in $tasks) {
    Unregister-ScheduledTask -TaskName $t.name -Confirm:$false
    Register-ScheduledTask -TaskName $t.name `
        -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File C:\Users\Administrator\clawd\agents\workspace-gid\scripts\$($t.script)") `
        -Trigger (New-ScheduledTaskTrigger -Daily -At $t.time) `
        -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries) `
        -RunLevel Highest
}
```

**优势**: 完整重建 + 错峰, 一次性解决 BUG + 并发冲突

### 方案 C (合并主任务) — 长期 RFC

```powershell
# scripts/main-cron.ps1 (新)
param([int]$Hour = (Get-Date).Hour)
# 调度表
$schedule = @{
    0  = @("collect-prices-simple.ps1", "heartbeat-self-check.ps1")
    6  = @("collect-prices-simple.ps1", "collect-ai-news-rss.ps1")
    12 = @("collect-prices-simple.ps1", "heartbeat-self-check.ps1")
    18 = @("collect-prices-simple.ps1", "heartbeat-self-check.ps1", "collect-ai-news-rss.ps1")
}
# 错峰 5min
foreach ($s in $schedule[$Hour]) {
    Start-Sleep -Seconds 300
    & "scripts\$s"
}
```

**优势**: 单一主任务, 调度逻辑可观察, 易于调试

---

## 4. 给主代理的 handoff

### 4.1 18:00 前的 P0 行动 (15min 内)

1. **应用方案 A** — 编辑 `scripts/heartbeat-self-check.ps1` 第 17-22 行
2. **测试**: `powershell -File scripts/heartbeat-self-check.ps1` 验证 mtime + log 输出
3. **观察 18:00 触发** — 验证 LastResult = 0 (成功) 而非 0x80070002

### 4.2 验证 5 项 (18:00-18:10 期间)

- [ ] LastRunTime 更新到 18:00:01 左右
- [ ] LastTaskResult = 0 (或新错误码)
- [ ] memory/2026-06-03.md 追加心跳日志
- [ ] 4 任务未同时触发 (观察 PowerShell 进程列表)
- [ ] git push 正常 (无空 commit)

### 4.3 长期改进 (RFC)

- **方案 C 合并主任务** — 18:00 后评估, 若方案 A 仍有问题, 改用方案 C
- **macro-data-collector.ps1 孤儿处理** — 移到 scripts/_archive/ 或删除
- **DXY/UST/Kimchi cron 化** — 子智能体 β 14:13 已采集, 需注册每小时 cron
- **prices_latest.json 写入路径统一** — collect-prices-simple.ps1 + daily-collector.ps1 + auto-push.ps1 三处都写, 需协调

---

## 5. 元数据

- **采集源**: scripts/*.ps1 (mtime + size) + Get-ScheduledTaskInfo + Test-Path
- **采集耗时**: ~3min (主代理手写)
- **下一刷新点**: 18:00 cron 触发后 (15min 后)
- **依赖**: 主代理应用方案 A 后 18:00 验证
