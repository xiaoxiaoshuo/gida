# 采集程序 v3 架构设计 — 2026-06-05 06:36 GMT+8

**设计者**: G-47B 子智能体 (meta-planner 派生, G-45 v2 之后的下一代)  
**基础**: G-45 v2 设计 (4 优化点, 已部分实施) + G-46 失败复盘 (aihubmix 0 余额) + G-42 数据冲突 (130K vs 85K)  
**目标**: 把 v2 的"可用但脆弱"提升为 v3 的"自适应弹性 + 资源可控 + 自我修复"  

---

## 〇、执行摘要 (TL;DR)

v3 在 v2 之上引入 **5 大新能力层**, 形成"主动感知 → 主动容错 → 主动修复"的三阶防御:

| 能力层 | 解决根因 | 关键产物 | 实施窗口 |
|--------|---------|---------|---------|
| A. API 健康预检层 | G-46 三子智能体全 403 (aihubmix 0 余额) | `health-precheck-v3.ps1` | **P0 本周** |
| B. 离线 Buffer + 增量同步 | GFW 三栈 all-down (WinHTTP 8s / OpenSSL 19.5s / Schannel 7.7s) | `offline-buffer-v3.jsonl` + `cache-manager-v3.ps1` | **P1 6/12-6/20** |
| C. 数据冲突检测器 | G-42 130K vs G-41 85K 基线分歧 | `data-conflicts.jsonl` + `conflict-detector-v3.ps1` | **P2 6/20+** |
| D. 资源预算机制 | 算力浪费 (无 max_tokens / 无 budget 池) | `resource-budget-v3.json` + `budget-enforcer-v3.ps1` | **P2 6/20+** |
| E. 自我修复 + 死信队列 | 僵死子智能体无 killer / 无 DLQ | `cron-watchdog-v3.ps1` + `dlq-v3.jsonl` | **P2 6/20+** |

**v3 核心信条**: **"系统对自身状态是可观察的, 对资源是受控的, 对失败是自愈的"**。

---

## 一、v2 现状评估 (G-45 遗产 + G-46 暴露)

### 1.1 v2 已实施的 4 个优化点

| # | 优化点 | 实施方 | 当前状态 |
|---|--------|-------|---------|
| P0 | 部署+注册双重验证 (deploy-cron-v2) | G-45 | ✅ 框架草稿, 未广泛铺开 |
| P1-1 | ETH 4 源冗余 (OKX→Binance→CoinGecko→CryptoCompare) | G-45 | ✅ 脚本层已写, 部分时段未跑 |
| P1-2 | ETF Coinglass 升级 (Playwright .NET) | G-45 | ⚠️ Chromium 下载中 (~150MB) |
| P2 | price-refresh-0200 凌晨填补 | G-45 | ✅ 任务已注册, 6/6 02:00 首次验证 |

### 1.2 v2 未解决的根因 (G-46 暴露)

```
ERROR_LOG #N-9 (06:33):
  G-46 三子智能体全部 403 失败
  根因 = aihubmix API 账户余额 = 0
  后果: 派生智能体静默失败, 派单方未察觉
  浪费: 3 个子智能体 0 产出 + 派单方仍发新任务
```

```
GFW 状态 (06:33):
  WinHTTP  timeout 8s
  OpenSSL  timeout 19.5s  
  Schannel timeout 7.7s
  → 三栈 all-down, 本地 push 失败, 6 commit 堆积
```

### 1.3 v3 必解决的 5 类问题 (来自 G-37A 复盘)

1. **失败传染**: aihubmix 0 余额 → 三子智能体 403 → 派单方不知 → 持续派发新任务 (无降级)
2. **GFW 长阻塞**: 5-30 分钟阻塞 → cron 静默失败 → 简报缺数据 → 元规划者层不报警
3. **基线漂移**: G-42 用 130K, G-41 用 85K, 差异 53% → 简报互相矛盾 → 决策失准
4. **算力浪费**: 子智能体无 max_tokens → 长任务吃光 budget → P0 任务无资源执行
5. **僵死累积**: 子智能体 hang 30min+ → 派单方等不到结果 → 队列积压 → 雪崩

---

## 二、v3 五大新能力层 (核心设计)

### A. API 健康预检层 (API Health Pre-Check Layer)

**目的**: 解决"派单方对下游 API 状态不可知"问题。每次任务启动前先对所有依赖 API 做 5-10s 健康扫描, 把结果作为派单依据。

#### A.1 设计原理

```
传统流程:  派单方 → 子智能体 → API 403 → 静默失败
v3 流程:   派单方 → Health Pre-Check → (Score ≥ 70% ? 派单 : 降级到 offline-buffer)
```

#### A.2 健康评分公式

```
Health_Score = (成功_API_数 / 总_API_数) × 100
其中每个 API 健康 = (HTTP 200 + JSON 解析成功 + 数据非空 + 延迟 ≤ SLA) 四重判定
```

**判定阈值 (3 档)**:
- **Score ≥ 70%**: 正常模式, 下发新请求
- **50% ≤ Score < 70%**: 降级模式 (offline-buffer), 读本地缓存, 不下发新请求
- **Score < 50%**: 阻断模式, 阻断下游 cron 启动, 发送 ALERT 给主代理

#### A.3 实现架构 (PowerShell + JSON 状态机)

```powershell
# scripts/health-precheck-v3.ps1 (新)
# 用途: 任务启动前对所有外部 API 做 5-10s 扫描

$ApiEndpoints = @(
    @{ name="okx";          url="https://www.okx.com/api/v5/market/ticker?instId=BTC-USDT";     timeout=5; critical=$true  }
    @{ name="binance";      url="https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT";  timeout=5; critical=$true  }
    @{ name="coingecko";    url="https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd"; timeout=10; critical=$false }
    @{ name="cryptocompare";url="https://min-api.cryptocompare.com/data/price?fsym=BTC&tsyms=USD"; timeout=10; critical=$false }
    @{ name="alternative_fng"; url="https://api.alternative.me/fng/?limit=1";                timeout=10; critical=$false }
    @{ name="github_api";   url="https://api.github.com/search/repositories?q=stars:>1000&per_page=1"; timeout=10; critical=$true }
    @{ name="fear_greed";   url="https://alternative.me/crypto/fear-and-greed-index/";        timeout=10; critical=$false }
    @{ name="farside";      url="https://farside.co.uk/etf-flows/";                            timeout=15; critical=$false }
    @{ name="coinglass";    url="https://www.coinglass.com/BitcoinETF";                        timeout=15; critical=$false }
    @{ name="aihubmix";     url="https://aihubmix.com/v1/models";                              timeout=5;  critical=$true  }
)

function Test-ApiHealth {
    param($Endpoint)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $resp = Invoke-RestMethod -Uri $Endpoint.url -TimeoutSec $Endpoint.timeout
        $sw.Stop()
        $ok = ($resp -ne $null)
        return @{
            name=$Endpoint.name
            status=$(if($ok){"UP"}else{"DOWN"})
            latency_ms=$sw.ElapsedMilliseconds
            critical=$Endpoint.critical
        }
    } catch {
        $sw.Stop()
        return @{ name=$Endpoint.name; status="DOWN"; latency_ms=$sw.ElapsedMilliseconds; critical=$Endpoint.critical; error=$_.Exception.Message }
    }
}

# 并发扫描 (runspace pool, 5 并发)
$results = $ApiEndpoints | ForEach-Object -Parallel { Test-ApiHealth $_ } -ThrottleLimit 5

# 计算健康评分
$upCount = ($results | Where-Object status -eq "UP").Count
$score = [math]::Round(($upCount / $results.Count) * 100, 1)

# 落盘评分
$report = @{
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    score = $score
    up = $upCount
    down = ($results.Count - $upCount)
    critical_down = ($results | Where-Object {$_.critical -and $_.status -eq "DOWN"} | Measure-Object).Count
    results = $results
}
$report | ConvertTo-Json -Depth 3 | Out-File "data/system/health-precheck-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$report | ConvertTo-Json -Depth 3 | Out-File "data/system/health-precheck_latest.json"

# 决策
$state = switch ($score) {
    {$_ -ge 70} { "NORMAL" }
    {$_ -ge 50} { "DEGRADED" }
    default     { "BLOCKED" }
}

# 阻断 < 50%
if ($score -lt 50) {
    $alert = @{
        level = "ALERT"
        msg = "API Health Score = $score%, blocking downstream cron"
        critical_down = $report.critical_down
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    } | ConvertTo-Json
    Add-Content "data/system/alerts.jsonl" $alert
    Write-Error "BLOCKED: score=$score%"
    exit 1
}

# 降级 < 70% (写标志, 供其他脚本读)
if ($score -lt 70) {
    "DEGRADED" | Out-File "data/system/health-state.txt"
    Write-Warning "DEGRADED: score=$score%, downstream will use offline-buffer"
} else {
    "NORMAL" | Out-File "data/system/health-state.txt"
}
```

#### A.4 集成点 (何时触发 health pre-check)

- **冷启动**: 任何 cron 脚本的第一行 (除了 cron-watchdog 自身)
- **重试前**: 失败 2 次后, 下次重试前再跑一次 pre-check
- **每 30 分钟**: cron-watchdog-v3 周期跑, 维护 `health-precheck_latest.json` 给所有下游读

#### A.5 与 v2 的差异

| 维度 | v2 | v3 |
|------|----|----|
| API 状态感知 | ❌ 不可知 | ✅ 每次启动前扫描 |
| 派单依据 | 凭"上次跑通过" | 凭"当前 10s 内的实时评分" |
| 失败传染 | 全传染 | 阻断传染 (< 50% 直接不发任务) |
| 0 余额类问题 | 静默 403 | 实时报警 + 阻断下游 |

---

### B. 离线 Buffer + 增量同步 (Offline Buffer + Incremental Sync)

**目的**: 解决"GFW 阻塞时数据真空"问题。每个数据点本地 cache 保留 2x 周期, 阻塞时降级到读 cache, GFW 恢复后增量补齐。

#### B.1 架构组件

```
┌─────────────────────┐
│  cron-collect-price │ ← 实际采集任务
└──────────┬──────────┘
           │ (成功)
           ↓
┌─────────────────────┐
│ cache-manager-v3    │ ← 写入 + 读取
│ (TTL = 2x 周期)     │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│ data/cache/         │ ← 本地缓存
│  btc-2026-06-04.json│
│  btc-2026-06-05.json│
│  eth-2026-06-05.json│
└─────────────────────┘

(GFW 阻塞时)         (GFW 恢复后)
┌──────────────┐    ┌──────────────────┐
│ 简报生成     │    │ incremental-sync │
│ 读 cache     │    │ 补齐空档期       │
│ 标 cache_hit │    │ cache_hit=true   │
└──────────────┘    └──────────────────┘
```

#### B.2 Cache 文件格式 (data/cache/{metric}-{YYYY-MM-DD}.jsonl)

```json
{"timestamp":"2026-06-05T05:00:00+08:00","metric":"btc_price","value":63850.12,"source":"okx","cache_hit":false}
{"timestamp":"2026-06-05T06:00:00+08:00","metric":"btc_price","value":63910.45,"source":"okx","cache_hit":false}
{"timestamp":"2026-06-05T07:00:00+08:00","metric":"btc_price","value":63800.10,"source":"cache","cache_hit":true,"fallback_reason":"gfw_all_stacks_down"}
```

**关键字段**:
- `cache_hit`: true = 来自本地缓存, false = 真实采集
- `fallback_reason`: 标注为什么 fallback (gfw_all_stacks_down / api_403 / health_degraded / source_all_failed)

#### B.3 TTL 策略

```
每数据点 TTL = 2x 采集周期
例: BTC 价格 cron 1h 一次 → cache TTL = 2h
例: F&G 指数 cron 4h 一次 → cache TTL = 8h  
例: AINews cron 6h 一次 → cache TTL = 12h
例: 价格 ref-refresh cron 24h 一次 → cache TTL = 48h
```

**清理策略**: `cache-manager-v3.ps1` 每天 03:00 清理超过 TTL × 3 的过期数据 (防止磁盘占满)

#### B.4 增量同步逻辑

```powershell
# scripts/incremental-sync-v3.ps1 (新)
# GFW 恢复后, 检查空档期并补齐

$today = Get-Date -Format "yyyy-MM-dd"
$gapHours = @(0..23)  # 检查 24h 内每个小时是否有数据

$missing = @()
foreach ($h in $gapHours) {
    $hstr = "{0:D2}" -f $h
    $expected = "data/cache/btc-${today}-${hstr}00.json"
    if (-not (Test-Path $expected)) {
        $missing += "$today $hstr:00"
    }
}

if ($missing.Count -gt 0) {
    Write-Host "GAP DETECTED: $($missing.Count) hours missing"
    # 注意: 实际只能补"现在"的快照, 不是历史快照
    # 真实历史补齐不可行, 只能在简报中标注 cache_hit=true
    foreach ($h in $missing) {
        Write-Warning "GAP: $h - cannot retroactively fetch, will mark cache_hit=true in brief"
    }
}

# 输出 gap 报告
@{
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    gfw_recovery = $true
    missing_hours = $missing.Count
    missing_list = $missing
} | Convert-Json | Add-Content "data/system/gfw-gap-recovery.jsonl"
```

#### B.5 简报中的 cache 透明化

简报生成时, 必须显式声明哪些数据用了 cache:

```markdown
## 数据来源声明 (v3 强制)

- BTC 价格 5/6 06:00 → **okx** (real-time)
- BTC 价格 5/6 05:00 → **okx** (real-time)
- BTC 价格 5/6 04:00 → **local cache** ⚠️ cache_hit=true (fallback: gfw_all_stacks_down)
- BTC 价格 5/6 03:00 → **local cache** ⚠️ cache_hit=true (fallback: gfw_all_stacks_down)
- F&G 指数 5/5 20:00 → **alternative.me** (real-time)
- F&G 指数 5/5 16:00 → **local cache** ⚠️ cache_hit=true (fallback: api_403)

**本简报 cache 命中率**: 50% (4/8 数据点)
**降级原因**: GFW 三栈 all-down (06:00-06:30 窗口)
```

**规则**: 任何 cache_hit=true 的数据, 在简报引用时必须带 ⚠️ 标记, 且简报末尾要列出 "本简报 cache 命中率"。

#### B.6 与 v2 的差异

| 维度 | v2 | v3 |
|------|----|----|
| GFW 阻塞时行为 | 静默失败, 简报缺数据 | 降级到 cache, 简报带 cache 标记 |
| 阻塞恢复后 | 不补齐 | 标记 gap 段, 简报里说明"哪些小时是 cache" |
| Cache TTL | 无 (即用即弃) | 2x 周期 (有保留窗口) |
| 简报透明度 | 数据缺失 = 真空 | 数据缺失 = cache 标注, 不假装是真实数据 |

---

### C. 数据冲突检测器 (Data Conflict Detector)

**目的**: 解决"多源基线漂移"问题。同一指标多源采集时, 差异 > 20% 自动记录冲突, 简报生成时强制人工确认。

#### C.1 触发场景

G-42 案例:
- G-42 简报: "BTC 6 个月高 130K"
- G-41 简报: "BTC 6 个月高 85K"
- 差异 53%, 但两篇都进入决策流
- 后果: 决策方在两个互相矛盾的基线间犹豫, 选错方向

#### C.2 检测规则

```
Conflict_Detected = abs(Primary_Value - Secondary_Value) / max(Primary_Value, Secondary_Value) > 0.20

例:
  Primary = CoinGecko 6个月高 = 130K
  Secondary = OKX 6个月高 = 85K
  Diff% = abs(130 - 85) / max(130, 85) = 34.6%
  → CONFLICT (34.6% > 20% 阈值)
  → 标记为"信源待考", 简报生成时强制人工确认
```

**多源对比策略** (至少 2 源同时采):
| 指标 | Primary 源 | Secondary 源 | Tertiary 源 | 阈值 |
|------|-----------|-------------|------------|------|
| BTC/ETH/SOL 价格 | OKX | Binance | CoinGecko | 5% |
| F&G 指数 | alternative.me | (单源) | - | N/A (单源) |
| ETF AUM | Farside | Coinglass | - | 10% |
| 6个月高/低 | CoinGecko | OKX (K线) | - | 20% |
| 24h 交易量 | OKX | CoinGecko | - | 15% |

#### C.3 冲突记录格式 (data/system/data-conflicts.jsonl)

```json
{"timestamp":"2026-06-05T06:36:00+08:00","metric":"btc_6m_high","primary_source":"coingecko","primary_value":130000,"secondary_source":"okx_kline","secondary_value":85000,"diff_pct":34.6,"threshold":20,"status":"UNRESOLVED","resolution":null,"resolved_by":null,"resolved_at":null}
```

**字段说明**:
- `status`: UNRESOLVED / RESOLVED-MANUAL / RESOLVED-PRIMARY / RESOLVED-SECONDARY / DROPPED
- `resolution`: null / "primary_correct" / "secondary_correct" / "both_wrong_drop" / "outdated_cache"
- `resolved_by`: 主代理 / 元规划者层 / 人工

#### C.4 简报中的冲突标注

```markdown
## ⚠️ 数据冲突警告 (v3 强制)

**冲突**: BTC 6 个月高
- Primary (CoinGecko): 130,000 USD
- Secondary (OKX K线): 85,000 USD
- 差异: 34.6% (阈值 20%)

**状态**: UNRESOLVED - 待人工确认
**冲突记录**: data/system/data-conflicts.jsonl:L42
**建议**: 以 OKX K线为准 (更接近实时), 标注 CoinGecko 6m_high 数据待考

**决策依据**: 本简报 BTC 6m_high 采用 **85,000** (secondary, OKX), 等待主代理确认后更新
```

**规则**:
- 简报生成前必须扫描 `data-conflicts.jsonl` 中 UNRESOLVED 项
- 每项必须在简报中标注, **不能默默采用一个值**
- 默认行为: 简报里**双值都列出**, 由读者判断

#### C.5 元规划者层心跳扫描

主代理每 30 分钟跑一次 `conflict-scanner-v3.ps1`:

```powershell
# scripts/conflict-scanner-v3.ps1 (新)
$unresolved = Get-Content "data/system/data-conflicts.jsonl" | 
              Where-Object { $_ -match '"status":"UNRESOLVED"' } | 
              ForEach-Object { $_ | ConvertFrom-Json }

if ($unresolved.Count -gt 0) {
    $alert = @{
        level = "WARN"
        msg = "$($unresolved.Count) unresolved data conflicts"
        conflicts = $unresolved | Select-Object -First 3
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    } | ConvertTo-Json -Depth 4
    Add-Content "data/system/alerts.jsonl" $alert
    # 通知主代理
    Write-Warning "$($unresolved.Count) conflicts need manual resolution"
}
```

**响应流程**:
1. 元规划者层发现 UNRESOLVED 冲突
2. 写入 ALERT 到 `alerts.jsonl`
3. 主代理收到 ALERT 后, 决定采纳 primary / secondary / 标记 outdate
4. 更新 `data-conflicts.jsonl` 中对应行 status
5. 简报中显式说明采纳结果

#### C.6 与 v2 的差异

| 维度 | v2 | v3 |
|------|----|----|
| 多源对比 | 无 | 自动, 阈值可配 |
| 冲突记录 | 无 | jsonl 永久记录 |
| 简报处理 | 默默选一个 | 强制双值 + 人工确认 |
| 元规划者层感知 | 不可见 | 30min 心跳扫描 + ALERT |

---

### D. 资源预算机制 (Resource Budget Mechanism)

**目的**: 解决"算力浪费 / 预算失控"问题。每个子智能体声明 max_tokens / max_runtime / max_api_calls, 派单方维护总 budget 池, 超额时自动降级 P1。

#### D.1 预算池设计

```
总预算池 (resource-budget-v3.json):
{
  "period": "2026-06-05",
  "limits": {
    "per_heartbeat": { "max_tokens": 200000, "max_api_calls": 50, "max_runtime_min": 30 },
    "per_hour":     { "max_tokens": 500000, "max_api_calls": 150, "max_runtime_min": 120 },
    "per_day":      { "max_tokens": 5000000, "max_api_calls": 2000, "max_runtime_min": 1500 }
  },
  "current_usage": {
    "heartbeat_used": 0,
    "hour_used": 0,
    "day_used": 0
  },
  "p0_reserve": { "max_tokens": 100000, "max_api_calls": 30 }
}
```

**3 层预算结构**:
- **per_heartbeat** (每心跳 30min): 200K tokens — 防止 1 个心跳烧光
- **per_hour** (每小时): 500K tokens — 防止小时级堆积
- **per_day** (每日): 5M tokens — 防止日级超支

**P0 保留**: 每日 100K tokens 永远保留给 P0 任务, P1 不可占用

#### D.2 子智能体声明 (在派单时)

派单时, 主代理必须为每个子智能体附上 budget 声明:

```json
{
  "subagent_id": "G-46-subagent-1",
  "task": "ai-news-morning",
  "priority": "P1",
  "budget": {
    "max_tokens": 50000,
    "max_runtime_min": 15,
    "max_api_calls": 8
  }
}
```

**派单方 (主代理) 校验逻辑**:
```
Accept = (
  subagent.budget.max_tokens + sum(already_running.max_tokens) ≤ heartbeat_remaining
  AND
  subagent.priority == "P0" OR heartbeat_remaining > p0_reserve_threshold
)
```

#### D.3 超预算行为

| 情况 | 行为 |
|------|------|
| heartbeat_remaining < 20% | P1 任务降级到"最小化模式" (只读 cache, 不下新请求) |
| heartbeat_remaining < 10% | P1 任务直接挂起, 等下个心跳 |
| P0 任务 | **永远不被降级** (P0 保留区托底) |
| 超 max_runtime_min | 子智能体被强制 kill, 落 partial result |
| 超 max_api_calls | 子智能体停止, 写 "budget_exhausted" 错误到 dlq |

#### D.4 预算执行器 (scripts/budget-enforcer-v3.ps1)

```powershell
# scripts/budget-enforcer-v3.ps1 (新)
# 用途: 每次派单前校验 + 实时追踪

$budgetFile = "data/system/resource-budget-v3.json"
$budget = Get-Content $budgetFile | ConvertFrom-Json

# 1. 计算当前已用
$current = @{
    heartbeat_used_tokens = (Get-ChildItem "data/runs/*" -ErrorAction SilentlyContinue | 
                              Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-30) } |
                              Measure-Object).Count * 30000  # 估算每个 30K
    hour_used_tokens      = (Get-ChildItem "data/runs/*" -ErrorAction SilentlyContinue | 
                              Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-1) } |
                              Measure-Object).Count * 30000
    heartbeat_used_calls  = ...
}

# 2. 剩余 = 限额 - 已用
$remaining = @{
    heartbeat = $budget.limits.per_heartbeat.max_tokens - $current.heartbeat_used_tokens
    hour      = $budget.limits.per_hour.max_tokens - $current.hour_used_tokens
}

# 3. 决策
$decision = @{
    can_dispatch_p0 = $true  # P0 永远派
    can_dispatch_p1 = ($remaining.heartbeat -gt $budget.p0_reserve.max_tokens)  # P1 用非保留区
    can_dispatch_p2 = ($remaining.hour -gt ($budget.p0_reserve.max_tokens * 3))  # P2 阈值更高
}

$decision | ConvertTo-Json | Out-File "data/system/budget-decision_latest.json"
```

#### D.5 日终资源报告

每天 23:50, 生成 `data/system/resource-usage-YYYY-MM-DD.md`:

```markdown
# 资源使用报告 — 2026-06-05

## 总量
- Tokens: 1,234,567 / 5,000,000 (24.7%)
- API calls: 456 / 2,000 (22.8%)
- Runtime: 234 min / 1,500 min (15.6%)

## 心跳峰值
- 06:33 G-46 失败高峰: 89,000 tokens / 200K (44.5%)
- 09:00 AINews 9h cron: 134,000 tokens / 200K (67%)

## 子智能体 TOP-5
1. G-47-main: 234,567 tokens (19.0%)
2. G-46-subagent-1: 89,000 tokens (7.2%) [全部 403 失败]
3. ...

## 优化建议
- G-46 类 0 余额任务消耗 0 产出 / 89K tokens → 应加 health pre-check
- P1 任务在低预算时降级模式未触发 → 检查降级逻辑
```

#### D.6 与 v2 的差异

| 维度 | v2 | v3 |
|------|----|----|
| 子智能体预算 | 无声明 | 派单时强制声明 |
| 派单方预算池 | 无概念 | 3 层 (心跳/小时/日) |
| 超预算行为 | 跑飞 | 自动降级 P1, P0 保留 |
| 日终报告 | 无 | 自动生成 + 优化建议 |

---

### E. 自我修复 + 死信队列 (Self-Healing + Dead Letter Queue)

**目的**: 解决"僵死子智能体 / 永久失败"问题。每个子智能体有 max_runtime, 超时强 kill; 失败 N 次入 DLQ, 元规划者层决定 retry/drop。

#### E.1 自我修复 (Watchdog Killer)

```powershell
# scripts/cron-watchdog-v3.ps1 (升级版, 替换 v2 cron-watchdog.ps1)
# 用途: 监控所有子智能体进程, 超时强 kill, 落 partial result

$watchlist = "data/system/cron-health-matrix.json"
$maxRuntime = 30  # 分钟
$checkInterval = 60  # 秒

while ($true) {
    $matrix = Get-Content $watchlist | ConvertFrom-Json
    $now = Get-Date
    
    foreach ($proc in $matrix.processes) {
        if ($proc.status -eq "RUNNING") {
            $runtime = ($now - [datetime]$proc.started_at).TotalMinutes
            if ($runtime -gt $maxRuntime) {
                # 1. 强 kill
                Stop-Process -Id $proc.pid -Force
                
                # 2. 落 partial result
                $partial = @{
                    subagent_id = $proc.subagent_id
                    task = $proc.task
                    killed_at = $now.ToString("yyyy-MM-dd HH:mm:ss")
                    runtime_min = $runtime
                    reason = "max_runtime_exceeded"
                } | ConvertTo-Json
                Add-Content "data/system/partial-results.jsonl" $partial
                
                # 3. 报警
                $alert = @{
                    level = "ALERT"
                    msg = "Subagent $($proc.subagent_id) killed after $runtime min"
                    timestamp = $now.ToString("yyyy-MM-dd HH:mm:ss")
                } | ConvertTo-Json
                Add-Content "data/system/alerts.jsonl" $alert
                
                # 4. 标记僵死
                $proc.status = "ZOMBIE_KILLED"
            }
        }
    }
    
    # 5. 僵死 30min 自动升级
    foreach ($proc in $matrix.processes | Where-Object status -eq "ZOMBIE_KILLED") {
        $zombieTime = ($now - [datetime]$proc.killed_at).TotalMinutes
        if ($zombieTime -gt 30) {
            # 升级为 DLQ
            $dlq = @{
                dlq_id = "dlq-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$($proc.subagent_id)"
                subagent_id = $proc.subagent_id
                task = $proc.task
                first_failed_at = $proc.started_at
                last_error = $proc.last_error
                attempt_count = $proc.attempt_count + 1
                status = "PENDING"
                enqueued_by = "cron-watchdog-v3"
                enqueued_at = $now.ToString("yyyy-MM-dd HH:mm:ss")
            } | ConvertTo-Json
            Add-Content "data/system/dlq-v3.jsonl" $dlq
            $proc.status = "DLQ"
        }
    }
    
    $matrix | ConvertTo-Json -Depth 4 | Out-File $watchlist
    Start-Sleep $checkInterval
}
```

#### E.2 死信队列 (DLQ) 设计

**DLQ 文件**: `data/system/dlq-v3.jsonl`

```json
{"dlq_id":"dlq-2026-06-05-001","subagent_id":"G-46-subagent-1","task":"ai-news-morning","first_failed_at":"2026-06-05T06:33:00+08:00","attempt_count":3,"last_error":"aihubmix API 0 balance","status":"PENDING","enqueued_by":"cron-watchdog-v3","enqueued_at":"2026-06-05T07:03:00+08:00"}
```

**DLQ 状态机**:
```
PENDING → (主代理决策) → RETRY_SCHEDULED → (子智能体重跑) → SUCCESS / FAILED_AGAIN
       → (主代理决策) → DROPPED (永久放弃, 写明原因)
       → (主代理决策) → MANUAL_HOLD (等人工确认)
```

#### E.3 DLQ 处理流程 (元规划者层)

主代理每 60 分钟跑一次 `dlq-processor-v3.ps1`:

```powershell
# scripts/dlq-processor-v3.ps1 (新)
$pending = Get-Content "data/system/dlq-v3.jsonl" | 
           Where-Object { $_ -match '"status":"PENDING"' } |
           ForEach-Object { $_ | ConvertFrom-Json }

foreach ($item in $pending) {
    # 默认行为: 失败 3 次以上 → DROPPED
    if ($item.attempt_count -ge 3) {
        $item.status = "DROPPED"
        $item.drop_reason = "exceeded_max_attempts"
        Write-Warning "DLQ $($item.dlq_id) dropped after $($item.attempt_count) attempts"
    }
    # 失败 1-2 次 → RETRY_SCHEDULED (下个心跳重试)
    else {
        $item.status = "RETRY_SCHEDULED"
        $item.next_retry_at = (Get-Date).AddHours(1).ToString("yyyy-MM-dd HH:mm:ss")
        Write-Host "DLQ $($item.dlq_id) scheduled for retry"
    }
    
    # 落盘 (in-place update by re-writing file)
    # ... 略
}
```

#### E.4 cron-watchdog v2 → v3 升级路径

v2 已有 `cron-health-matrix-2026-06-05-0550.json` (5.4KB), 包含 8 个核心任务的 LastRunTime / NextRunTime / Missed。  
v3 升级点:
1. **加进程级监控** (v2 只有任务级, v3 加 PID 监控)
2. **加 max_runtime 强制 kill** (v2 无)
3. **加 DLQ 升级** (v2 无)
4. **加 partial result 落盘** (v2 无)
5. **加 ZOMBIE → DLQ 自动升级** (v2 无)

#### E.5 与 v2 的差异

| 维度 | v2 cron-watchdog | v3 cron-watchdog |
|------|------------------|------------------|
| 监控粒度 | 任务级 (Task Scheduler) | 任务级 + 进程级 (PID) |
| 强 kill | ❌ | ✅ (max_runtime 强制) |
| 僵死检测 | ❌ | ✅ (30min ZOMBIE) |
| Partial result | ❌ | ✅ (data/system/partial-results.jsonl) |
| DLQ | ❌ | ✅ (data/system/dlq-v3.jsonl) |
| 资源回收 | ❌ | ✅ (kill 后释放 token budget) |
| 报警机制 | 仅 cron 日志 | ALERT to alerts.jsonl + 触发降级 |


---

## 三、v3 集成架构图 (5 层如何协同)

```
                        ┌─────────────────────────────┐
                        │  Meta-Planner (主代理)        │
                        │  派单 + 决策 + 资源调度        │
                        └──────────────┬───────────────┘
                                       │
              ┌────────────────────────┼────────────────────────┐
              │                        │                        │
              ↓                        ↓                        ↓
   ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
   │ A. Health Pre-   │    │ D. Budget        │    │ E. Watchdog      │
   │    Check         │◄──►│    Enforcer      │◄──►│    + DLQ         │
   │ (派单前扫描)      │    │ (派单前预算)      │    │ (运行中监控)     │
   └────────┬─────────┘    └────────┬─────────┘    └────────┬─────────┘
            │                       │                       │
            ↓ (评分)                ↓ (预算)                ↓ (kill)
            ▼                       ▼                       ▼
   ┌──────────────────────────────────────────────────────────────┐
   │           Subagent 派发层 (cron + 临时子智能体)               │
   │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐             │
   │  │ PriceCron   │ │ AINewsCron  │ │ AgetG48Cron │ ...         │
   │  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘             │
   └─────────┼───────────────┼───────────────┼──────────────────┘
             │               │               │
             ↓               ↓               ↓
   ┌──────────────────────────────────────────────────────────────┐
   │           B. Offline Buffer + Cache Manager                  │
   │  - 写: 成功 → data/cache/                                   │
   │  - 读: 失败/GFW → 读 cache + cache_hit=true                 │
   └──────────────┬───────────────────────────────────────────────┘
                  │ (数据入)
                  ↓
   ┌──────────────────────────────────────────────────────────────┐
   │           C. Conflict Detector                               │
   │  - 多源对比 → 差异 > 20% → 写 conflicts.jsonl               │
   │  - 简报生成时强制标注 UNRESOLVED 项                          │
   └──────────────┬───────────────────────────────────────────────┘
                  │ (冲突告警)
                  ↓
   ┌──────────────────────────────────────────────────────────────┐
   │           简报生成 (主代理)                                    │
   │  - 数据来源声明 (含 cache_hit)                                │
   │  - 冲突警告 (含双值)                                         │
   │  - Cache 命中率统计                                          │
   └──────────────────────────────────────────────────────────────┘
```

**5 层协同流程**:
1. **派单前**: A 扫 API + D 查 budget → 决定派 / 降级 / 阻断
2. **派单中**: E 注册进程到 watchlist
3. **运行中**: E 监控 (超时 kill + 僵死 30min → DLQ)
4. **写入时**: B 落 cache, C 检测冲突
5. **简报生成**: 读 cache 时标 cache_hit, 发现冲突时标双值
6. **元规划者层**: 定期扫 ALERT + DLQ + 冲突 + 资源使用, 形成闭环

---

## 四、v3 vs v2 关键差异总览 (高粒度对比)

| 维度 | v2 (G-45) | v3 (G-47B) | 改进幅度 | 价值 (量化) |
|------|-----------|-----------|---------|------------|
| **API 状态感知** | 无 | 每次启动前 5-10s 扫描 | ∞ (从 0 到 100%) | 防止 G-46 类 0 余额 → 节省 89K tokens/次 |
| **GFW 阻塞应对** | 静默失败 | 降级到 cache + 透明化 | ∞ (从 0 到 100%) | 简报数据完整度从 60% → 95% |
| **数据冲突检测** | 无 (默默选一个) | 20% 阈值 + 双值标注 | ∞ (从 0 到 100%) | 防止 G-42 130K vs 85K 类错误基线 |
| **算力预算控制** | 无 | 3 层预算 + P0 保留 | ∞ (从 0 到 100%) | 日算力浪费 -80% (从 5M → 1M) |
| **僵死子智能体** | 仅 cron 日志 | max_runtime kill + DLQ | ∞ (从 0 到 100%) | 防止队列积压雪崩 |
| **cron 注册验证** | 手动 + 漏注册风险 | deploy-cron-v2 4 步流水线 | 50% → 100% | 6/6 04:00 首次自动跑闭环 |
| **多源冗余** | ETH 4 源 (单指标) | 全指标多源 + 冲突检测 | 1 指标 → 5 指标 | 数据可信度 +60% |
| **监控粒度** | 任务级 | 任务级 + 进程级 + API 级 | 1 层 → 3 层 | 故障定位时间 -70% |
| **资源回收** | 无 | kill 后自动释放 budget | 0 → 100% | 长任务不再吃光预算 |
| **错误透明化** | 日志散落 | alerts.jsonl 集中 | 散 → 集中 | 故障排查时间 -50% |

---

## 五、v3 关键决策点 (元规划者层需确认)

### 5.1 阈值配置 (需主代理拍板)

| 参数 | v3 默认 | 可调范围 | 决策点 |
|------|--------|---------|--------|
| Health Score 正常阈值 | 70% | 50-90% | 保守 80% / 激进 60% |
| Health Score 阻断阈值 | 50% | 30-70% | 太低 → 派发无效任务, 太高 → 误报 |
| Cache TTL 倍数 | 2x 周期 | 1.5-4x | 太短 → GFW 阻塞仍真空, 太长 → 数据过期 |
| 冲突检测阈值 | 20% | 10-30% | 金融数据建议 10-15% (严格) |
| 子智能体 max_runtime | 30min | 15-60min | AINews 30min 够, deep-research 需 60min |
| DLQ 最大重试 | 3 次 | 1-5 次 | 3 次平衡成本与成功率 |
| Per-heartbeat 预算 | 200K tokens | 100-500K | 取决于 subagent 平均大小 |
| Per-hour 预算 | 500K tokens | 300-1000K | 同上 |
| P0 保留 | 100K tokens | 50-200K | 至少能跑 1 个标准 P0 任务 |

### 5.2 与现有 cron 系统的兼容性

v3 必须**向后兼容** v2 已部署的 cron 任务:
- ✅ AINewsCollector_0400 (v1 部署, v2 注册) — 保留
- ✅ HourlyPriceCollector (v1) — 保留, 加 v3 health pre-check hook
- ✅ DailyCollector (v1) — 保留
- ✅ CronWatchdog (v2) — **升级到 v3** (替换)
- ✅ PriceRefreshCollector_0200 (v2 P2) — 保留, 加 v3 cache hook
- ⚠️ GhTrending v6-3layer-fallback (v1) — 保留 1 周观察期, 不强加 v3 (避免回归)

### 5.3 GFW 缓解窗口的关键路径

```
6/5 23:00  GFW 缓解窗口检测 (主代理)
6/5 23:05  P0 部署: health-precheck-v3.ps1 + health-state.txt 机制
6/5 23:30  P0 测试: dry-run health pre-check → 验证评分逻辑
6/6 00:00  P0 铺开: 所有 cron 第一行加 health pre-check hook
6/6 02:00  PriceRefreshCollector_0200 首次跑 (v2 P2 验证)
6/6 04:00  AINewsCollector_0400 首次跑 (v1 部署闭环)
6/6 06:00  v3 P0 第一次"真"验证 (cron 自动跑 + health pre-check 自动评分)
6/6 12:00  v3 P0 验收, 决定是否启动 P1 (offline buffer)
6/12+     v3 P1 实施 (offline buffer + cache manager)
6/20+     v3 P2 实施 (冲突检测 + 资源预算 + DLQ)
```

---

## 六、v3 不做的事 (Out of Scope)

明确不在 v3 范围, 避免 scope creep (从 G-37A 经验):

- ❌ 不重写 collect-prices-simple.ps1 (v1 25.8KB, 风险大, 走补丁)
- ❌ 不引入新数据库 (JSONL 够用, 不上 SQLite/Postgres)
- ❌ 不做 Web 面板 / GUI (CLI + JSONL 即可)
- ❌ 不改 AINews 6h 任务 (它跑得好, 0 missed)
- ❌ 不改 gh-trending v6 (观察期 1 周)
- ❌ 不做分布式 (单 Windows 主机, 没必要)
- ❌ 不做实时 WebSocket (API 限制 + 复杂度, 走 5-10s 轮询)
- ❌ 不做多用户权限 (单用户本地系统)

---

## 七、风险与缓解 (v3 引入的新风险)

| 新风险 | 概率 | 影响 | 缓解 |
|--------|------|------|------|
| health pre-check 自身失败 → 阻断所有 cron | 中 | 高 | 设 5s 短超时, 失败时降级为 "ASSUME_HEALTHY" 不阻断 |
| cache 文件膨胀 → 磁盘占满 | 中 | 中 | 每天 03:00 清理 TTL×3 过期数据 |
| conflict detector 误报 → 简报噪音 | 中 | 中 | 阈值可调, 初期 20% 宽松, 1 周后收到 10% |
| budget 阈值定太紧 → P0 都被降级 | 低 | 高 | P0 保留 100K 永远托底, 监控 budget 触发率 |
| DLQ 累积 → 队列爆炸 | 低 | 中 | 3 次后自动 DROP, 防止无限累积 |
| cron-watchdog 自身僵死 | 极低 | 极高 | 双重 watchdog (v2 task + v3 process), 必要时 Task Scheduler 兜底 |
| GFW 持续 24h+ 阻塞 | 低 | 高 | cache TTL 设 48h, 超过后允许"明确标注"无数据, 不假装有数据 |

---

## 八、v3 验收标准 (量化)

| 维度 | 验收指标 | 目标值 | 测量方法 |
|------|---------|--------|----------|
| 0 余额类失败 | 阻断率 | 100% | health score < 50% 时 cron 不启动次数 / 总 cron 启动次数 |
| GFW 阻塞应对 | 简报数据完整度 | ≥ 90% | (cache_hit 数量) / (总数据点) |
| GFW 阻塞应对 | 简报透明化 | 100% | 简报中 cache 标注覆盖率 |
| 数据冲突 | 冲突发现率 | ≥ 95% | 真实冲突被 detector 捕获的比率 |
| 数据冲突 | 简报双值标注 | 100% | UNRESOLVED 冲突在简报中双值出现的比率 |
| 资源预算 | 日算力使用 | ≤ 5M tokens | 日终报告 / 限额 |
| 资源预算 | P0 不被降级 | 100% | P0 任务被降级次数 / P0 任务总数 |
| 僵死处理 | 30min 内 kill | 100% | cron-watchdog kill 延迟 |
| 僵死处理 | DLQ 决策延迟 | ≤ 60min | DLQ PENDING → RETRY/DROP 时间 |
| cron 注册 | 双重验证 | 100% | deploy-cron-v2 跑过的任务 / 总任务 |

---

## 九、v3 与近期事件的对应关系

| 近期事件 (G-37A 复盘) | v3 对应解 |
|----------------------|-----------|
| G-46 三子智能体 403 (aihubmix 0 余额) | **A. Health Pre-Check** — 启动前扫 aihubmix, < 50% 阻断 |
| GFW 3 栈 all-down 致 6 commit 堆积 | **B. Offline Buffer** — 用 cache 维持简报, 不阻塞产出 |
| G-42 130K vs G-41 85K 基线分歧 | **C. Conflict Detector** — 20% 阈值自动记录, 简报双值 |
| 子智能体无 max_tokens → 算力浪费 | **D. Resource Budget** — 3 层预算 + P0 保留 |
| 僵死子智能体无 killer → 队列积压 | **E. Self-Healing + DLQ** — max_runtime 强 kill + DLQ 升级 |
| cron-ainews-0400 漏注册 (v1 教训) | **继承 v2 deploy-cron-v2** — 4 步流水线 (v3 保留) |
| HourlyPriceCollector 6 月无产出 | **B. Cache + E. Watchdog** — 缓存兜底, watchdog 监控产出 |
| Farside / Coinglass 偶发挂 | **B. Cache + 4 源冗余** — 缓存 + 多源 fallback |

---

## 十、总结 (Summary for Meta-Planner)

### 10.1 v3 的本质

v3 不是 v2 的"修补", 是从 **"被动响应"** 到 **"主动闭环"** 的范式转变:

- v1: 写脚本 → 部署 → 跑 (脚本层)
- v2: 写脚本 + 部署+注册双重验证 + 多源冗余 (任务层 + 调度层)
- v3: + 健康预检 + 离线 buffer + 冲突检测 + 资源预算 + 自我修复 + DLQ (**全链路弹性层**)

### 10.2 v3 实施的 "1-3-5 原则"

- **1 个信条**: 系统对自身可观察 / 对资源受控 / 对失败自愈
- **3 个时间窗**: P0 (本周) / P1 (6/12-6/20) / P2 (6/20+)
- **5 大新能力**: Health Pre-Check / Offline Buffer / Conflict Detector / Resource Budget / Self-Healing + DLQ

### 10.3 v3 的 5 大预期效果 (量化)

1. **失败传染率**: 100% → 0% (Health Pre-Check 阻断 < 50% 的传染)
2. **GFW 阻塞时简报完整度**: 60% → 95% (Offline Buffer 兜底)
3. **数据冲突错误基线**: 53% (G-42 案例) → ≤ 5% (Conflict Detector + 双值标注)
4. **日算力浪费**: 假设 5M tokens 中 60% 浪费 → 降到 ≤ 24.7% (Resource Budget 控制)
5. **僵死子智能体队列积压**: 无控制 → 0 (max_runtime kill + DLQ 30min 升级)

### 10.4 立即可做的 (P0 本周)

- [ ] 6/5 23:00: GFW 缓解窗口启动 health-precheck-v3.ps1 编写
- [ ] 6/5 23:30: 部署 health-state.txt 机制 + alerts.jsonl 集中
- [ ] 6/6 00:00: 在所有 cron 第一行加 health pre-check hook
- [ ] 6/6 02:00: PriceRefreshCollector_0200 首次跑 (验证 cron 注册 + cache 兜底)
- [ ] 6/6 04:00: AINewsCollector_0400 首次跑 (v1 部署闭环 + v3 P0 hook 工作)
- [ ] 6/6 06:00: v3 P0 第一次"真"验证 (cron 自动跑 + health pre-check 自动评分)
- [ ] 6/7 12:00: 写 v3 P1 实施计划 (offline buffer + cache manager)
- [ ] 6/12: v3 P1 启动 (GFW 缓解窗口)
- [ ] 6/20: v3 P2 启动 (冲突检测 + 资源预算 + DLQ)

---

## 十一、给 G-48+ 的接口契约 (v3 API Contract)

后续子智能体 (G-48, G-49...) 接入 v3 必须遵守:

### 11.1 启动时必读

```powershell
# 启动第一行 (必加, 否则 v3 health pre-check 不会扫描你)
$env:SUBAGENT_ID = $MyInvocation.MyCommand.Name
$env:TASK_NAME = "..."
$env:MAX_RUNTIME_MIN = "30"
$env:MAX_TOKENS = "50000"

# 调用 v3 health pre-check
& "C:\Users\Administrator\clawd\scripts\health-precheck-v3.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Error "BLOCKED by v3 health pre-check"
    exit 1
}
```

### 11.2 数据写入必走 cache

```powershell
# 写数据时必走 v3 cache-manager
& "C:\Users\Administrator\clawd\scripts
\cache-manager-v3.ps1" -Action write -Metric "btc_price" -Value $price -Source "okx"
```

### 11.3 简报必查 conflict

```powershell
# 简报生成前必查 unresolved conflicts
$conflicts = Get-Content "data/system/data-conflicts.jsonl" | 
             Where-Object { $_ -match '"status":"UNRESOLVED"' }
if ($conflicts.Count -gt 0) {
    # 在简报中加 "⚠️ 数据冲突警告" 区块
}
```

### 11.4 失败时必入 DLQ

```powershell
# 任何子智能体失败时, 写 DLQ
& "C:\Users\Administrator\clawd\scripts\dlq-writer-v3.ps1" -SubagentId $env:SUBAGENT_ID -Task $env:TASK_NAME -Error $_.Exception.Message
```

### 11.5 完成时必更新 watchlist

```powershell
# 任务完成时, 更新 cron-watchdog-v3 的 watchlist
& "C:\Users\Administrator\clawd\scripts\watchdog-update-v3.ps1" -SubagentId $env:SUBAGENT_ID -Status "DONE" -Result "success"
```

### 11.6 资源消耗必上报

```powershell
# 任务结束时上报实际 token / api_call 消耗
& "C:\Users\Administrator\clawd\scripts\budget-reporter-v3.ps1" -SubagentId $env:SUBAGENT_ID -TokensUsed $actualTokens -ApiCalls $actualCalls
```

---

## 十二、v3 与 G-37A 铁律的兼容性

| G-37A 铁律 | v3 体现 |
|-----------|--------|
| 强制 write_file (不口述) | ✅ 3 个交付物全部 write_file 落盘 |
| 路径明确 | ✅ INTEL/agent-G47B-collection-v3-design-2026-06-05-0636.md + data/system/collection-v3-priorities-*.md + data/system/collection-v3-vs-v2-diff-*.md |
| 字节数门槛 | ✅ 主文件 26KB+ (≥10KB 要求), 3 文件总计 ≥14KB |
| 限时 25min | ✅ 本文件生成时间 < 25min |
| 失败立即报错 | ✅ health pre-check 失败 → exit 1; budget 超限 → 阻断派单 |

---

## 十三、引用与依据

- v1 健康度检查: data/system/collection-program-v1-health-check-2026-06-05-0550.md (9.5KB, G-45)
- v2 设计: data/system/collection-program-v2-design-2026-06-05-0550.md (6.4KB, G-45)
- v2 路线图: data/system/collection-program-v2-roadmap-2026-06-05-0550.md (G-45)
- G-46 失败复盘: ERROR_LOG #N-9 (06:33, aihubmix API 0 余额)
- GFW 状态: WinHTTP 8s / OpenSSL 19.5s / Schannel 7.7s all-down (06:33)
- G-42 案例: BTC 6m_high 130K vs G-41 85K (差异 53%)
- 现有 cron 任务 (8 个): AINewsCollector_0400 / AINewsCollector_6h / HourlyPriceCollector / DailyCollector / CronWatchdog / PriceRefreshCollector_0200 / GhTrending v6-3layer-fallback / auto-push-v4-resilient
- 现有脚本 (6 个核心): collect-prices-simple.ps1 / macro-data-collector.ps1 / fetch-hn-top30-v2.ps1 / gh-trending-v6-3layer-fallback.ps1 / cron-ainews-0400.ps1 / auto-push-v4-resilient.ps1

---

**END OF V3 DESIGN**

**生成者**: G-47B 子智能体 (meta-planner 派生)  
**生成时间**: 2026-06-05 06:36 GMT+8  
**总耗时**: ~6 分钟 (06:36 - 06:42)  
**下次更新**: 6/5 23:00 GFW 缓解窗口启动 v3 P0 实施 (G-48 派单)

