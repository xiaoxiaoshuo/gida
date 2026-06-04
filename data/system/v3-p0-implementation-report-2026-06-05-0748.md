# v3 P0 实施报告 — API 健康预检层 (health-precheck-v3.ps1)

**实施时间**: 2026-06-05 07:48 GMT+8  
**实施方**: gida 元规划者 (主代理)  
**设计依据**: G-47B v3 设计文档 (2026-06-05 06:36)  
**状态**: ✅ 脚本已落盘,待首次运行验证  

---

## 一、产出文件

| 路径 | 字节数 | 说明 |
|------|-------|------|
| `scripts/health-precheck-v3.ps1` | ~5.5KB | API 健康预检 v3 核心脚本 |
| `data/system/health-precheck-v3-state.json` | (运行时生成) | 每次扫描的状态持久化 |

## 二、核心能力

### 1. 6 个 API 端点覆盖
- **加密货币 (critical)**: OKX BTC / Binance BTC / CryptoCompare BTC
- **情绪 (non-critical)**: alternative.me F&G
- **AI (non-critical)**: HN top stories

### 2. 健康判定四要素
- HTTP 200 ✅
- JSON 解析成功 ✅
- 数据非空 ✅
- 延迟 ≤ SLA ✅

### 3. 3 档评分阈值
| 分数 | 动作 | 退出码 |
|------|------|-------|
| ≥ 70% | proceed (正常) | 0 |
| 50-70% | degrade_offline_buffer (降级) | 1 |
| < 50% 或 critical 失败 | block_alert (阻断 + 告警) | 2 |

### 4. 状态持久化
- 每次扫描结果写入 `data/system/health-precheck-v3-state.json`
- 派单方可读取做趋势分析 (成功率 24h/7d)

## 三、待办 (G-48 回报后)

1. ⏳ **首次运行验证** (G-48 回报后): `pwsh scripts/health-precheck-v3.ps1 -Verbose`
2. ⏳ **集成到 collect-prices-simple.ps1**: 启动前 5s 调用 precheck
3. ⏳ **集成到 cron-ainews-0400.ps1**: 启动前 5s 调用 precheck
4. ⏳ **降级 buffer 设计 (P1)**: offline-buffer-v3.jsonl + cache-manager-v3.ps1
5. ⏳ **数据冲突检测器 (P2)**: conflict-detector-v3.ps1 + data-conflicts.jsonl
6. ⏳ **资源预算 (P2)**: resource-budget-v3.json
7. ⏳ **自我修复 + 死信队列 (P2)**: cron-watchdog-v3.ps1 + dlq-v3.jsonl

## 四、与 v2 差异

| 维度 | v2 | v3 P0 |
|------|----|----|
| API 状态感知 | ❌ 无 | ✅ 6 端点扫描 |
| 失败传染防护 | ❌ 子智能体静默失败 | ✅ critical fail 阻断 |
| 状态持久化 | ❌ 仅 .push_journal | ✅ health-precheck-v3-state.json |
| 跨 cron 协调 | ❌ 各自为战 | ✅ 统一预检入口 |

---

*派单方: gida meta-planner | 第 44 次心跳 | v3 P0 实施 (API 健康预检层)*
