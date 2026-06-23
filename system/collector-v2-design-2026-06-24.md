# 采集程序 v2 设计方案

**版本**: v2.0
**日期**: 2026-06-24 04:26 GMT+8
**起草**: G-102 子智能体 (基于MEMORY.md + HEARTBEAT.md + 全部历史bug分析)
**架构师**: 元规划者层

---

## 一、问题诊断 (v1架构缺陷)

### 1.1 飞散式cron无统一管控

| 问题 | 实例 | 影响 |
|------|------|------|
| cron意外Disabled | HourlyPriceCollector, BridgeCollector, cron-watchdog (多次) | 数据断档19-23天 |
| 无健康自检 | cron死了但无报警 | 元层直到用户或推送失败才发现 |
| 多脚本无统一入口 | ~8个cron + 5个采集脚本 | 启动基线不一致，失败根因难以追踪 |

### 1.2 元规划者层活化缺失

| 问题 | 实例 |
|------|------|
| 元层只有手动触发路径 | 派单方手工扫描→派发子智能体→简报 |
| cron-watchdog设计未完成 | 5:50设计的"派单方接管"从未实际部署 |
| 断档后发现太晚 | 6/5至6/23连续19天无产出 |

### 1.3 具体数据Bug

| Bug | 时长 | 根因 |
|-----|------|------|
| F&G 21天未更新 | 6/3→6/23 | F&G采集cron失效 |
| 简报零产出 | 19天 | 元层活化机制不存在 |
| 价格数据源切换不稳定 | 持续 | OKX/Binance API失败时降级门控不可靠 |
| 黄金/原油降级链 | 持续 | 浏览器超时→web_fetch失败→估算值 |

---

## 二、v2架构设计

### 2.1 高层架构

```
                    ┌──────────────────────┐
                    │    元规划者层保活     │
                    │  (heartbeat-activator) │
                    └──────────┬───────────┘
                               │ 每30min触发
                    ┌──────────▼───────────┐
                    │   统一采集调度器     │
                    │  (collector-master.ps1)│
                    └──┬──┬──┬──┬──┬──┬──┘
                       │  │  │  │  │  │
         ┌─────────────┘  │  │  │  │  └──────────────┐
         ▼                ▼  ▼  ▼  ▼                 ▼
    ┌─────────┐   ┌──────────────────────┐   ┌────────────┐
    │价格采集器│   │ 数据新鲜度自检+补采  │   │简报触发器  │
    └─────────┘   └──────────────────────┘   └────────────┘
```

### 2.2 组件详细设计

#### A. 统一采集调度器 (`collector-master.ps1`)

**定位**: 替代所有分散cron的单一入口点。Task Scheduler只运行这一个脚本。

**输入**: `system/scheduler-config.json` （集中配置）

```json
{
  "cycles": {
    "price_1h": { "interval_min": 60, "script": "scripts/collect-prices-simple.ps1" },
    "ai_news_6h": { "interval_min": 360, "script": "scripts/collect-ai-news-all.ps1" },
    "gh_trending_30m": { "interval_min": 30, "script": "scripts/gh-trending-v6-3layer-fallback.ps1" },
    "macro_4h": { "interval_min": 240, "script": "scripts/macro-all-in-one.ps1" },
    "fnf_1h": { "interval_min": 60, "script": "scripts/collect-fear-greed.ps1" },
    "briefing_12h": { "interval_min": 720, "script": "gen:briefing" }
  },
  "freshness": {
    "check_interval_min": 30,
    "max_age_min_per_source": {
      "price": 90,
      "macro": 240,
      "fnf": 120,
      "ai_news": 360
    }
  }
}
```

**调度逻辑**:
1. 每启动时读入配置
2. 检查每个cycle的 `last_run_time` (从 `data/market/last_run.json` 读)
3. 如果 `now - last_run_time >= interval_min`，执行该cycle
4. 所有cycle执行完毕后写入 `last_run_time`
5. 执行 `freshness_check` 阶段

**Task Scheduler配置**: 只注册一个 `GidaCollectorMaster`，每30min触发一次。使用mutex防重入。

**优势**:
- 单点管控 — 只有一个cron，Disabled就只有一个
- 去重执行 — 30min周期的master不导致1h任务执行2次
- 集中日志 — 所有cycle的执行记录写入单个JSONL
- 自愈 — 如果某cycle失败，下次master运行时自动重试

#### B. 数据新鲜度自检 + 自动补采 (`freshness-check.ps1`)

**功能**: 验证所有数据源的新鲜度，自动触发补采

**工作流**:
```
1. 读取 prices_latest.json timestamp
2. 对每个数据源计算 age = now - timestamp
3. 如果 age > max_age_min:
   a. 记录到 data/market/freshness-violations.jsonl
   b. 自动执行补采脚本
   c. 如果补采成功 -> 更新状态
   d. 如果连续3次补采失败 -> 生成ALERT
```

**关键阈值**:
| 数据源 | max_age_min | 降级动作 |
|--------|-------------|----------|
| BTC/ETH/SOL | 90 | 自动重采 + 换源 |
| GOLD/OIL | 240 | 自动重采 + 降级估算 |
| F&G | 120 | 自动重采 |
| AI News | 360 | 自动重采 |
| HN Trending | 180 | 自动重采 |

**补采逻辑** (v2新增):
- 如果普通采集失败，不立即估算，而是尝试降级链的下一个源
- 记录补采次数，超过3次/30min则发ALERT
- GOLD/OIL从静态估算回源改为尝试多源轮询

#### C. 元规划者层保活机制 (`heartbeat-activator.ps1` 或内建于master)

**问题**: 当前元规划者层只有"派单方手动触发"一条路径
**v2方案**: 元规划者层自身独立活化

**设计**:
```
┌────────────────────────────────────┐
│        派单方会话 (主路径)          │
│  用户主动消息 → 元层激活            │
└────────────────────────────────────┘
            OR
┌────────────────────────────────────┐
│      heartbeat-activator (备路径)   │
│                                    │
│  1. cron-watchdog 检测到异常        │
│  2. 检测到数据老化 >1h             │
│  3. 检测到简报老化 >12h            │
│  4. 检测到 cron Disabled           │
│  → 任一条触发 → 唤醒元规划者层       │
└────────────────────────────────────┘
```

**唤醒协议**:
1. `heartbeat-activator` 写入 `system/activate-signal.json`
2. 信号内容包括: 触发原因、数据老化状态、优先级
3. cron-watchdog 在每轮执行前检查信号文件
4. 如果检测到信号:
   - 标记: 心跳用"有任务待处理"模式运行
   - 保留常规HEARTBEAT_OK模式
5. **最大静默时间**: 如果12h无心跳触发，heartbeat-activator 强制发一次通知

**实现建议**: 最简单的实现是在 `cron-watchdog-v3-30min.ps1` 中加入活化检测逻辑

#### D. F&G采集修复

**当前问题**: F&G 21天断档 — cron失效后无自动恢复

**v2修复**:
1. **新独立脚本**: `scripts/collect-fear-greed.ps1`
   - 源: `alternative.me/crypto/fear-and-greed-index/` (web_fetch可用)
   - 输出: `data/macro/fng_latest.json`
   - 同时写入 `prices_latest.json macro.VIX`
2. **纳入master调度**: 在 `scheduler-config.json` 中配置1h周期
3. **新鲜度告警**: 如果F&G age > 2h，触发黄色告警

**F&G采集流程**:
```
web_fetch alternative.me → 解析JSON中的value → 写入fng_latest.json
→ 同步至prices_latest.json macro.VIX.value
→ 如果失败：CryptoCompare VIX 备选 → 写入但标注confidence=medium
→ 如果全失败：保持最近一次值 + 标注age + 触发补采
```

#### E. 简报自动生成触发器 (`briefing-trigger.ps1`)

**条件**: 以下任意满足时触发简报生成
- 每12h固定 (08:00 / 20:00)
- 价格单变量变化 >5% (24h)
- F&G变化 >10点 (24h)
- 数据补采后全部恢复
- 元规划者层恢复后自动补发恢复简报

**输出**: `briefings/YYYY-MM-DD-HHmm.md`
**触发方式**: 写入 `system/briefing-trigger.json`，供即将恢复的元规划者层读取并生成简报

---

## 三、实施路线图

### Phase 1: 修复 + 补丁 (今明，P0)

| # | 任务 | 工作量 | 优先级 |
|---|------|--------|--------|
| 1 | 编写 `collect-fear-greed.ps1` (独立脚本) | 15min | P0 |
| 2 | 修复所有cron的Enable状态 + 记录LastRunTime | 10min | P0 |
| 3 | 手动补采F&G 21天历史 + 写入JSON | 15min | P0 |
| 4 | 在cron-watchdog中增加F&G新鲜度检查 | 5min | P0 |

### Phase 2: 统一调度器 (本周，P1)

| # | 任务 | 工作量 | 优先级 |
|---|------|--------|--------|
| 1 | 编写 `collector-master.ps1` (主控脚本) | 60min | P1 |
| 2 | 编写 `scheduler-config.json` (配置) | 10min | P1 |
| 3 | 编写 `freshness-check.ps1` (新鲜度自检) | 30min | P1 |
| 4 | 编写 `last_run.json` 存储 + 读取逻辑 | 10min | P1 |
| 5 | 停用旧cron, 注册新 `GidaCollectorMaster` | 10min | P1 |
| 6 | 测试跑通: 30min窗口内price+macro+fnf全覆盖 | 20min | P1 |

### Phase 3: 元层活化 + 简报警报 (6月底，P2)

| # | 任务 | 工作量 | 优先级 |
|---|------|--------|--------|
| 1 | 编写 `heartbeat-activator.ps1` (或集成到watchdog) | 30min | P2 |
| 2 | 编写 `briefing-trigger.ps1` | 15min | P2 |
| 3 | 12h静默告警回路 | 10min | P2 |
| 4 | 整合测试: 模拟cron Disable → 自动恢复 | 20min | P2 |

---

## 四、架构对比

| 维度 | v1 (当前) | v2 (目标) |
|------|-----------|-----------|
| cron数量 | 6-8个 | 1个 (master) |
| 健康检查 | 无 | 30min级新鲜度自检 |
| 自动修复 | 无 | 失败自动重试+降级链 |
| 元层活化 | 仅手动 | 自动+定时 |
| 简报触发 | 手动 | 定时+阈值 |
| F&G采集 | 附属脚本(易断) | 独立脚本+独立调度 |
| 故障MFDT | 19天 | <2h |

---

## 五、文件结构变更

```
scripts/
├── collector-master.ps1          ★ NEW (统一调度器)
├── freshness-check.ps1           ★ NEW (新鲜度自检)
├── collect-fear-greed.ps1        ★ NEW (F&G独立采集)
├── heartbeat-activator.ps1       ★ NEW (元层保活)
├── briefing-trigger.ps1          ★ NEW (简报触发器)
├── collect-prices-simple.ps1     (保留，由master调用)
├── gh-trending-v6-3layer-fallback.ps1 (保留)
└── merge-ai-news.ps1             (保留)

system/
├── scheduler-config.json         ★ NEW (集中配置)
└── activate-signal.json          ★ NEW (元层唤醒信号)

data/
└── market/
    ├── prices_latest.json        (保留)
    ├── fng_latest.json           ★ NEW (F&G独立存储)
    ├── last_run.json             ★ NEW (调度器时间戳)
    └── freshness-violations.jsonl ★ NEW (异常日志)
```

---

## 六、关键指标 (KPI)

| 指标 | 当前 | v2目标 |
|------|------|--------|
| 简报产出频率 | ~0/天 | 2/天 (固定) + 事件驱动 |
| F&G更新延迟 | 21天 | <2h |
| 元层沉默时间 | 19天 | <4h |
| cron Disable恢复时间 | 2h+ (手动发现) | <30min (自动) |
| 数据新鲜度<1h比例 | 约60% | >90% |
| 推送成功率 | ~70% | >80% (GFW容忍) |

---

*设计文档 v1.0 | 由 G-102 子智能体基于全量历史数据分析生成 | 实施建议: 按Phase 1→2→3顺序执行，Phase 1需在4h内完成修复*
