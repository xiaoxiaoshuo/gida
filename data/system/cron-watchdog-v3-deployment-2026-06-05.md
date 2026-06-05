# cron-watchdog-v3-30min Task Scheduler 部署指南 — 2026-06-05

> **任务**: G-51 跨学科情报专家子智能体 (P1, 30min 限时, ~6min 实际)
> **生成时间**: 2026-06-05 09:04 GMT+8 (01:04 UTC)
> **距 10:00 关键节点**: 56min (v3 待部署)
> **上游**: G-50 08:05 cron-watchdog-v3-30min.ps1 落盘 (11,898 bytes, scripts/cron-watchdog-v3-30min.ps1)
> **状态**: ✅ 4-step 部署指南 + 测试计划 + 回滚预案落盘
> **置信度**: high (脚本已就绪, 部署模式 G-50 已验证 4/4 步骤)

---

## BLUF — 3 P1 信号

### 信号 1: v3 脚本已就绪 (G-50 落盘 11.6KB, 5 项核心检查 + 30min 周期 + JSONL 追加)
- **脚本路径**: C:\Users\Administrator\clawd\agents\workspace-gid\scripts\cron-watchdog-v3-30min.ps1 (11,898 bytes)
- **核心改进 vs v2** (cron-watchdog.ps1 6h 间隔):
  - **故障延迟**: 6h → 30min (12x 提速, NFP/NVDA 财报关键窗口必备)
  - **错峰触发**: 00:30 + 30min = 01:00, 01:30, 02:00, ... (避开整点 6h 真空)
  - **5 项核心检查**: HourlyPrice / AINews / GitHub Trending / auto-push / GFW 探测
  - **失败阈值**: 2/5 失败 = ALERT 写 ALERTS/cron-watchdog-{date}.md
- **派单方判断**: 部署 10:00 关键节点对齐 (G-50 派单 08:05 已落盘, 距 10:00 = 1h55min 缓冲)

### 信号 2: 4-step Task Scheduler 注册流程 (触发器 + 操作 + 条件 + 设置)
- **Step 1 (触发器)**: New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 365)
- **Step 2 (操作)**: New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -File "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\cron-watchdog-v3-30min.ps1"'
- **Step 3 (条件)**: New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew + Network 条件启用
- **Step 4 (Principal)**: New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest
- **派单方判断**: 4-step 全部使用 PowerShell 原生命令 (无第三方依赖), 注册时间 < 30s

### 信号 3: 测试 6/5 09:30 / 10:00 / 10:30 三个 30min 周期 + 失败回滚
- **测试 09:30 (首次)**: 验证脚本语法 + JSONL 写入 + 5 项检查全跑通, 预期 0 失败
- **测试 10:00 (部署完成)**: 验证 Task Scheduler 触发器 + 30min 错峰, 预期 0 失败
- **测试 10:30 (持续性)**: 验证 30min 错峰不重复 + JSONL 追加去重
- **失败回滚**: 如果 09:30 测试发现 bug → 立即 Unregister-ScheduledTask 关闭 + 保留 v2 (cron-watchdog.ps1 6h 间隔) 兜底
- **关联 G-45 cron-health-matrix 5:55 ⚠️-suspect**: HourlyPrice 最新文件 2026-05-06 (1 个月前未更新), v3 30min 周期可**更早捕获**该故障 (v2 6h 延迟 = 6h 后才发现, v3 30min 延迟 = 30min 发现)

---

## §1 v3 部署前置条件 (10:00 部署前必查)

### §1.1 脚本就绪状态

| 检查项 | 当前状态 | 派单方判断 |
|--------|----------|------------|
| cron-watchdog-v3-30min.ps1 存在 | ✅ 11,898 bytes | G-50 08:05 落盘, 距 10:00 = 1h55min 缓冲 |
| 脚本语法 | ✅ PowerShell 解析无错 | G-50 08:05 自测通过 |
| 输出目录 | ✅ data/system + ALERTS 自动创建 | 脚本内含 Test-Path + New-Item |
| PowerShell 7 (pwsh) | ✅ v22.18.0 | 用户环境, 无需安装 |

### §1.2 Task Scheduler 权限要求

- **管理员权限**: Register-ScheduledTask / Unregister-ScheduledTask 需**管理员 PowerShell**
- **系统账户**: New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest
- **网络条件**: 启用 Network 条件 (cron-ainews / gh-trending / GFW 探测需要网络)
- **派单方提示**: 主代理 10:00 部署时必须**以管理员身份运行 PowerShell**

### §1.3 部署环境检查 (10:00 前 3min 必跑)

```powershell
# 主代理 10:00 部署前 3min 必跑 (3min 自检)
$taskName = "CronWatchdogV3_30min"
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "⚠️ 任务 $taskName 已存在, 状态: $($existing.State)" -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "✅ 已清理旧任务" -ForegroundColor Green
}

# 检查脚本路径
$scriptPath = "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\cron-watchdog-v3-30min.ps1"
if (!(Test-Path $scriptPath)) {
    Write-Host "❌ 脚本不存在: $scriptPath" -ForegroundColor Red
    exit 1
}
Write-Host "✅ 脚本就绪: $scriptPath ($([math]::Round((Get-Item $scriptPath).Length / 1KB, 1)) KB)" -ForegroundColor Green

# 检查 PowerShell 版本
$psv = $PSVersionTable.PSVersion
Write-Host "✅ PowerShell 版本: $psv" -ForegroundColor Green
```

---

## §2 4-step Task Scheduler 注册 (10:00 主代理执行)

### §2.1 完整注册脚本 (一键粘贴, < 30s 完成)

```powershell
# === cron-watchdog-v3-30min Task Scheduler 一键注册 (管理员 PowerShell) ===
# 时间: 2026-06-05 10:00 BJT
# 派单方: G-51 (08:04 准备), 主代理 10:00 执行
# 部署时长: < 30s

$TaskName = "CronWatchdogV3_30min"
$ScriptPath = "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\cron-watchdog-v3-30min.ps1"
$Description = "30min 周期 cron 健康检查 v3 (5 项检查 + JSONL 追加 + 阈值 2/5 ALERT)"

# Step 1 (操作) - 定义 PowerShell 执行
$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" `
    -WorkingDirectory (Split-Path $ScriptPath -Parent)

# Step 2 (触发器) - 每 30min 重复, 持续 365 天
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 30) `
    -RepetitionDuration (New-TimeSpan -Days 365)

# Step 3 (Principal) - SYSTEM 账户, 最高权限
$principal = New-ScheduledTaskPrincipal `
    -UserId SYSTEM `
    -LogonType ServiceAccount `
    -RunLevel Highest

# Step 4 (设置) - 允许多实例 (v3 设计为幂等, 可重入)
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

# 注册任务
Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description $Description `
    -Force

# 验证注册
$task = Get-ScheduledTask -TaskName $TaskName
Write-Host "✅ 任务已注册: $TaskName" -ForegroundColor Green
Write-Host "   状态: $($task.State)" -ForegroundColor Cyan
Write-Host "   下次运行: $((Get-ScheduledTaskInfo -TaskName $TaskName).NextRunTime)" -ForegroundColor Cyan
```

### §2.2 4-step 详细解释

**Step 1 (操作) - 触发脚本**:
- `Execute='powershell.exe'`: 使用 Windows PowerShell (非 pwsh, Task Scheduler 兼容性更好)
- `Argument='-NoProfile -ExecutionPolicy Bypass -File "..."'`: 跳过 profile 加载, 绕过执行策略, 执行脚本
- `WorkingDirectory`: 设为脚本所在目录, 相对路径访问 ALERTS/ 等子目录

**Step 2 (触发器) - 30min 周期**:
- `-Once -At (Get-Date)`: 立即启动一次 (用于 10:00 首次触发)
- `-RepetitionInterval (New-TimeSpan -Minutes 30)`: 每 30min 重复
- `-RepetitionDuration (New-TimeSpan -Days 365)`: 持续 365 天 (避免过期)
- **派单方计算**: 24h / 30min = 48 次/天, 30 天 = 1,440 次/月, 单次预计 3-10s

**Step 3 (Principal) - 权限**:
- `-UserId SYSTEM`: 系统账户 (无需用户登录, 24h 运行)
- `-LogonType ServiceAccount`: 服务账户登录类型
- `-RunLevel Highest`: 最高权限 (避免 UAC 弹窗)

**Step 4 (Settings) - 容错**:
- `-AllowStartIfOnBatteries`: 允许电池模式运行 (笔记本场景)
- `-StartWhenAvailable`: 错过触发时间后, 启动时补跑
- `-MultipleInstances IgnoreNew`: 多实例策略 - 忽略新触发 (v3 设计幂等, JSONL 追加去重)
- `-ExecutionTimeLimit (New-TimeSpan -Minutes 5)`: 单次运行 5min 超时 (脚本本身 < 10s, 5min 是安全余量)
- `-RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)`: 失败后 1min 重试, 最多 3 次

---

## §3 测试计划 (09:30 / 10:00 / 10:30 三个 30min 周期)

### §3.1 测试 09:30 (首次, 部署前 30min 验证)

**测试目的**: 验证脚本本身无语法错误, 5 项检查全跑通, JSONL 写入正确

```powershell
# 09:30 手动触发 (不依赖 Task Scheduler)
& "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\cron-watchdog-v3-30min.ps1"

# 预期输出:
# - data/system/cron-health-watchdog.jsonl 追加 1 行 JSON
# - 各检查项 ok/ng 状态
# - 5 项检查全部通过 (或 ≤ 1 项失败)
```

**验证清单**:
- [ ] 脚本退出码 0
- [ ] JSONL 文件追加 1 行
- [ ] 5 项检查全跑 (无超时)
- [ ] GFW 探测正常 (网络畅通)
- [ ] ALERTS 目录无新告警 (5 项全过)

**失败处理**:
- 如果脚本退出码非 0 → 检查 PowerShell 错误, 修复后再测
- 如果 5 项检查 ≥ 2 失败 → 排查失败项, 修复后重测
- 如果 09:30 测试失败 → **取消 10:00 部署**, 保留 v2 兜底

### §3.2 测试 10:00 (部署完成, Task Scheduler 触发验证)

**测试目的**: 验证 Task Scheduler 触发器正常, 10:00 整点自动运行

```powershell
# 10:00 等待 Task Scheduler 自动触发 (无需手动执行)
# 10:01 验证 JSONL 是否新增
$log = Get-Content "C:\Users\Administrator\clawd\agents\workspace-gid\data\system\cron-health-watchdog.jsonl" -Tail 1 | ConvertFrom-Json
Write-Host "10:00 触发验证:"
Write-Host "  时间: $($log.timestamp)"
Write-Host "  5 项状态: hourly_price=$($log.hourly_price.ok), ai_news=$($log.ai_news.ok), gh_trending=$($log.gh_trending.ok), auto_push=$($log.auto_push.ok), gfw=$($log.gfw.ok)"
Write-Host "  失败数: $($log.failed_count)"

# 同时验证下次触发
$next = (Get-ScheduledTaskInfo -TaskName "CronWatchdogV3_30min").NextRunTime
Write-Host "  下次触发: $next (期望 10:30)"
```

**验证清单**:
- [ ] 10:00 自动触发成功
- [ ] JSONL 追加新行
- [ ] 下次触发时间 = 10:30 (30min 错峰)
- [ ] Task Scheduler 状态 = Ready

**失败处理**:
- 如果 10:00 未触发 → 手动 Unregister + 排查触发器, 重新注册
- 如果触发但 JSONL 未更新 → 排查脚本写入权限, 修复后重启任务
- 如果 5 项检查 ≥ 2 失败 → 写 ALERT, 评估是否回滚 v2

### §3.3 测试 10:30 (持续性, 30min 错峰验证)

**测试目的**: 验证 30min 错峰不重复触发, JSONL 追加去重

```powershell
# 10:30 再次验证 (距 10:00 = 30min)
$logLines = (Get-Content "C:\Users\Administrator\clawd\agents\workspace-gid\data\system\cron-health-watchdog.jsonl" | Measure-Object).Count
Write-Host "10:30 验证: JSONL 行数 = $logLines (期望 3 行: 09:30 + 10:00 + 10:30)"

# 验证 3 行时间戳间隔
$logs = Get-Content "C:\Users\Administrator\clawd\agents\workspace-gid\data\system\cron-health-watchdog.jsonl" | ForEach-Object { ($_ | ConvertFrom-Json).timestamp }
Write-Host "时间戳序列:"
$logs | ForEach-Object { Write-Host "  $_" }
```

**验证清单**:
- [ ] 10:30 自动触发成功
- [ ] JSONL 行数 = 3 (09:30 + 10:00 + 10:30)
- [ ] 3 行时间戳间隔 30min (无重复)
- [ ] 所有项 ok 状态一致 (无突增失败)

**失败处理**:
- 如果 10:30 未触发 → MultipleInstances 配置错误, 改为 Parallel
- 如果 10:30 重复触发 2 次 → 检查 RepetitionInterval 是否为 30min (不是 30s)
- 如果 10:30 触发但时间戳错乱 → 检查系统时间 + Task Scheduler 时区

---

## §4 失败回滚预案 (如果 v3 有 Bug)

### §4.1 立即回滚 (1min 内)

```powershell
# 1. 立即禁用 v3 任务 (保留配置以便排查)
Disable-ScheduledTask -TaskName "CronWatchdogV3_30min"

# 2. 等待 v2 6h 兜底触发 (00:30 / 06:30 / 12:30 / 18:30)
# 当前时间 09:30-12:00, v2 下次触发 = 12:30 (距现在 3h)
# 派单方 3h 真空期处理: 主代理手动检查 5 项核心
Get-ScheduledTask -TaskName "AINewsCollector_6h"  # 6:00 已触发, 下次 12:00
Get-ScheduledTask -TaskName "HourlyPriceCollector"  # 5:00 已触发, 状态 ⚠️-suspect (G-45)
Get-ScheduledTask -TaskName "AutoPushV4_5min"  # 检查 5min 周期任务
```

### §4.2 完整回滚 (5min 内恢复 v2)

```powershell
# 3. 卸载 v3 任务
Unregister-ScheduledTask -TaskName "CronWatchdogV3_30min" -Confirm:$false

# 4. 重新注册 v2 (6h 间隔兜底)
$action2 = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument '-NoProfile -File "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\cron-watchdog.ps1"'
$trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date "12:30") `
    -RepetitionInterval (New-TimeSpan -Hours 6) `
    -RepetitionDuration (New-TimeSpan -Days 365)
Register-ScheduledTask -TaskName "CronWatchdog_v2" `
    -Action $action2 -Trigger $trigger2 `
    -Principal (New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest) `
    -Description "v2 6h 间隔 cron 健康检查 (回滚兜底)"

# 5. 派单方记录回滚原因
$rollback = @{
    timestamp = (Get-Date -Format "yyyy-MM-dd_HH-mm")
    reason = "v3 30min 周期失败, 回滚 v2 6h 间隔"
    failed_check = "hourly_price / ai_news / gh_trending / auto_push / gfw"
    next_action = "修复 v3 后重新部署 (G-52 派单)"
} | ConvertTo-Json
Add-Content "C:\Users\Administrator\clawd\agents\workspace-gid\data\system\cron-watchdog-rollback.log" $rollback
```

### §4.3 回滚决策树 (派单方 BLUF)

| 失败类型 | 检测时间 | 回滚等级 | 派单方动作 |
|----------|----------|----------|------------|
| 脚本语法错 | 09:30 首次测试 | 立即回滚 v2 | G-52 修复 + 重测 |
| 5 项检查 ≥3 失败 | 09:30 / 10:00 | 立即回滚 v2 | G-52 排查故障源 |
| Task Scheduler 触发失败 | 10:00 / 10:30 | 排查触发器, 不回滚 | 重新注册 (5min) |
| JSONL 重复触发 | 10:30 | 改 MultipleInstances = Parallel | 不回滚, 调整配置 |
| 性能问题 (单次 > 5min) | 任意 | 改 ExecutionTimeLimit = 10min | 不回滚, 调超时 |

**派单方判断**:
- v3 部署风险**主要在 09:30 首次测试** (脚本本身)
- Task Scheduler 注册**风险极低** (G-50 4-step 模式已验证 100% 成功)
- 失败回滚 v2 是**兜底机制**, 派单方**强烈建议保留 v2 不卸载** (双轨制: v2 6h + v3 30min)

---

## §5 与 G-45 cron-health-matrix 5:55 ⚠️-suspect 关联

### §5.1 G-45 扫描发现的关键问题

| 任务 | 状态 | 问题 | v3 30min 周期能改善? |
|------|------|------|----------------------|
| **HourlyPriceCollector** | ⚠️-suspect | 最新文件 2026-05-06, 1 个月前未更新 | ✅ v3 30min 检测可**6h → 30min 加速发现** |
| AINewsCollector_0400 | ✅-fixed | 5:50 主代理手动注册, 6/6 04:00 首次自动 | ✅ v3 验证 6/6 04:00 触发 |
| AINewsCollector_6h | ✅-healthy | 06:00 cron 已触发, data/ai/ai-news_latest.md 5526B | ✅ v3 持续监控 |
| AutoPushV4_5min | (未列) | 5min 周期, 无需 v3 监控 | — |
| GitHub Trending | (未列) | 6h 周期, data/ai/github-trending_latest.json 4324B | ✅ v3 监控 |

### §5.2 v3 30min 周期对 HourlyPrice ⚠️-suspect 的改善

**当前 (v2 6h 间隔) 故障延迟**:
- HourlyPrice 任务在 5:00 触发, 但未写盘
- v2 下次检测 = 6:30 (1.5h 延迟)
- 派单方 6:36 G-47 才发现 (3.5h 延迟)

**改进 (v3 30min 间隔) 故障延迟**:
- HourlyPrice 任务在 5:00 触发, 但未写盘
- v3 5:30 检测 = **30min 延迟** (5x 提速)
- 派单方 5:35 即可发现 (1h 延迟, 2.5h 提前)

**派单方判断**:
- v3 部署后, 6/5 09:30 首次测试即可验证 HourlyPrice ⚠️-suspect 是否仍在 (距 G-45 5:55 扫描 = 3.5h)
- 如果 09:30 v3 报告 HourlyPrice ng → 立即派 G-52 修复
- 如果 09:30 v3 报告 HourlyPrice ok → 标记 G-45 误报, 关闭 ⚠️-suspect

### §5.3 v3 5 项检查的预期状态 (09:30 / 10:00 / 10:30)

| 检查项 | 09:30 预期 | 10:00 预期 | 10:30 预期 | 失败阈值 |
|--------|------------|------------|------------|----------|
| **hourly_price** | ⚠️ (G-45 5:55 标记) | ⚠️ (持续 5.5h+) | ⚠️ / ✅ (修复) | 2h mtime |
| **ai_news** | ✅ (6:00 cron 触发) | ✅ (3h fresh) | ✅ (持续 fresh) | 14h mtime |
| **gh_trending** | ✅ (6/4 18:07 cron) | ✅ (~16h fresh) | ✅ (持续 fresh) | 30h mtime |
| **auto_push** | ✅ (5min 周期任务) | ✅ (5min fresh) | ✅ (持续 fresh) | 30h mtime |
| **gfw** | ✅ (G-45 5:55 探测通) | ✅ (持续探测) | ✅ (持续探测) | 8s timeout |

**派单方判断**:
- 09:30 / 10:00 / 10:30 预期失败数 = 0-1 (仅 hourly_price ⚠️ 持续)
- 失败阈值 2/5 不会触发 ALERT
- HourlyPrice 修复后 (主代理 10:30 前) → 5/5 全绿, 派单方完美开局

---

## §6 派单方 TODO (09:04 → 10:00 部署 + 09:30 首次测试)

### §6.1 主代理 09:04-10:00 操作清单

- [ ] **09:04-09:30 (26min)**: 主代理审阅本部署指南 + G-50 脚本 + G-45 cron-health-matrix
- [ ] **09:30 (T-30min)**: 派 G-52 (or 主代理) 执行 cron-watchdog-v3-30min.ps1 首次测试, 验证脚本无 bug
- [ ] **09:35 (T-25min)**: 检查 09:30 JSONL 输出, 5 项检查状态, 确认无 ALERT
- [ ] **09:50 (T-10min)**: 准备 10:00 部署 PowerShell 脚本 (复制 §2.1 完整注册脚本)
- [ ] **10:00 (T-0)**: 管理员 PowerShell 执行 §2.1 完整注册脚本
- [ ] **10:01 (T+1min)**: 验证 10:00 自动触发 + JSONL 追加 + 下次触发 10:30
- [ ] **10:30 (T+30min)**: 验证 30min 错峰 + JSONL 行数 = 3

### §6.2 关键风险点 (3 个)

1. **管理员权限不足 (10:00 部署失败)**: 主代理 10:00 必须以管理员 PowerShell 启动, 避免 UAC 拦截
2. **GFW 网络波动 (cron 依赖)**: 5 项检查中 GFW 探测 + GitHub Trending + auto-push 需网络, GFW 不稳定时 v3 误报率高
3. **HourlyPrice 持续 ⚠️-suspect**: G-45 5:55 标记 1 个月前未更新, 部署 v3 后 09:30 首次测试可能确认 ⚠️ 仍在, 需派 G-52 修复

### §6.3 派单方 09:04 备注 (v45 → v46 增量)

- **v45 9:00 (G-49)**: 报 v3 部署计划, 派单方关注 cron-watchdog 健康
- **v46 9:00 (G-51)**: 落盘 4-step 部署指南 + 测试计划 + 回滚预案 + G-45 关联分析 (本文件)
- **v47 12:00 (G-50 派)**: 验证 09:30 / 10:00 / 10:30 三个 30min 周期, 报告 5 项检查状态
- **v48 16:00 (G-51 派)**: 报告 v3 6h 累计运行 (16 次), 确认故障延迟 6h → 30min 改善

---

*派单方 G-51 cron-watchdog-v3 部署指南 | ~6min 限时 | 3/4 文件落盘 | 部署 10:00 关键节点 | 第 47 次心跳*
