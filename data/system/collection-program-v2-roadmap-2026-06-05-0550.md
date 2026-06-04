# 采集程序 v2 优化路线图 (G-45)

**规划时间**: 2026-06-05 05:55 +08:00
**规划者**: G-45 子智能体 (meta-planner 派生)
**依据**: G-40B v1 部署报告 + G-45 v1 健康度自检 (7.6/10)
**目标**: 把 v1 的"脚本层 OK, 调度层有漏"提升为 v2 的"全链路零漏检"

---

## 一、v1 → v2 关键差距

| 维度 | v1 (G-40B) | v2 (G-45) | 差距 |
|------|-----------|-----------|------|
| 脚本存在 | ✅ 100% | ✅ 100% | 已平 |
| 语法检查 | ✅ 100% | ✅ 100% | 已平 |
| API 可达 | ✅ 100% | ✅ 100% | 已平 |
| **任务注册** | ⚠️ 50% (漏 1/3) | **✅ 100%** | **核心补** |
| 首次运行验证 | ❌ 0% | **✅ 100%** | **核心补** |
| 数据完整性 | ⚠️ 6/5 真空未填 | ✅ 6/6 起自动 | 已知 |
| 故障重试 | ❌ 0% | ⚠️ 50% (L3 归档+人工) | 待补 |
| **总评** | **7.6/10** | **目标 9.5/10** | +1.9 |

---

## 二、4 个新优化点 (P0/P1/P1/P2)

### P0 (CRITICAL): 部署+注册双重验证机制

**问题**: G-40B 5:20 落盘 cron-ainews-0400.ps1, 5:27 写完实施报告, 5:50 主代理发现**未注册到 Windows Task Scheduler**。30 分钟窗口内 cron 没跑。

**v2 解决方案**: 任何 cron 脚本部署必须通过 **4 步强制流水线**, 缺一不算"完成":

```powershell
# scripts/_deploy/deploy-cron-v2.ps1 (待写)
function Deploy-CronV2 {
    param(
        [string]$ScriptPath,
        [string]$TaskName,
        [string]$Cron,
        [string]$Description
    )

    # Step A: 文件落盘
    if (-not (Test-Path $ScriptPath)) { throw "FAIL-A: file not found" }
    $size = (Get-Item $ScriptPath).Length
    Write-Host "[A] ✅ File: $ScriptPath ($size bytes)"

    # Step B: 语法检查
    $errs = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $ScriptPath, [ref]$null, [ref]$errs) | Out-Null
    if ($errs.Count -gt 0) { throw "FAIL-B: syntax errors: $errs" }
    Write-Host "[B] ✅ Syntax: 0 errors"

    # Step C: 任务注册 (幂等)
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "[C] ⚠️  Task exists, updating trigger"
        Set-ScheduledTask ...
    } else {
        Write-Host "[C] ✅ Registering new task"
        Register-ScheduledTask -TaskName $TaskName ...
    }

    # Step D: 首次运行验证 (立即跑一次 + 检查输出文件)
    & pwsh -File $ScriptPath -DryRun   # 干跑, 不写数据
    $testFile = "$ScriptPath.test.ok"
    if (Test-Path $testFile) {
        Remove-Item $testFile
        Write-Host "[D] ✅ First run OK"
    } else {
        throw "FAIL-D: first run did not produce $testFile"
    }

    Write-Host "✅ DEPLOY-V2 COMPLETE: $TaskName"
}
```

**验收标准**:
- 任何新 cron 部署前, 必须先跑 `Deploy-CronV2 -ScriptPath ... -TaskName ... -Cron ...`
- 失败抛异常, 不允许"静默成功"
- 实施时间: 6/5 23:00 (GFW 缓解窗口) 开始写 deploy 框架, 6/6 02:00 前完成

---

### P1: ETH 三源冗余 (Binance 备选)

**问题**: 当前 ETH 价格依赖:
- CryptoCompare API (主)
- OKX public API (备 1)
- Gate.io public API (备 2)

如果 GFW 突发阻断 CryptoCompare + OKX, 6/2 23:10 collect-prices-simple.ps1 25.8KB 已有 `_fix-eth-v2/v3` 补丁历史, 说明 ETH 断链是已知反复问题。

**v2 解决方案**: 增加 **Binance public API** 作为第 4 源:
```
GET https://api.binance.com/api/v3/ticker/price?symbol=ETHUSDT
→ {"symbol":"ETHUSDT","price":"2456.78"}
```

**实施步骤**:
1. 在 `collect-prices-simple.ps1` 增加 L4 layer (L1=CryptoCompare, L2=OKX, L3=Gate.io, L4=Binance)
2. 每个 L 失败 → 立即 fallback 到下一个, 间隔 <2s
3. 4 源全失败 → 写 `data/system/prices-errors.jsonl` (类似 gh-trending 模式)

**预期收益**: ETH 可用率从 90% (3 源) 提升到 99% (4 源)

**实施时间**: 6/5 23:30 - 6/6 01:00 (2h)

---

### P1: ETF JS 渲染升级 (Playwright .NET)

**问题**: ETF 数据 (BTC/ETH 现货 ETF 资金流) 当前依赖 Farside 静态 HTML (etf-monitor.ps1, 6/3 03:14, 2.7KB):
```
Farside Investors: https://farside.co.uk/etf-flows/
→ 静态 HTML, 简单抓取 OK, 但 6/2 之后多次 Farside 服务器慢/挂
```

**v2 方案**: 增加 **Coinglass ETF 深度数据** 源 (含机构持仓/单日净流入):
```
Coinglass: https://www.coinglass.com/BitcoinETF
→ JS 渲染 (React), web_fetch 拿到空壳
→ 必须用 Playwright .NET (Microsoft.Playwright) 跑 headless Chromium
```

**实施步骤**:
1. 确认 Playwright .NET 5.x 已装 (`dotnet add package Microsoft.Playwright`)
2. 写 `scripts/etf-coinglass-v2.ps1` (调用 C# DLL)
3. 输出 `data/market/etf-coinglass-YYYY-MM-DD.json` (含 Grayscale/BlackRock/Fidelity 拆分)
4. 与 Farside 数据做 diff, 差异 >10% 时报警

**预期收益**: ETF 数据从"1 源 + 偶发挂"升级到"2 源 + 交叉验证"

**风险**: Playwright 首次下载 chromium ~150MB, 需预留磁盘

**实施时间**: 6/6 09:00 - 12:00 (避开 NFP 8:30 数据冲击, 3h)

---

### P2: 价格 cron 02:00 填补任务

**问题**: `data/prices/` 最新文件 5/6 13:06, **一个月前**。HourlyPriceCollector 任务在 Task Scheduler 里 Ready, 但实际未产出 6 月文件 (可能 5 月底后无人触发 / 路径变了)。

**v2 方案**:
1. 写 `scripts/price-refresh-0200.ps1` (凌晨 2 点单次跑)
2. 注册 `PriceRefreshCollector_0200` 任务
3. 同时排查 HourlyPriceCollector 为何不产出 (路径/权限/script 错误)

**实施步骤**:
1. 立即: `Get-Content data/prices/2026-05-06-13.json` 看格式, 复制 v2 脚本结构
2. 6/5 06:00: 等 HourlyPriceCollector 跑完, 看 6 月首文件是否产出
3. 6/5 23:00: 写 price-refresh-0200.ps1, 注册任务
4. 6/6 02:00: 首次自动验证

**预期收益**: 价格数据密度从"月级"恢复到"小时级"

**实施时间**: 6/5 23:00 - 6/6 01:00 (2h)

---

## 三、v2 实施时间表

| 时间 | 任务 | 责任人 | 验证方式 |
|------|------|--------|----------|
| **6/5 05:55-06:00** | G-45 落盘 3 个交付物 (本文件) | G-45 ✅ | 文件存在 |
| 6/5 06:00 | HourlyPriceCollector 自动跑 (观察是否产出) | cron | data/prices/ 出现 06-05-06.json |
| 6/5 08:30 | NFP 数据冲击, 暂停新部署 | — | — |
| 6/5 14:00 | NFP 余波消化, 准备 P0 框架 | 主代理 | — |
| **6/5 23:00** | **P0 框架开发启动** (deploy-cron-v2.ps1) | 主代理 + G-46 | 4 步流水线通过单测 |
| 6/6 00:00 | P1 ETH 4 源 + P2 price-refresh-0200 并行 | G-47 | 脚本就绪 + 任务注册 |
| 6/6 02:00 | price-refresh-0200 首次自动跑 | cron | data/prices/06-06-02.json 存在 |
| 6/6 04:00 | **AINewsCollector_0400 首次自动跑** (v1 验证里程碑) | cron | data/ai/ai-news-06-06-04.json 存在 |
| **6/6 06:00** | **v2 首次自动验证** (P0+P1+P2 三件套) | cron | 凌晨 4h 真空填补 + ETH 4 源 + 价格 2 点更新 |
| 6/6 09:00 | P1 ETF Coinglass 启动 | 主代理 + G-48 | Playwright 截图首跑 |

**关键里程碑**: **6/6 06:00** — 这是 v1 部署缺陷 (0400 未注册) 完全闭环 + v2 三件套首次自动验证的时刻。

---

## 四、v2 不做的事 (Out of Scope)

明确不在 v2 范围, 避免 scope creep:
- ❌ 不改 AINewsCollector_6h (它跑得好, 0 missed runs)
- ❌ 不改 gh-trending-v6-3layer-fallback (刚部署, 需 1 周观察期)
- ❌ 不重写 collect-prices-simple (太大, 风险高, 走补丁路线)
- ❌ 不引入新数据库 (JSON 文件 + JSONL 日志够用)
- ❌ 不做 GUI / Web 面板 (单用户本地系统, CLI 即可)

---

## 五、v2 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| deploy-cron-v2 自身 bug 导致注册失败 | 中 | 高 | 保留 v1 手动注册命令作 fallback |
| Playwright 下载 chromium 失败 | 中 | 中 | 跳过, Farside 静态源够用 |
| 6/5 23:00 仍在 GFW 封锁期 | 低 | 中 | 推迟到 6/6 03:00, 接受 1 天延迟 |
| ETH 4 源全部被 GFW 屏蔽 | 极低 | 高 | 走 Cloudflare 1.1.1.1 DNS 备选 |

---

**END OF V2 ROADMAP**
**总耗时**: ~5 分钟 (5:55-6:00)
**联动文件**: data/system/collection-program-v1-health-check-2026-06-05-0550.md
