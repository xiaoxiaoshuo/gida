# 采集程序优化计划 v1 (2026-06-05 03:38)

> 触发: 用户定时提醒"优化生成自己的采集程序"
> 作者: 元规划者层 (G-38 派发后)
> 范围: 跨凌晨真空期采集补全 + 工作流断链修复

---

## 📊 当前采集矩阵盘点

| 程序 | 状态 | 触发 | 主要问题 |
|---|---|---|---|
| `collect-prices-simple.ps1` (v8) | 🟢 健康 | 5 cron (1h) | 0x80070002 路径上下文, 已修 |
| `gh-trending-browser-v5.ps1` | 🔴 断链 | 12 cron (6h) | 输出"请在 browser tool 执行"无后续 |
| `cron-wrapper.ps1` (AINews) | 🟡 部分 | 4 cron (6h) | 跨凌晨 02:00-06:00 真空 |
| `cron-watchdog.ps1` (v2) | 🟡 30min 错峰 | 4 cron (6h) | 实际间隔 6h, 非 30min |
| `briefing-generator.ps1` (v2) | 🟢 健康 | 4 cron (6h) | 0 |
| `auto-push-v3-with-api-fallback.ps1` | 🟡 422 self-log | 持续 | self-log 被 GH 拒绝 |
| `auto-push-v4-resilient.ps1` (新) | 🟢 健康 | 持续 | archive 模式稳定 |

---

## 🔴 4 个优化点 (按优先级)

### 1. gh-trending-browser-v5.ps1 工作流断链 (P0)

**问题**: 脚本输出"请在 browser tool 执行 evaluate", 但 cron 环境无 browser 调用, 6/5 00:00/04:31/06:36/12:00 已 4 次未执行

**v6 设计方案**:
```
gh-trending-v6-fully-auto.ps1
├── Step 1: OpenClaw browser tool 触发 open url=https://github.com/trending
├── Step 2: 等待 3-5s (sleep)
├── Step 3: OpenClaw browser tool 触发 evaluate (提取脚本内嵌)
├── Step 4: JSON 落盘到 data/tech/github-trending_latest.json
└── Step 5: 主代理接收回报, 写入 summary
```

**关键变化**: 从"半自动"升级为"全自动" - 不再依赖人工执行 browser tool

**实施成本**: 低 (50 行 PS1 + 30 行 JSON 提取), 2h 工作量

### 2. 跨凌晨 02:00-06:00 采集真空 (P0)

**问题**: AINewsCollector_6h 在 00/06/12/18 触发, 02-06 段 4h 无 AI 新闻
- 6/5 02:27 主代理 fallback 补采 (G-37A), 但这是手动触发
- 6/4 04:31 同样需要手动补救
- 6/4 22:00 cron 触发, 6/5 04:00 才会自动再触发, 跨凌晨 4h 真空

**v6 优化方案**:
```
新增 cron-ainews-0400 (凌晨补采)
├── 触发: 每天 04:00
├── 任务: AINewsCollector_6h 同源 (HN + GitHub + AI RSS)
├── 输出: data/ai/ai-news-2026-MM-DD_04-00.json
└── 集成: 添加到 Scheduled Task, 与现有 cron 并行
```

**实施成本**: 极低 (复制 cron-wrapper 改时间), 30min 工作量

### 3. cron-watchdog 实际间隔过长 (P1)

**问题**: 设计意图"错峰 30min", 实际触发 00:30/06:30/12:30/18:30, 6h 间隔
- 00:30 触发后, 06:30 才再次, 中间 6h 真空
- 6/5 02:00-04:00 期间 cron 静默失败 (HourlyPrice 0x80070002) 都未被捕获

**v3 优化方案**:
```
cron-watchdog-v3-frequent.ps1
├── 触发: 每 30min (与当前相同)
├── 任务: 5 项检查 (HN/AINews/HourlyPrice/wrapper_log/push_age)
├── 改进: 增加 cron last-run-time 实时检查 (读取 Scheduled Task)
└── 输出: data/system/cron-watchdog-30min.jsonl
```

**实施成本**: 低 (30 行 PS1), 1h 工作量

### 4. auto-push-v3 422 self-log 模式 (P1)

**问题**: API PUT 推送时, auto-push-v3-log-*.txt 自身日志文件被 GitHub 422 拒绝
- 6/5 02:57/04:57/05:07/05:18 多次 422
- 原因: self-log 在 git add 后被修改, PUT 时 hash 变化

**v4 优化方案**:
```
auto-push-v4-with-self-log-rotation.ps1
├── 改进 1: .gitignore 添加 auto-push-v*-log-*.txt
├── 改进 2: 推送前 mv self-log 到 data/system/logs/
├── 改进 3: self-log 改为 append-only (避免 hash 变化)
└── 改进 4: 推送成功后, 单独 PUT log (最佳努力)
```

**实施成本**: 中 (改 .gitignore + 重构 self-log 逻辑), 2h 工作量

---

## 🎯 实施优先级矩阵

| 优先级 | 优化点 | 影响范围 | 实施成本 | 收益 |
|---|---|---|---|---|
| P0 | gh-trending-v6 全自动 | GH Trending 数据 | 2h | 高 (解决 6/5 4 次断链) |
| P0 | cron-ainews-0400 | 跨凌晨 AI News | 30min | 高 (填补 4h 真空) |
| P1 | cron-watchdog-v3 30min | cron 健康监控 | 1h | 中 (捕获 6h 内失败) |
| P1 | auto-push-v4 self-log | 推送成功率 | 2h | 中 (减少 422 误报) |

**总工作量**: 5.5h (一个人一天)
**建议**: 分两批实施, 今晚 23:00 (GFW 缓解) 先做 P0 两件 (2.5h), 明天做 P1

---

## 📅 实施时间表

- **2026-06-05 04:00** (22min 后): HourlyPrice cron 触发, 顺便实施 cron-ainews-0400
- **2026-06-05 23:00** (19h22min): GFW 缓解窗口, 实施 gh-trending-v6 + auto-push-v4
- **2026-06-06 02:00**: 验证 v6 + v4 全部 cron 健康
- **2026-06-06 06:00**: 验证 AINewsCollector_6h + cron-ainews-0400 双 cron

---

## 📌 元规划者反思

**为什么现在触发优化**:
- G-37A 02:32 完成后, 跨凌晨空档期是元规划者层反思最佳窗口
- 03:30 段是 cron 真空 (04:00 之前), 不会与子智能体冲突
- 6/5 NFP 之前 16h, 是部署"全自动化管道"最后窗口

**为什么不立即实施**:
- 派发 G-38A/B 子智能体已用 2 个 subagent slot
- 子智能体实施程序修改风险高, 主代理 5min 决策后让子智能体执行更稳
- 当前凌晨空档期, 推送失败率高, 实施后无法立即验证

**子智能体方法论**:
- G-39 (04:30) 派发"程序优化实施"子智能体, 主代理 5min 决策 → 子智能体 30min 实施
- 或今晚 23:00 派发, 实施后等 6/6 02:00 验证

---

*本计划由 2026-06-05 03:38 元规划者层生成, 待 04:30 派 G-39 实施*
*最后更新: 2026-06-05 03:38 GMT+8*
