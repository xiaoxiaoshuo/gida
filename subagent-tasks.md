# 子智能体任务：深度执行与修复

## 任务ID: deep-exec-20260326-0419
## 时间: 2026-03-26 04:19 GMT+8

---

## 任务1：修复黄金/原油价格采集BUG（最高优先级）

### 问题根因
- 症状：Bing搜索"黄金价格 今日 USD"和"WTI原油价格 今日 USD"结果摘要不包含价格
- 结果：正则提取到错误数字（如"20"——来自页面元素ID）
- 证据：raw_search_all文件中没有真正的价格数字

### 修复方案（三选一或多选）

#### 方案A：更换数据源
- 尝试 Metals-API (metals-api.com) - 有免费tier
- 或 try: `https://api.metals.live/v1/spot` (免费，无需认证)
- 或: 使用OKX的合约数据（BTC季度合约中有指数价格）

#### 方案B：改进搜索策略
- Bing搜索改用：`site:xm.com 黄金价格` 或 `site:forex.com 黄金 USD`
- 尝试更有针对性的查询，确保搜索结果摘要含价格

#### 方案C：标记为不可用
- 在 `collect-prices-simple.ps1` 的 GOLD/OIL 采集函数中添加合理性检查
- 如果价格 < 100（黄金）或 < 20（原油），标记为失败或标注"(数据不可靠)"
- 这样至少不会产生误导性数据

### 执行步骤
1. 读取 `scripts/collect-prices-simple.ps1` 中的 `Get-MacroPrice` 函数
2. 实现方案C（最低成本，立即有效）
3. 如果可以，尝试方案A
4. 更新脚本版本为 v6b
5. 测试运行脚本，验证结果

---

## 任务2：获取真实黄金/原油价格（验证）

使用web_fetch获取真实数据：
- 黄金：尝试 `https://api.metals.live/v1/spot` 或 cn.bing.com搜索更精确的查询
- WTI原油：尝试 `https://api.metals.live/v1/spot/wti` 或搜索 "WTI crude oil price today USD"

将真实值记录到 memory/2026-03-26.md

---

## 任务3：GitHub推送重试

等待GitHub 502问题窗口期后，尝试推送：
```
cd C:\Users\Administrator\clawd\agents\workspace-gid
git push
```
如果成功，记录到输出。
如果失败，记录但不阻塞。

---

## 任务4：更新每日简报

检查 `DAILY/briefings.md` 或 `DAILY/2026-03-26.md`：
- 是否包含最近4小时的加密货币价格？
- 是否有新的重要情报？
- 更新简报，加入：
  - 当前BTC/ETH/SOL价格
  - Fear&Greed Index = 14（极度恐慌）
  - 市场情绪分析

---

## 约束
- 工作目录：C:\Users\Administrator\clawd\agents\workspace-gid
- 网络：注意GWF问题，使用cn.bing.com搜索
- 不要删除任何文件
- 推送失败记录但不等待
