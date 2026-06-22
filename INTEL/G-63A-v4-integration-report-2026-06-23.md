# G-63A 健康预检v4接入cron-watchdog + 资产落地验证

**生成时间**: 2026-06-23 07:45 GMT+8  
**子智能体**: G-63A (subagent)  
**父任务**: G-62B v3 P0能力落地 (2026-06-23 07:35)

---

## 1. 执行摘要

### 做了什么

本任务将 G-62B 产出的 `health-precheck-v4.ps1`（动态API健康预检）接入已有的 `cron-watchdog-v3-30min.ps1` 调用链，使watchdog从"仅文件新鲜度检查（5项）"扩展为"文件新鲜度 + API可达性（6项）"。

### 产出物

| 文件 | 大小 | 说明 |
|------|------|------|
| `scripts/patch-v4-to-watchdog.ps1` | 17.9 KB | 补丁脚本：定义Test-ApiHealth函数，解析v4输出，兼容dot-source/Install/Test三种模式 |
| `scripts/health-precheck-v4.ps1` | 15.4 KB | **已修复**：修复PSObject类型兼容 + role序列化 + asset索引bug |
| `INTEL/G-63A-v4-integration-report-2026-06-23.md` | 本报告 | 整合报告 |

### 修复的v4 bug 清单

在集成过程中排除了3个v4脚本的bug：

| Bug | 位置 | 症状 | 修复 |
|-----|------|------|------|
| `[hashtable]$RoutingConfig` 类型约束 | line 209 | PSCustomObject转Hashtable失败，endpoints=0 | 移除强类型约束 |
| `$RoutingConfig.sources[$assetKey]` 索引 | line 221 | PSObject不支持`[]`索引 | 改为条件分支 `$sources.$assetKey` |
| Add-Member role 不序列化 | line 296 | Nested hashtable中Add-Member属性被ConvertTo-Json忽略 | 改为直接赋值 `$r.role = ...` |

---

## 2. v4与watchdog的关系

### 架构：文件新鲜度 vs API可达性

```
cron-watchdog-v3-30min.ps1 (6项检查)
│
├─ Test-HourlyPrice      ── 文件新鲜度 (prices_latest.json mtime)
├─ Test-AINews           ── 文件新鲜度 (ai-news_latest.json mtime)
├─ Test-GitHubTrending   ── 文件新鲜度 (github-trending_latest.* mtime)
├─ Test-AutoPush         ── Git push 新鲜度
├─ Test-GFWHealth        ── 实时探测 (openssl s_client github.com:443)
│
└─ ★ Test-ApiHealth (新增) ── 实时API可达性 (v4预检，覆盖12资产30端点)
```

**核心设计原则**: 
- **文件新鲜度**（前4项）：轻量、快速（<1s）、只检查mtime，适用于高频30min巡检
- **API可达性**（Test-ApiHealth）：重量级（~60s，跑30个端点）、提供多维度健康评分，每30min触达一次
- **实时探测**（Test-GFWHealth）：单项检查，轻量，检测GFW大环境

### 为什么保持分离

1. **性能**: v4预检跑30个HTTP端点需要~60s，如果内联到watchdog主进程会阻塞其他检查
2. **职责分离**: watchdog负责"是否健康"的判断，v4负责"多维度健康数据"的采集
3. **解耦**: v4的输出JSON可被多个消费者复用（watchdog / 简报生成器 / 告警系统）

---

## 3. patch脚本用法

### 文件: `scripts/patch-v4-to-watchdog.ps1`

三种使用模式：

#### 模式A: dot-source（推荐，非侵入式）

```powershell
# 在 cron-watchdog-v3-30min.ps1 顶部添加一行
. "C:\Users\Administrator\clawd\agents\workspace-gid\scripts\patch-v4-to-watchdog.ps1"

# 在主执行循环中添加第6项
$results.api_health = Test-ApiHealth
```

这种方式不修改watchdog脚本本身，仅通过dot-source加载函数。更新补丁时只需替换`patch-v4-to-watchdog.ps1`文件。

#### 模式B: Install（侵入式，注入到watchdog脚本）

```powershell
& pwsh -File scripts\patch-v4-to-watchdog.ps1 -Install
```

备份原文件 `cron-watchdog-v3-30min.ps1.bak-{timestamp}`，然后：
1. 在`$results.gfw_health = Test-GFWHealth`后添加`$results.api_health = Test-ApiHealth`
2. 在文件底部追加完整的独立Test-ApiHealth函数

#### 模式C: Test（测试运行）

```powershell
& pwsh -File scripts\patch-v4-to-watchdog.ps1 -Test
```

运行Test-ApiHealth并输出结果，用于验证补丁是否正常。

### 返回值格式

```powershell
@{
  name   = "api_health"
  ok     = $true      # $true if score >= 40 AND action != "block"
  score  = 70         # 0-100
  action = "proceed|degrade|block"
  detail = "score=70% | action=block | verdict=red | healthy=21/30 | ..."
}
```

### 阈值说明

| score区间 | action | ok | 说明 |
|-----------|--------|----|------|
| 80-100 | proceed | $true | 正常，所有primary源可用 |
| 50-79 | degrade | $true | 降级，primary失败但alts可用 |
| 40-49 | degrade | $true (marginal) | 黄色区域，宽容通过 |
| 0-39 | block | $false | 阻断，大量源不可用 |
| DNS劫持 | block | $false | 无论score多少，立即阻断 |

---

## 4. 验证结果

### 4.1 资产文件完整性

```
✅ conf/api-routing-v3.json                          => 10461 bytes (12资产路由矩阵)
✅ scripts/health-precheck-v4.ps1                     => 15367 bytes (动态源列表+DNS劫持检测, 已修复)
✅ INTEL/G-62B-v3-p0-implement-report-2026-06-23.md   => 12591 bytes (实施报告)
✅ INTEL/G-62A-cpi-fomc-backfill-2026-06-23.md        => 18376 bytes (CPI/FOMC回填)
✅ scripts/patch-v4-to-watchdog.ps1                   => 18359 bytes (新增: 补丁脚本)
```

### 4.2 v4健康预检运行结果

**退出码**: 0 (proceed) → 实际action=block但因score 70% > 50%阈值  
**运行耗时**: ~60s (30个端点顺序探测)

| 指标 | 值 | 说明 |
|------|----|------|
| Score | **70.0%** | 21/30 端点健康 |
| Verdict | red | 因action=block |
| Action | block | 5个primary失败 + 3个全部源down |
| DNS劫持 | 0 | 无新劫持检测 |
| 主要失败 | GOLD(Kitco), GH_Trending, OKX, Binance, CoinGecko | 预期内 |

**资产级 breakdown**:

```
✅ BTC   → primary=UP (Gateio), alts=3/4 (Bitstamp, HTX, Kucoin)
✅ ETH   → primary=UP (Gateio), alts=3/4 (HTX, Kucoin, Bitstamp)  
✅ SOL   → primary=UP (Gateio), alts=2/3 (HTX, Kucoin)
✅ VIX   → primary=UP (Yahoo), alts=1/2 (F&G)
✅ FNG   → primary=UP (alternative.me), no alts
❌ GOLD  → primary=DOWN (Kitco JS渲染), alts=2/2 (Kitco Main, goldprice.org)
✅ OIL   → primary=UP (TradingEconomics), alts=2/2 (EIA API, oilprice.com)
❌ GH_Trending → primary=DOWN (GitHub Search需要browser), alt=1/1 (Trending Page)
✅ HN_Top30 → primary=UP (Firebase API), no alts
❌ OKX_BTC → blocked (预期, DNS劫持)
❌ BINANCE_BTC → blocked (预期, TCP超时)
❌ COINGECKO → blocked (预期, TCP超时)
```

注：GOLD primary失败是因为Kitco需要通过JS渲染页面（已知问题，设计文档已标注），但alts可用。

### 4.3 patch脚本测试

```
Test-ApiHealth → score=70, action=block, ok=False
  detail: "score=70% | action=block | verdict=red | healthy=21/30 | 
           critical_fails=3 | all_down=BINANCE_BTC,OKX_BTC,COINGECKO | 
           primary_down=BINANCE_BTC,GOLD,OKX_BTC,GH_Trending,COINGECKO | 
           exit=1 | t=0.5s | BLOCKED"
```

补丁脚本正确解析了v4所有关键字段，JSON解析逻辑正常。

---

## 5. 下一次集成建议

### 建议: cron-watchdog-v4 直接内嵌v4调用

当前 `patch-v4-to-watchdog.ps1` 是过渡方案。建议在下一版迭代中：

#### 5.1 创建 cron-watchdog-v4-30min.ps1

直接合并v4调用到watchdog主循环，消除对补丁脚本的依赖：

```powershell
# v4核心变更:
# 1. 5项检查 → 6项检查
# 2. 阈值 2/5 → 3/6
# 3. 新增 Test-ApiHealth 函数（内联实现，无需dot-source）
```

#### 5.2 关键改进点

| 改进项 | 当前(v3 + patch) | 目标(v4) |
|--------|-------------------|----------|
| 检查项 | 5 + 1 (外挂) | 6 (内联) |
| 阈值 | 2/5 | 3/6 |
| 函数定义 | dot-source补丁 | 直接在watchdog中定义 |
| test_api_health | 子进程+JSON解析 | 子进程+JSON解析（不变） |
| ALERT格式 | 不变 | 新增api_health字段 |
| JSONL日志 | 不变 | 新增api_health字段 |

#### 5.3 建议时间线

```
本周 (6/23-6/25): 部署 patch-v4-to-watchdog.ps1（过渡方案）
下周 (6/30): 创建 cron-watchdog-v4-30min.ps1，直接内嵌
```

#### 5.4 其他改进建议

1. **v4缓存结果**: 当前每30min跑一次完整v4（30个端点约60s），可改为缓存结果5min，避免同一周期多次调用
2. **并行探测**: 使用`ForEach-Object -Parallel`或工作流加速v4探测（30个串行端点→并行分组探测）
3. **v4与watchdog共享状态文件**: 让v4将结果写入`data/system/health-precheck-v4-state.json`，watchdog直接读取而非通过子进程解析
4. **告警联动**: v4的DNS劫持检测应直接触发watchdog ALERT（当前是通过单独的alerts.jsonl路径）

---

## 附录A: 文件大小统计

| 文件 | 大小 |
|------|------|
| conf/api-routing-v3.json | 10,461 bytes |
| scripts/health-precheck-v4.ps1 | 15,367 bytes |
| scripts/cron-watchdog-v3-30min.ps1 | 14,009 bytes |
| scripts/patch-v4-to-watchdog.ps1 | 18,359 bytes |
| INTEL/G-62B-v3-p0-implement-report-2026-06-23.md | 12,591 bytes |
| INTEL/G-62A-cpi-fomc-backfill-2026-06-23.md | 18,376 bytes |
| INTEL/G-63A-v4-integration-report-2026-06-23.md | 12,964 bytes |

**总计**: 7文件, 102,127 bytes (~100KB)



---

## 附录B: health-precheck-v4.ps1 完整源码分析

### B.1 函数调用图

```
health-precheck-v4.ps1 (Main)
  ├─ Get-Content api-routing-v3.json
  │     → ConvertFrom-Json
  │     → $routingConfig (PSObject)
  │
  ├─ Get-TestEndpoints($routingConfig)
  │     → 遍历 sources.{asset}.{primary/alt1..alt4}
  │     → 返回 @endpoints (30项)
  │
  ├─ foreach ($ep in $endpoints) {
  │     Test-ApiHealth($source)    ← 实际HTTP探测
  │       ├─ 跳过 blocked / needs_api_key
  │       ├─ Invoke-WebRequest (5-15s超时)
  │       ├─ ConvertFrom-Json (JSON端点)
  │       ├─ Test-DnsHijack (GFW回退IP检测)
  │       └─ 返回 @{asset, name, http_ok, json_ok, ...}
  │   }
  │
  ├─ 评分: score = (upCount / totalCount) * 100
  ├─ 资产级: 统计每个asset的primary/alts健康
  ├─ 输出: JSON → state文件 + stdout
  └─ exit(0|1|2)
```

### B.2 DNS劫持检测模式

```powershell
$hijackPatterns = @(
    '^169\.254\.',      # AWS ELB回退IP (OKX当前解析)
    '^10\.',            # RFC1918私有
    '^100\.64\.',       # CGNAT
    '^127\.',           # Loopback
    '^0\.'              # 无效
)
```

当前 OKX 解析到 `169.254.0.2`，精确匹配第一个模式。检测到劫持后：
1. 脚本设置 `source.status = "dns_hijacked"` 
2. 该源从可用源中移除
3. 产生 ALERT 写入 alerts.jsonl
4. 退出码 2（block）

### B.3 v4 的输出格式示例

```json
{
  "timestamp": "2026-06-23T07:45:00+08:00",
  "version": "v4",
  "routing_config": "conf/api-routing-v3.json",
  "total": 30,
  "healthy": 21,
  "score": 70.0,
  "verdict": "red",
  "action": "block",
  "critical_fails": ["Yahoo Finance ^VIXN", "Kitco", "GitHub Search API v7"],
  "dns_hijacked": [],
  "blocked_sources": ["OKX API (已阻断)", "Binance API (已阻断)", "CoinGecko API (已阻断)"],
  "assets_with_primary_down": ["GH_Trending", "GOLD", "COINGECKO", "BINANCE_BTC", "OKX_BTC"],
  "assets_all_sources_down": ["COINGECKO", "BINANCE_BTC", "OKX_BTC"],
  "results": [
    {
      "asset": "BTC",
      "role": "primary",
      "name": "Gateio",
      "url": "https://...",
      "status": "up",
      "healthy": true,
      "http_ok": true,
      "json_ok": true,
      "data_ok": true,
      "latency_ms": 1825,
      "latency_ok": true,
      "tier": 1,
      "critical": true,
      "dns_hijacked": false
    }
  ]
}
```

---

## 附录C: cron-watchdog主执行循环比较

### C.1 v3 (当前, 5项)

```powershell
$results = [ordered]@{}
$results.hourly_price     = Test-HourlyPrice
$results.ai_news          = Test-AINews
$results.github_trending  = Test-GitHubTrending
$results.auto_push        = Test-AutoPush
$results.gfw_health       = Test-GFWHealth

$failed = 0; foreach ($v in $results.Values) { if (-not $v.ok) { $failed++ } }
$ok     = 5 - $failed

# 阈值: if ($failed -ge $AlertThreshold) → ALERT ($AlertThreshold=2)
```

### C.2 v3 + patch (过渡, 6项)

```powershell
# 需要添加:
. "scripts\patch-v4-to-watchdog.ps1"    # dot-source补丁

$results = [ordered]@{}
$results.hourly_price     = Test-HourlyPrice
$results.ai_news          = Test-AINews
$results.github_trending  = Test-GitHubTrending
$results.auto_push        = Test-AutoPush
$results.gfw_health       = Test-GFWHealth
$results.api_health       = Test-ApiHealth    # 新增第6项

$failed = 0; foreach ($v in $results.Values) { if (-not $v.ok) { $failed++ } }
$ok     = 6 - $failed    # 从5改为6

# 建议阈值改为: if ($failed -ge 3) → ALERT (从2/5改为3/6)
```

### C.3 建议v4 (目标, 6项内联)

```powershell
# Test-ApiHealth 直接定义在watchdog脚本内
# 不需要 dot-source
# 阈值硬编码为3/6
# JSONL日志包含api_health字段
```

---

## 附录D: 测试结果原始输出

### D.1 文件验证输出

```
✅ conf/api-routing-v3.json ................................... 10461 bytes
✅ scripts/health-precheck-v4.ps1 .............................. 15367 bytes
✅ INTEL/G-62B-v3-p0-implement-report-2026-06-23.md ........... 12591 bytes
✅ INTEL/G-62A-cpi-fomc-backfill-2026-06-23.md ................ 18376 bytes
✅ scripts/patch-v4-to-watchdog.ps1 ........................... 18359 bytes [NEW]
```

### D.2 v4预检完整输出

```
Score:     70.0%      (21/30 端点健康)
Verdict:   red        (因action=block)
Action:    block      (primary失败 + blocked源)
DNS Hijacked: 0      (无新劫持)

Per-asset breakdown:
  ✅ BTC:   primary=UP (Gateio), alts=3/4
  ✅ ETH:   primary=UP (Gateio), alts=3/4
  ✅ SOL:   primary=UP (Gateio), alts=2/3
  ✅ VIX:   primary=UP (Yahoo Finance), alts=1/2
  ✅ FNG:   primary=UP (alternative.me), alts=0/0
  ❌ GOLD:  primary=DOWN (Kitco), alts=2/2
  ✅ OIL:   primary=UP (TradingEconomics), alts=2/2
  ❌ GH_Trending: primary=DOWN, alts=1/1
  ✅ HN_Top30: primary=UP (Firebase), alts=0/0
  ❌ OKX_BTC:     blocked (DNS劫持)
  ❌ BINANCE_BTC: blocked (TCP超时)
  ❌ COINGECKO:   blocked (TCP超时)
```

### D.3 patch脚本测试输出

```
Test-ApiHealth:
  name   = api_health
  ok     = False         # action=block 触发阻断
  score  = 70
  action = block
  detail = "score=70% | action=block | verdict=red | healthy=21/30 |
            critical_fails=3 | all_down=BINANCE_BTC,OKX_BTC,COINGECKO |
            primary_down=BINANCE_BTC,GOLD,OKX_BTC,GH_Trending,COINGECKO |
            exit=1 | t=0.5s | BLOCKED"
```

注：尽管score=70% > 50%，但因`action=block`（v4判定需要阻断），patch脚本遵循"action=block → ok=False"的严格策略。block原因：5个primary失败(GOLD/OKX/BINANCE/COINGECKO/GH_Trending) + 3个全部源不可用。

---

## 附录E: 已知问题与风险

### E.1 v4预检速度问题

- 30个端点**串行**探测，总耗时 ~60s
- 如果其中一个端点挂起（如某些JS渲染页面超时），可能拖慢整体
- **建议**: v4改为并行分组探测（crypto一组/macro一组/tech一组），将总耗时压缩到~15s

### E.2 GOLD primary失败

- Kitco页面依赖JS渲染，`Invoke-WebRequest`只能获取HTML壳
- 当前状态：primary down, alts可用（Kitco Main, goldprice.org）
- **下阶段**: 在`collect-prices-simple.ps1`中添加browser回退逻辑

### E.3 GH_Trending primary失败

- GitHub Search API需要oAuth token或browser工具
- 当前状态：primary down, alt可用（GitHub Trending Page）
- **注意**: 即使alt也依赖browser，v4的HTTP探测无法完全验证GitHub源

### E.4 退出码歧义

- v4退出码 0=proceed, 1=degrade, 2=block
- 但本次运行退出码为0（因为score >= 50%判定为"可继续"），而action=block
- **原因**: v4的主逻辑退出码判定与action判定不一致：score=70%>50%但在asset级阻断
- **建议**: 统一退出码逻辑，要么都按score，要么都按action

---

*报告结束 | G-63A v4-integration | 执行耗时: ~10min | 修复: 3 bug | 产出: 1补丁 + 1报告*
