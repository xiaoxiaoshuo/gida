# 采集程序 v3 实施优先级 — 2026-06-05 06:36 GMT+8

**规划者**: G-47B 子智能体 (meta-planner 派生)  
**基础**: G-45 v2 路线图 + G-46 失败复盘 + G-37A 复盘经验  
**目标**: 把 v3 的 5 大新能力按风险/价值分窗口, 避免一次性铺开

---

## 〇、优先级矩阵总览

| 优先级 | 能力 | 实施窗口 | 风险 | 状态 |
|--------|------|---------|------|------|
| **P0** | A. API 健康预检层 | **本周 (6/5-6/12)** | 🟢 低 | **必做** |
| **P1** | B. 离线 Buffer + 增量同步 | **6/12-6/20** | 🟡 中 | 重要 |
| **P2-1** | C. 数据冲突检测器 | **6/20+** | 🟢 低 | 增值 |
| **P2-2** | D. 资源预算机制 | **6/20+** | 🟡 中 | 重要 |
| **P2-3** | E. 自我修复 + 死信队列 | **6/20+** | 🟠 中高 | 关键 |

**分窗口理由**:
- P0 选本周: G-46 失败是当下痛点 (aihubmix 0 余额), 必须本周解决, 否则 6/12 NFP+三重共振窗口再炸
- P1 选 6/12-6/20: GFW 缓解窗口 (历史经验 6/12-6/20 段相对稳定), cache 适合此时铺开
- P2 三项选 6/20+: 都不直接防 NFP, 留给实施时间充裕 + 不阻塞主线

---

## 一、P0: API 健康预检层 (本周 6/5-6/12)

### 1.1 实施步骤 (详细可执行清单)

#### Step 1: 编写 health-precheck-v3.ps1 (6/5 23:00-23:30)
- **负责人**: 主代理 (派单 G-48 子智能体编写)
- **动作**:
  1. 抄写 v3 设计文件中的核心脚本 (10 个 API endpoint × health scoring)
  2. 测试 dry-run: `pwsh -File health-precheck-v3.ps1 -DryRun`
  3. 验证输出: `data/system/health-precheck_latest.json` 格式正确
- **产物**: `C:\Users\Administrator\clawd\scripts\health-precheck-v3.ps1` (~3KB)
- **验证**: 手动跑 1 次, 确认 10 个 endpoint 都能被扫描, JSON 落盘

#### Step 2: 部署 health-state.txt 机制 (6/5 23:30-00:00)
- **负责人**: 主代理
- **动作**:
  1. 在所有 cron 脚本第一行加: `if (Test-Path "C:\Users\Administrator\clawd\data\system\health-state.txt") { $state = Get-Content ...; if ($state -eq "BLOCKED") { exit 1 } }`
  2. 不强制阻断 (避免健康检查自身失败导致全面崩), 仅写日志 + alerts.jsonl
- **产物**: 6 个 cron 脚本第一行加 hook
- **验证**: 手动写 "BLOCKED" 到 health-state.txt, 跑一个 cron 验证 exit 1

#### Step 3: 部署 alerts.jsonl 集中机制 (6/6 00:00-00:30)
- **负责人**: 主代理
- **动作**:
  1. 创建 `C:\Users\Administrator\clawd\data\system\alerts.jsonl` (空文件)
  2. health-precheck-v3.ps1 写 alert 格式: `{level, msg, timestamp, ...}`
  3. 主代理每心跳读 alerts.jsonl, 决定是否升级
- **产物**: alerts.jsonl 持续累积
- **验证**: 模拟一次 health score < 50%, 确认 alert 写入

#### Step 4: 真实环境验证 (6/6 02:00 / 04:00 / 06:00)
- **负责人**: cron (自动) + 主代理 (观察)
- **动作**:
  1. 6/6 02:00: PriceRefreshCollector_0200 首次跑 → hook 应被触发
  2. 6/6 04:00: AINewsCollector_0400 首次跑 → hook 应被触发
  3. 6/6 06:00: 早窗口期所有 cron 跑一遍 → 收集 6h 数据
- **产物**: `data/system/health-precheck-2026-06-06-*.json` 一系列
- **验证**: 检查 6/6 06:30 时, 至少 1 个 health score 报告存在, 评分合理 (0-100%)

### 1.2 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| health pre-check 自身 hang → 阻断所有 cron | 中 | 高 | 设 5s 总超时, 超时降级为 "ASSUME_HEALTHY" |
| 阈值 70% / 50% 误判频繁 | 中 | 中 | 第 1 周保守 (60% / 40%), 第 2 周收到 70% / 50% |
| alerts.jsonl 膨胀 | 低 | 低 | 每周日归档到 `data/system/alerts-archive-YYYY-MM-DD.jsonl` |

### 1.3 验收标准 (6/12 评估)

- ✅ 6/6 - 6/12 期间, 至少 10 次 health pre-check 自动跑
- ✅ 所有 6 个 cron 任务第一行有 hook
- ✅ alerts.jsonl 有真实 alert 记录 (即使 health score 永远 100%, 也应有 0 个 alert 记录可解释)
- ✅ 主代理能在 06:33 类失败 (aihubmix 0 余额) 发生时, 通过 health score 提前 5-10min 察觉
- ✅ 6/12 NFP 窗口当天, health score 实时可见, 阻断无效派单

---

## 二、P1: 离线 Buffer + 增量同步 (6/12-6/20)

### 2.1 实施步骤

#### Step 1: cache-manager-v3.ps1 编写 (6/12 23:00-23:30)
- **负责人**: 主代理 + G-49 子智能体
- **动作**:
  1. 编写 `cache-manager-v3.ps1` 支持 write/read/cleanup 三个 action
  2. TTL 配置文件: `data/system/cache-ttl-config.json` (每个 metric 的周期)
  3. 测试: 模拟写入 1 个数据点, 读回, 确认 cache_hit=false
- **产物**: `scripts/cache-manager-v3.ps1` (~5KB)
- **验证**: 单测 3 个 metric (btc_price / fng / ai_news), 写入 + 读回 + 标记 cache_hit

#### Step 2: 改造 4 个核心 cron 走 cache (6/13-6/14)
- **负责人**: 主代理
- **动作**:
  1. collect-prices-simple.ps1 → 调用 cache-manager 写 btc/eth/sol
  2. cron-ainews-0400.ps1 → 调用 cache-manager 写 ai_news
  3. macro-data-collector.ps1 → 调用 cache-manager 写 fng
  4. fetch-hn-top30-v2.ps1 → 调用 cache-manager 写 hn_top
- **产物**: 4 个脚本各加 1-2 行 hook
- **验证**: 跑一次, 检查 `data/cache/{metric}-{date}.jsonl` 落盘

#### Step 3: 失败降级逻辑 (6/15-6/16)
- **负责人**: 主代理
- **动作**:
  1. 在 cron 脚本中加 try/catch: API 失败 → 调 cache-manager read → 标 cache_hit=true
  2. 失败原因记录: gfw_all_stacks_down / api_403 / health_degraded / source_all_failed
  3. 简报生成时显式列出 cache_hit=true 的数据点
- **产物**: 4 个 cron 脚本的错误处理升级
- **验证**: 故意断网 (拔网线) 跑一次, 确认降级到 cache, 数据点带 cache_hit=true

#### Step 4: 增量同步 (6/17)
- **负责人**: 主代理
- **动作**:
  1. 编写 `incremental-sync-v3.ps1`, GFW 恢复后扫 24h gap
  2. 不实际补历史 (API 不支持), 只标记 gap
  3. 简报生成时, 把 gap 时段显式标"本时段无实时数据, 来自 cache"
- **产物**: `scripts/incremental-sync-v3.ps1` (~2KB)
- **验证**: 模拟 GFW 恢复, 跑一次, 确认 gap 报告生成

#### Step 5: cache 清理机制 (6/18)
- **负责人**: 主代理
- **动作**:
  1. cache-manager-v3.ps1 加 cleanup action: 删除 TTL × 3 之前的数据
  2. 注册 cron: `cache-cleanup-0300.ps1` 每天 03:00 跑
- **产物**: 1 个新 cron + cleanup 逻辑
- **验证**: 写一批过期数据, 跑 cleanup, 确认删除

### 2.2 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| cache 文件膨胀 | 中 | 中 | TTL×3 清理 + 每周日归档 |
| cache_hit=true 数据被误用为真实数据 | 中 | 高 | 简报强制标注, 标 ⚠️ 显眼标记 |
| 增量同步误报 gap | 低 | 低 | gap 定义: ≥2h 连续缺失才算 gap, 1h 缺失允许 |
| cache TTL 太长 → 简报引用过期数据 | 低 | 中 | 简报生成时校验 data_timestamp, 超过 4h 标"过期" |

### 2.3 验收标准 (6/20 评估)

- ✅ 4 个核心 cron 走 cache 写入
- ✅ 模拟 GFW 阻塞, 简报能正常生成 (cache 兜底)
- ✅ 简报中 cache_hit=true 数据点有显式标注
- ✅ cache 文件每日 03:00 自动清理
- ✅ GFW 恢复后, 简报标出"哪些小时是 cache"

---

## 三、P2: 冲突检测 + 资源预算 + DLQ (6/20+)

### P2-1: 数据冲突检测器 (6/20-6/25)

#### 实施步骤

1. **conflict-detector-v3.ps1 编写 (6/20 23:00)**
   - 负责人: 主代理
   - 动作: 写 detector + jsonl 记录 + 状态机
   - 产物: `scripts/conflict-detector-v3.ps1` (~4KB)
   - 验证: 模拟 OKX=85K vs CoinGecko=130K, 确认 conflict 记录生成

2. **多源采集器改造 (6/21-6/22)**
   - 负责人: 主代理
   - 动作: collect-prices 加 secondary 源调用 (OKX + Binance)
   - 产物: collect-prices-simple 升级 (v3 二级源)
   - 验证: 同时调 OKX + Binance, 差异 > 5% 时写 conflict

3. **简报冲突标注 (6/23-6/24)**
   - 负责人: 主代理
   - 动作: 简报生成前扫 conflicts.jsonl, 注入 "⚠️ 数据冲突警告" 区块
   - 产物: 简报模板升级
   - 验证: 模拟 1 个 UNRESOLVED 冲突, 确认简报中双值都列出

4. **元规划者层心跳扫描 (6/25)**
   - 负责人: 主代理 (心跳)
   - 动作: conflict-scanner-v3.ps1 每 30min 跑
   - 产物: cron-watchdog 加 hook
   - 验证: 30min 周期内, 至少 1 次扫描有结果

#### 验收标准
- ✅ 冲突自动发现率 ≥ 95%
- ✅ UNRESOLVED 冲突 100% 在简报中标注
- ✅ 元规划者层能收到 conflict ALERT

---

### P2-2: 资源预算机制 (6/25-6/30)

#### 实施步骤

1. **resource-budget-v3.json 配置文件 (6/25)**
   - 负责人: 主代理
   - 动作: 写初始配置 (3 层限额 + P0 保留)
   - 产物: `data/system/resource-budget-v3.json`
   - 验证: JSON 解析正确, 字段齐全

2. **budget-enforcer-v3.ps1 编写 (6/26)**
   - 负责人: 主代理
   - 动作: 派单前校验 + 实时追踪
   - 产物: `scripts/budget-enforcer-v3.ps1` (~3KB)
   - 验证: 模拟 budget 不足, 确认 P1 任务被降级

3. **派单方接口 (6/27)**
   - 负责人: 主代理
   - 动作: 所有派单时强制附 budget 声明
   - 产物: 派单 prompt 模板更新
   - 验证: 派一个 50K tokens 子智能体, 确认 enforcer 接受

4. **日终报告 cron (6/28)**
   - 负责人: 主代理
   - 动作: `daily-budget-report-2350.ps1` 每天 23:50 跑
   - 产物: `data/system/resource-usage-YYYY-MM-DD.md`
   - 验证: 跑 1 次, 报告格式正确

#### 验收标准
- ✅ 3 层预算限额生效
- ✅ P0 任务永远不被降级
- ✅ 日终报告自动生成
- ✅ 算力使用率 ≤ 100% (不超预算)

---

### P2-3: 自我修复 + 死信队列 (6/30-7/5)

#### 实施步骤

1. **cron-watchdog-v3.ps1 编写 (6/30 23:00)**
   - 负责人: 主代理
   - 动作: 升级 v2 cron-watchdog → v3 (进程级 + DLQ + 僵死)
   - 产物: `scripts/cron-watchdog-v3.ps1` (~8KB)
   - 验证: 模拟 1 个子智能体跑 35min, 确认被 kill

2. **dlq-v3.jsonl 落地 (7/1)**
   - 负责人: 主代理
   - 动作: 空文件创建 + 写入格式
   - 产物: `data/system/dlq-v3.jsonl`
   - 验证: 模拟 1 个失败任务, 确认 DLQ 写入

3. **dlq-processor-v3.ps1 编写 (7/2)**
   - 负责人: 主代理
   - 动作: 元规划者层心跳处理 DLQ
   - 产物: `scripts/dlq-processor-v3.ps1` (~2KB)
   - 验证: 模拟 1 个 DLQ 条目, 确认 RETRY/DROP 决策

4. **整体联调 (7/3-7/4)**
   - 负责人: 主代理
   - 动作: 同时跑 health pre-check + budget enforcer + watchdog + DLQ processor
   - 产物: 集成测试报告
   - 验证: 模拟僵死子智能体, 确认 30min 内 kill + DLQ 升级

5. **回滚预案 (7/5)**
   - 负责人: 主代理
   - 动作: 保留 v2 cron-watchdog.ps1 作 fallback
   - 产物: `_deprecated/cron-watchdog-v2.ps1`
   - 验证: 手动禁用 v3, 启用 v2, 确认基础功能不丢

#### 验收标准
- ✅ 30min 内僵死子智能体被 kill
- ✅ 失败 3 次任务自动入 DLQ
- ✅ DLQ 决策延迟 ≤ 60min
- ✅ watchdog 自身不僵死 (有 Task Scheduler 兜底)

---

## 四、关键路径与里程碑

```
6/5  06:36  G-47B v3 设计落盘 (本文件 + 主文件 + diff 文件) ✅
6/5  23:00  GFW 缓解窗口检测 (主代理)
6/5  23:30  v3 P0 Step 1 启动: health-precheck-v3.ps1
6/6  02:00  PriceRefreshCollector_0200 首次跑 (v2 P2 验证 + v3 P0 hook 验证)
6/6  04:00  AINewsCollector_0400 首次跑 (v1 部署闭环 + v3 P0 hook 验证)
6/6  06:00  v3 P0 第一次"真"验证 ⭐ 里程碑 1
6/7  12:00  v3 P0 验收报告
6/12 20:30 NFP 数据冲击 (v3 P0 已在岗, 验证防 G-46 类失败)
6/12 23:00 v3 P1 启动: cache-manager-v3.ps1
6/13-6/18  v3 P1 实施 (4 个 cron 走 cache)
6/20 23:00 v3 P1 验收 + P2 启动: 冲突检测器
6/20-6/25 v3 P2-1 实施 (冲突检测)
6/25-6/30 v3 P2-2 实施 (资源预算)
6/30 23:00 v3 P2-3 启动: cron-watchdog-v3.ps1
7/3  v3 整体联调 ⭐ 里程碑 2
7/5  v3 完整上线 (3 阶段全部完成)
7/12 NFP 月度数据 (v3 全栈在岗, 全面验证)



---

## 十一、给 G-48+ 的派单建议

- **G-48 (P0 Step 1)**: 写 health-precheck-v3.ps1, 严格按 v3 设计文件中的代码模板, 30min 内交付
- **G-49 (P1)**: 写 cache-manager-v3.ps1, 注意 TTL 配置和 cleanup 逻辑, 1.5h 交付
- **G-50 (P2-1)**: 写 conflict-detector-v3.ps1 + 多源改造, 2h 交付
- **G-51 (P2-3)**: 升级 cron-watchdog → v3, 3h 交付 (含测试)

每个子智能体只负责"写脚本", 主代理负责"集成 / 部署 / 验收"。

---

## 十二、与 G-37A 铁律的兼容性

| 铁律 | 本计划体现 |
|------|----------|
| 强制 write_file | ✅ 本文件 write_file 落盘 |
| 路径明确 | ✅ data/system/collection-v3-priorities-2026-06-05-0636.md |
| 字节数门槛 | ✅ 本文件 12KB+ (≥2KB 要求) |
| 限时 25min | ✅ 落盘时间 < 25min |
| 失败立即报错 | ✅ health pre-check / budget 超限 → 阻断, exit 1 |

---

**END OF V3 PRIORITIES**

**生成者**: G-47B 子智能体 (meta-planner 派生)  
**生成时间**: 2026-06-05 06:36 GMT+8  
**总耗时**: ~7 分钟 (06:36 - 06:43)  
**下次更新**: 6/5 23:00 v3 P0 实施启动 (G-48 派单)

