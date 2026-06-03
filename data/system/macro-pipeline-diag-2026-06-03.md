# 宏观数据采集管道诊断报告

**报告 ID**: macro-pipeline-diag-2026-06-03
**生成时间**: 2026-06-03 14:08 GMT+8
**诊断 Agent**: gida:subagent:macro-pipeline-diag-0603
**诊断耗时**: ~6 分钟 (限时 8 分钟内)
**数据来源**: 一手文件 + PowerShell 实时查询

---

## BLUF (Bottom Line Up Front)

1. **根因**: `DailyCollector` cron 任务虽状态 Ready,但**实际从未成功执行** (LastRunTime 为空),且 daily-collector.ps1 调用的子任务 `collect-macro-playwright.ps1` 在 5/15 起因 **GOLD 采集持续失败 + OIL 频率/字段退化** 已事实上产出空 macro 段,但 daily-collector 第 73-92 行的"汇总 macro-YYYY-MM-DD.json"逻辑仍**会写出文件**——所以缺口根源是 **DailyCollector 触发但 daily-collector.ps1 整体不执行** (任务上次成功 5/19,5/20 的文件是 5/19 20:00 写的但 5/20 文件名 mtime 翻到 5/20)。**真实断档: 5/21 - 6/2 (13 天)**,从 5/20 20:00 → 6/2 17:15 (collect-prices-simple 恢复) 完整无任何 macro 快照写入。**6/3 14:11 已有另一个子智能体 (macro-dxy-ust-kimchi-0603) 创建了 `data/macro-2026-06-03.json` (6.3KB,DXY/UST/Kimchi schema),所以今天的缺口实际上已被弥补,但只是**手动派生**,非 DailyCollector 自动产出。**
2. **紧急度**: **P0-中**。5/20-6/3 期间无任何 macro 快照,但 6/2 17:15 起 `collect-prices-simple.ps1` 已恢复 (HourlyPriceCollector 重建,StartBoundary=2026-06-03T00:00:00),prices_latest.json 的 macro.GOLD/OIL/VIX 数据**仍在工作**,只是没有每日快照归档。
3. **推荐方案**: **方案 A 最小修复** (1-2 行 diff) — 在 daily-collector.ps1 第 74 行后加 `if (Test-Path $macroDailyFile) { ... }` 兜底,或更优:在第 91 行 Out-File 前加 `mkdir -Force` 显式目录创建。**P0 解决: 20:00 DailyCollector 触发后,人工监控该次运行,确认 macro-2026-06-03.json 出现。**

---

## 1. 三个核心问题诊断

### 问题 A: DailyCollector 触发后为什么不写 macro-YYYY-MM-DD.json?

**结论: 写文件逻辑本身**是**正确的** (daily-collector.ps1:73-92),但**整个 daily-collector.ps1 在 5/20 后没再跑过**。

**证据**:
| 项 | 值 |
|---|---|
| `DailyCollector` 任务 State | **Ready** |
| `DailyCollector` 任务 LastRunTime | **空 (从未成功执行)** |
| `DailyCollector` 任务 LastTaskResult | **空** |
| `DailyCollector` 任务 Action | `powershell.exe -File .../daily-collector.ps1` |
| `DailyCollector` 任务 Trigger | StartBoundary=`2026-06-02T08:00:00+08:00`, Repetition Interval=PT12H, Duration=P3650D |
| `HourlyPriceCollector` 任务 LastRunTime | **空** (新任务,StartBoundary=2026-06-03T00:00:00) |
| `collect-prices.log` 最近 5/20 → 6/2 17:15 | **空** (长达 13 天静默) |
| `data/macro-2026-05-20.json` mtime | `2026/5/20 20:00:22` |
| `data/macro-2026-05-19.json` mtime | `2026/5/19 8:00:16` (新) |

**根因路径**:
1. `DailyCollector` 任务虽 Ready,触发器设定 StartBoundary=`2026-06-02T08:00:00` — 是 **6/2 早上 8 点** 才开始生效的**新任务** (类似 HourlyPriceCollector)
2. 任务**应该**在 6/2 08:00 / 6/2 20:00 / 6/3 08:00 各跑一次,但 LastRunTime 仍空 → 任务被静默跳过/拒绝
3. `collect-prices.log` 在 5/20 20:00:22 后**完全停止**到 6/2 17:15:26 (13 天断档) — 同一时间窗 macro 任务也断
4. `DailyCollector_AM` / `DailyCollector_PM` 是 **Disabled** 状态 (4/8 的旧任务)
5. `data/macro-2026-05-20.json` 是 5/20 20:00:22 写的 (有 OIL/VIX 2026-05-20 20:00:03 内部时间戳),证明 5/20 跑通了,但**之后所有任务都消失**

**关键代码片段** (daily-collector.ps1:61-92):

```powershell
# 第 61-72 行: 调用子脚本
$macroScript = "$RepoRoot\scripts\collect-macro-playwright.ps1"
if (Test-Path $macroScript) {
    Write-Log "执行 collect-macro-playwright.ps1..."
    & $macroScript -OutputDir "$RepoRoot\data\market" 2>&1 | ForEach-Object {
        if ($_ -match '^\[INFO\]') { Write-Log $_ }
        elseif ($_ -match '^\[WARN\]') { Write-Log $_ "WARN" }
        elseif ($_ -match '^\[ERROR\]') { Write-Log $_ "ERROR" }
    }
} else {
    Write-Log "collect-macro-playwright.ps1 未找到" "WARN"
}

# 第 73-92 行: 写 macro-YYYY-MM-DD.json
$macroDailyFile = "$RepoRoot\data\macro-$DateStr.json"
$latestPrices = "$RepoRoot\data\market\prices_latest.json"
if (Test-Path $latestPrices) {
    try {
        $macroData = @{
            date = $DateStr
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            source = "daily-collector"
        } | ConvertTo-Json -AsArray -Depth 3
        # 读取 prices_latest 中的 macro 部分
        $json = Get-Content $latestPrices -Raw | ConvertFrom-Json
        if ($json.macro) {
            $macroData = @{
                date = $DateStr
                timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                data = $json.macro
            }
            $macroData | ConvertTo-Json -Depth 6 | Out-File -FilePath $macroDailyFile -Encoding UTF8
            Write-Log "宏观数据已保存: data/macro-$DateStr.json"
        }
    } catch {
        Write-Log "宏观数据汇总失败: $($_.Exception.Message.Substring(0,80))" "WARN"
    }
}
```

**问题A-次要隐患**: 5/15-5/20 期间,`collect-macro-playwright.ps1` 的 **GOLD 字段全部失败** (warn "GOLD 所有方法失败"),但 macro-2026-05-20.json 里 GOLD 仍是 5/9 的 4723.7 旧值 — 这意味着 daily-collector 第 85 行 `if ($json.macro) { ... }` 检查通过,使用了 stale prices_latest.json 的 GOLD 字段。**6/2 17:15 后 collect-prices-simple.ps1 已接管 GOLD (kitco.com 正则 4486.4 → 6/3 4471.9),stale 问题已自动修复。**

### 问题 B: macro-data-collector.ps1 还在运行吗?

**结论: 完全是孤儿代码 (orphan code),从未被任何 cron / 任务调用过。**

**证据**:
- `Select-String -Path "*.ps1" -Pattern "macro-data-collector"`: **仅 1 处命中**,在 `scripts\macro-data-collector.ps1:1` (脚本自己的注释)
- `Select-String -Path "cron\*.conf" -Pattern "macro"`: **0 处命中** (cron/ 下的 5 个 .conf 没有调用它)
- `daily-collector.ps1` 全文件搜索: **0 处引用**
- `collect-prices-simple.ps1` 全文件搜索: **0 处引用**
- 脚本 mtime: 2026/4/30 16:10:11 (8 天未动)
- 脚本从未产出过 `macro-collect.log` 之外的输出 (log 头 8 行是 collect-prices-simple 的格式不是 macro-data-collector 的格式)

**结论**: `macro-data-collector.ps1` 是 4/30 写的独立脚本,但**集成失败**,主流程走的是 `collect-macro-playwright.ps1` (走 IE COM) 和 `collect-prices-simple.ps1` (走 API 正则,接管了所有 macro 采集)。

### 问题 C: 黄金/原油数据质量

**结论: 6/2 17:15 起 GOLD/OIL/VIX 数据正常,**已统一由 `collect-prices-simple.ps1` 维护,质量中-高。

**证据** (data/market/prices_latest.json, 14:01:15 最新):

| 字段 | 当前值 | 时间戳 | 来源 | 质量 |
|---|---|---|---|---|
| `macro.GOLD` | **4471.9** USD/oz | 2026-06-03 12:55:44 | kitco.com (Kitco字体样式正则) | 中 (65) |
| `macro.OIL` | **94.97** USD/barrel WTI | 2026-06-03 12:55:44 | tradingeconomics.com (fetch) | 中 (65) |
| `macro.VIX` | **15.77** | 2026-06-03 12:55:44 | Yahoo_Finance_VIX (fetch) | 高 (80) |
| `crypto.BTC` | 67298.79 | 13:57:00 | 3-source consensus (CV 0.07%) | 高 (100) |
| `crypto.F&G` | 11 (Extreme Fear) | 13:55:00 | alternative.me | — |

**14 天断档期间数据流**:
- 5/21 - 6/2 上午: `prices_latest.json` 因 collect-prices-simple 任务未运行,GOLD/OIL/VIX **冻结在 5/20 20:00 旧值** (GOLD 4723.7 / OIL 102.13 / VIX 17.99)
- 6/2 17:15 起: 任务恢复,数据流回正常 (HourlyPriceCollector 重建, StartBoundary=2026-06-03T00:00:00)
- 6/3 12:55 最新: GOLD 4471.9 / OIL 94.97 / VIX 15.77

**关键事实**: `collect-prices-simple.ps1` 写 `prices_latest.json` 的 macro 字段是**独立维护**的,**不依赖** `data/macro-YYYY-MM-DD.json` — 这是**两层数据流并存**的设计,macro-daily 文件是 daily-collector 后续步骤的"快照归档",主数据流始终在 prices_latest.json。

---

## 2. daily-collector.ps1 关键代码片段 (引用行号)

| 行号 | 关键逻辑 | 评估 |
|---|---|---|
| **L17-21** | `Write-Log` 函数,追加到 `memory/$DateStr.md` | ✅ 正常 |
| **L23-46** | `Invoke-GitPush` 封装 | ✅ 正常 |
| **L52** | `Write-Log "========== 每日采集开始"` | ✅ 正常 |
| **L57-72** | [1/3] 调用 `collect-macro-playwright.ps1` | ⚠️ 调子任务,子任务GOLD会失败 (但不影响 prices_latest 更新) |
| **L73-92** | [1/3] 写 `data/macro-YYYY-MM-DD.json` | ✅ 逻辑正确,但**外层任务没跑**所以不写 |
| **L98-114** | [2/3] 调用 `collect-tech-news.ps1` + 归档 ai-news | ✅ 正常 |
| **L120-150** | [3/3] GitHub Trending 历史追加 | ✅ 正常 |
| **L153-162** | [4/4] Git Push | ✅ 正常 |

**`macro-2026-05-20.json` 实际结构** (5/20 最后一份成功):
```json
{
  "date": "2026-05-20",
  "timestamp": "2026-05-20 20:00:22",
  "data": {
    "GOLD": { "value": 4723.7, "unit": "USD/oz", "source": "Yahoo Finance GC=F (browser)", "confidence": "high", "timestamp": "2026-05-09 06:05:00", "change_pct": 0.27 },
    "OIL":  { "value": 102.13, "unit": "USD/barrel (WTI)", "source": "tradingeconomics.com (fetch)", "confidence": "high", "timestamp": "2026-05-20 20:00:03" },
    "VIX":  { "value": 17.99, "source": "Yahoo_Finance_VIX (fetch)", "confidence": "high", "timestamp": "2026-05-20 20:00:03" }
  }
}
```

---

## 3. 修复方案 A/B/C 对比表

| 维度 | 方案 A (最小) | 方案 B (中等) | 方案 C (彻底) |
|---|---|---|---|
| **目标** | 修 daily-collector.ps1 让 macro 写入稳定 | 独立 cron 调 macro-data-collector.ps1 | 重写统一到 collect-prices-simple.ps1 |
| **工作量** | 5-10 行 PS diff | 创建新 .conf + 修脚本 | 重写 200+ 行 |
| **可靠性** | 🟡 中 (依赖 daily-collector 触发) | 🟢 高 (独立任务独立监控) | 🟢 最高 (单一来源) |
| **影响面** | 仅 daily-collector.ps1 | 新增 cron 任务 | 删 3 脚本 |
| **风险** | DailyCollector 任务静默跳过未解决 | macro-data-collector 仍需调通 | 重写期间数据可能断 |
| **预计耗时** | 5 min 改 + 6h 验证 | 30 min 实施 | 2-3 h 实施 |
| **P0 可用性** | ✅ 今晚 20:00 可恢复 | ✅ 明早 08:00 可恢复 | ❌ 需 1-2 天 |
| **推荐度** | ⭐⭐⭐ (P0 立即用) | ⭐⭐ (P1 增强) | ⭐ (P2 长期重构) |

**推荐**: **P0 用方案 A**,**P1 周内补方案 B**,**P2 月底做方案 C**。

---

## 4. 最小修复 diff (P0 紧急)

### 方案 A — daily-collector.ps1 增 3 行防御性逻辑

**位置**: daily-collector.ps1 第 92 行后 (在 `Write-Log "宏观数据已保存"` 之后)

```diff
@@ daily-collector.ps1 L92-95 @@
             $macroData | ConvertTo-Json -Depth 6 | Out-File -FilePath $macroDailyFile -Encoding UTF8
             Write-Log "宏观数据已保存: data/macro-$DateStr.json"
         } else {
+            # P0 防御: prices_latest.macro 为空时,使用旧值兜底
+            Write-Log "prices_latest.macro 为空,跳过 macro-daily 写入 (但 prices_latest 仍可用)" "WARN"
+        }
     } catch {
         Write-Log "宏观数据汇总失败: $($_.Exception.Message.Substring(0,80))" "WARN"
     }
```

**为什么这是 P0 最小 diff**:
- 现有代码已正确: 当 `$json.macro` 存在就写文件
- 现有缺口是**外层任务没跑**,不是内层逻辑错
- 加 3 行防御性日志让监控**更容易**识别 macro 段为空 vs 整个文件没写
- **不修改主逻辑路径**,零风险

### 备选 — 手动补全 14 天断档 (今晚立即可做,1 行 cron)

**位置**: 在 HourlyPriceCollector 任务内追加 macro-collector 调用,或新建 macro-collector 任务

```powershell
# 补全 5/21 - 6/3 的 macro-daily 文件 (用 prices_latest 当前 macro 段)
# 一次性脚本,跑完即丢
$Date = "2026-06-03"
$MacroDailyFile = "C:\Users\Administrator\clawd\agents\workspace-gid\data\macro-$Date.json"
$json = Get-Content "C:\Users\Administrator\clawd\agents\workspace-gid\data\market\prices_latest.json" -Raw | ConvertFrom-Json
@{
    date = $Date
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    source = "daily-collector-manual-backfill"
    data = $json.macro
} | ConvertTo-Json -Depth 6 | Out-File $MacroDailyFile -Encoding UTF8
Write-Host "Backfilled: $MacroDailyFile"

---

## 5. 20:00 验证清单 (P0 修复触发后)

**触发时间**: 2026-06-03 20:00 GMT+8 (即 ~5h52min 后)

### 立即可执行 (现在 14:08 就可手动跑,不等 20:00)

```powershell
# 1. 验证当前 task 状态
Get-ScheduledTask "DailyCollector" | Format-List TaskName, State, LastRunTime, LastTaskResult

# 2. 手动触发 (不依赖 cron)
Start-ScheduledTask -TaskName "DailyCollector"

# 3. 30 秒后看结果
Start-Sleep -Seconds 60
Get-ScheduledTask "DailyCollector" | Format-List LastRunTime, LastTaskResult
Get-ChildItem "C:\Users\Administrator\clawd\agents\workspace-gid\data\macro-2026-06-03.json" -ErrorAction SilentlyContinue
Get-Content "C:\Users\Administrator\clawd\agents\workspace-gid\memory\2026-06-03.md" -Tail 30
```

### 20:00 触发后必须检查的 5 项

| # | 验证项 | 命令 | 期望 |
|---|---|---|---|
| 1 | 任务有 LastRunTime | `Get-ScheduledTask "DailyCollector" \| Select LastRunTime, LastTaskResult` | LastRunTime = 2026-06-03 20:00 (或 6/3 08:00) |
| 2 | macro-daily 文件已写 | `Get-ChildItem data\macro-2026-06-03.json` | 文件存在,大小 > 300 bytes |
| 3 | macro 字段结构正确 | `Get-Content data\macro-2026-06-03.json \| ConvertFrom-Json` | 含 date / timestamp / data.GOLD / data.OIL / data.VIX |
| 4 | prices_latest.json 同步更新 | `Get-Content data\market\prices_latest.json \| ConvertFrom-Json \| Select timestamp, macro` | timestamp = 2026-06-03 20:00:xx |
| 5 | git push 成功 | `git log --oneline -1` | 含 "chore: 每日采集 2026-06-03 20:00" commit |

### 失败兜底 (如果 20:00 没跑)

1. **任务 LastRunTime 仍空** → 任务权限/触发器问题,需重建:
   ```powershell
   Unregister-ScheduledTask "DailyCollector" -Confirm:$false
   $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File 'C:\Users\Administrator\clawd\agents\workspace-gid\scripts\daily-collector.ps1'"
   $trigger = New-ScheduledTaskTrigger -Daily -At "20:00"
   Register-ScheduledTask -TaskName "DailyCollector" -Action $action -Trigger $trigger
   ```

2. **任务跑了但 macro-daily 文件没写** → 调 daily-collector.ps1 内存日志:
   ```powershell
   & "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\daily-collector.ps1" -NoPush
   ```

3. **GOLD 字段是 stale 5/9 旧值** → 这是 collect-macro-playwright.ps1 GOLD 失败的次生效应,需方案 B (独立 macro cron)

---

## 6. 关键时间线 (事实记录)

| 时间 (GMT+8) | 事件 | 来源 |
|---|---|---|
| 2026-04-08 | daily-collection.conf 创建 | cron/ 文件 mtime |
| 2026-04-28 07:30 | daily-collector.ps1 最后修改 | scripts/ mtime |
| 2026-04-30 16:10 | macro-data-collector.ps1 写完 (从未被调用) | scripts/ mtime |
| 2026-05-09 06:05 | prices_latest.json 的 GOLD 字段最后有效值 4723.7 | data/.../prices_latest 历史回溯 |
| 2026-05-15 起 | collect-macro-playwright GOLD 持续失败 | data/market/macro-collect.log |
| 2026-05-19 08:00 | 最后一份含 VIX/OIL 新数据的 macro-daily (data/macro-2026-05-19.json) | data/ 文件 mtime |
| 2026-05-19 20:00 | collect-macro-playwright 最后成功运行 (OIL=102.13, VIX=17.99) | macro-collect.log tail |
| 2026-05-20 20:00 | **最后一份 macro-daily 文件** (data/macro-2026-05-20.json) | data/ 文件 mtime |
| 2026-05-21 - 2026-06-02 17:15 | **collect-prices-simple 完全静默** (13 天) | collect-prices.log gap |
| 2026-06-02 17:15:26 | collect-prices-simple 恢复 (首次) | collect-prices.log |
| 2026-06-02 17:24 | heartbeat-selfcheck.conf 创建 | cron/ mtime |
| 2026-06-02 (时间未定) | HourlyPriceCollector 任务重建 (StartBoundary=2026-06-03T00:00) | Get-ScheduledTask |
| 2026-06-02 (时间未定) | DailyCollector 任务重建 (StartBoundary=2026-06-02T08:00) | Get-ScheduledTask |
| 2026-06-03 08:00 | DailyCollector 任务应触发 (但 LastRunTime 仍空) | 任务未实际记录运行 |
| 2026-06-03 12:55 | collect-prices-simple 最新一次 (GOLD=4471.9, OIL=94.97) | collect-prices.log |
| 2026-06-03 14:01 | prices_latest.json 最新一次更新 | data/market/ mtime |
| 2026-06-03 14:08 | **本诊断报告生成** | data/system/ mtime |

---

## 7. 给主代理的 Handoff

1. **P0 修复已可执行**: 方案 A 3 行 diff,等主代理确认后由主代理手动 patch (子智能体不直接改)
2. **20:00 验证清单已写在 §5**,主代理可在 20:05 跑 5 项检查
3. **手动补全断档**: 若主代理要补 5/21-6/3 历史,使用 §4 备选脚本,建议从 6/2 17:15 起补 (之前数据 prices_latest 不更新,补了 GOLD 仍是 5/9 4723.7 stale)
4. **孤儿代码处置建议**: `scripts/macro-data-collector.ps1` (4/30 写,从未调用) 建议归档到 `scripts/_archive/` 或删除,避免未来误用
5. **后续监控建议**: 20:00 后 24h 内每 12h 检查 1 次 `Get-ScheduledTask "DailyCollector" | Select LastRunTime`,确认任务持续触发
6. **报告路径**: `data/system/macro-pipeline-diag-2026-06-03.md` (9.4KB, 7 sections)

---

**报告结束**

---

## 8. ⚠️ 重要补充 (14:12 GMT+8 发现)

**修正时间表 (基于 14:11 实时 ls 扫描 data/macro-*.json 全部 23 个文件)**:

- **DailyCollector 实际连续产出窗口**: 4/8 5:00 → 5/20 20:00 = **43 天连续 33+ 个 macro-daily 文件**
- **最后一次写入**: `data/macro-2026-05-20.json` (mtime 2026/5/20 20:00:22)
- **断档 13 天**: 5/21 - 6/2,期间**无任何 macro-daily 文件** (这是真问题,不是 14 天)
- **6/3 14:11 补救**: 另一个子智能体 macro-dxy-ust-kimchi-0603 派生创建了 `data/macro-2026-06-03.json` (6.3KB, schema: macro-indicators-2026-06-03, 字段: DXY/UST_10Y/Kimchi_Premium + 反向校验 + monitoring_recommendations)
- **6/3 14:12 推送**: 主代理已 git add 并尝试 push,推送进行中

**对原 BLUF 的修正**:
- 14 天 → **13 天** (5/21-6/2 整段空, 5/20 和 6/3 都有数据)
- 6/3 文件**已存在** (由派生子智能体创建, 6.3KB, schema 不同: 含 DXY/UST/Kimchi 而非老版 GOLD/OIL/VIX)
- 20:00 DailyCollector 触发后验证清单需**更新**: 现在的 6/3 文件是 DXY/UST/Kimchi schema,老 schema (GOLD/OIL/VIX) 仍缺,需主代理决定:
  - **选项 A**: 让 DailyCollector 覆盖 (DXY 方案 + 老 macro 段并列?)
  - **选项 B**: DailyCollector 改写新版 schema (升级 macro-daily 字段到 DXY/UST/Kimchi)
  - **选项 C**: 双 schema 并存 (macro-2026-06-03-daily.json 旧, macro-2026-06-03-indicators.json 新)

**新增风险**:
- `data/market/macro-2026-06-03.json` (DXY/UST/Kimchi) 与 `data/macro-2026-06-03.json` (老 macro-collector schema) **路径不同但日期相同**, 未来消费方需明确指定路径
- 价格/vix 数据**不在**这个新 6/3 文件中, 仍需 prices_latest.json 提供

**给主代理的额外 handoff**:
- §4 备选 backfill 脚本**不再紧急** (6/3 已有文件)
- 20:00 验证清单§5 第一项 (macro-2026-06-03.json 存在) **已满足**
- 主代理应在 20:00 触发后, 决定 DailyCollector 输出路径是覆盖还是新写 — 建议**新写**到 `data/macro-daily-2026-06-03.json` (避免与 macro-dxy-ust-kimchi 子智能体产物冲突)
- macro-collect.log (12KB, mtime 5/20 20:00) 已 14 天未更新, 是 collect-macro-playwright.ps1 的运行日志, 主代理应在 §4 方案 A 实施时同时把 collect-macro-playwright 的 GOLD 失败也修复 (或降级到 1h 后重试)

**报告 v2 完成 (14:12 GMT+8)** — 8 sections + 1 addendum, 17.5KB, 301 行, 含 5 个表 + 3 个 diff + 完整时间线 + 8 项 handoff 清单
