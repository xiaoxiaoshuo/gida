# G-32F: GitHub Push 策略优化 + 5 commits 兜底 (执行报告)

**生成时间**: 2026-06-04 18:10 GMT+8
**任务**: G-32F (10 min 限时, 实际用时 ~13 min 含修复)
**作者**: gida-intel subagent (session: agent:gida:subagent:a5c67d43-...)
**上一版**: `scripts\auto-push-v3-with-api-fallback.ps1` (API fallback)
**本版**: `scripts\auto-push-v4-resilient.ps1` (重试 + bundle 兜底)

---

## 0. 执行结果 (TL;DR)

| 指标 | 值 |
|---|---|
| 推送结果 | **✅ 成功** (1 attempt, 3.0s) |
| 推送 commit 数 | 1 (353e1e6, 即 5 commits 链的最新延伸) |
| GFW 探测 | WinHTTP=795ms ✅ / OpenSSL=912ms ✅ / Schannel=227ms ❌ |
| Verdict | `push-now` |
| Bundle 兜底 | `repo-2026-06-04_180812.bundle` (4.7 MB, 10 refs, **complete history**, 含 5+1 commits) |
| `.last_push_time` | 更新到 `2026-06-04 18:08` |
| `.push_journal.json` | 累积 3 条 attempt 记录 |
| 铁律遵守 | ✅ 无 force / 无 commit 删除 / bundle 包含全部 commit |

**实际推送的成功 commit**: `353e1e6 chore: G-32F 推送优化前快照 (cron 数据 + 心跳日志, 18:05)`
**GFW 抖动规律 1 句话**: 17:00–18:00 持续阻断, 18:00 后窗口逐渐打开, 18:08 出现稳定 900ms 级 OpenSSL 通道 — 推断晚 18-20 点是相对好窗口。

---

## 1. 诊断当前状态 (任务 1)

### 1.1 git log --oneline -10 (18:05 前)
```
c44f92c chore: 第32次心跳 17:58 总结 (3子智能体100%成功 + 5文件 + GFW 1/5 推送成功)
a4393fb chore: 第32次心跳 17:57 (G-32C GEO补采 + 停火协议 + 地缘权重15%→10%下调)
44f38f0 chore: 第32次心跳 17:49 (HEARTBEAT#32 完成版)
57dad59 chore: 第32次心跳 17:48 (G-32A/B完成 + v32简报 + BTC-8.2%归因 + Farside 6/3 -\.6M + 归档嵌套修复)
01ecf8d chore: G-32A 数据补采 2026-06-04 17:42
5142630 chore: 第32次心跳 17:37 (G-31A/B 跟踪 + BTC累计-8.2%归因 + archive嵌套修复)
68e98c8 chore: 定时更新 2026-06-04 17:22
262fa35 chore: 定时更新 2026-06-04 17:03
37e6100 chore: 定时更新 2026-06-04 16:52
6ffa000 chore: 定时更新 2026-06-04 16:42
```

### 1.2 关键发现
- **5 commits 链** (01ecf8d → 57dad59 → 44f38f0 → a4393fb → c44f92c) 在 18:00 前已经全部在 `origin/main` 上, 是 c44f92c 的祖先
- 18:05 工作区有 6 modified + 2 untracked (cron 数据 + heartbeat 日志) 还未提交
- 已提交一个 snapshot commit `353e1e6` (G-32F 推送优化前快照) 涵盖所有工作区变更
- 推送前状态: `HEAD = 353e1e6`, `origin/main = c44f92c`, **ahead = 1 commit**

### 1.3 GFW 18:05 探测
```
WinHTTP  (api.github.com):  FAIL (timeout)
OpenSSL  (git ls-remote):  FAIL (Connection was reset)
Schannel (curl):           FAIL (port 443 connect timeout)
```
所有栈全 down, 符合背景中 5 次连续失败 (17:12/17:22/17:32/17:48/17:51) 的模式。

---

## 2. v4 脚本设计 (任务 2)

### 2.1 文件信息
- **路径**: `C:\Users\Administrator\clawd\agents\workspace-gid\scripts\auto-push-v4-resilient.ps1`
- **大小**: 16.3 KB / 430 行
- **相对 v3 的改进**:
  - v3 走 "git push → API → 等待窗口" 三策略, **API 路径复杂且会绕过 git 历史 (data integrity 风险)**
  - v4 走 "3 次重试 (30s/60s/120s 指数退避) → bundle 落盘" 二阶段, **保留完整 git 历史**

### 2.2 核心特性

#### A. 三栈 GFW 探测 (Test-GfwStack)
- **WinHTTP** (PS `Invoke-WebRequest` → api.github.com) — 检测 443 端口 HTTPS 可达性
- **OpenSSL** (`git ls-remote`) — 检测 git 协议栈, 推送主路径
- **Schannel** (`curl.exe`) — 备选 TLS 栈
- 三个栈时延都返回, 用于决策 verdict:
  - `push-now` — OpenSSL 通, 直接推
  - `probe-only` — HTTPS 通但 git 栈瞬时阻断, 重试
  - `all-down` — 全断, 落盘 bundle

#### B. 智能重试 (指数退避)
- 默认 3 次重试, 间隔 30s → 60s → 120s (指数增长)
- 每次重试前重新探测, 避免在已知 GFW down 期间空跑
- 使用 `Start-Job` 实现 push 超时控制 (默认 60s)
- 错误分类:
  - `GH013 / Push Protection` → 立即停止, 不重试 (需修 secret)
  - `non-fast-forward / rejected` → 立即停止, 不自动 force (铁律)
  - `Connection was reset / Failed to connect` → 网络错, 重试
  - 其他 → 警告 + 重试

#### C. Bundle 兜底 (铁律: 离线可恢复)
- 3 次重试都失败后, 执行 `git bundle create repo-<timestamp>.bundle --all`
- 包含所有 refs (main, backup branches, tags, stash, origin)
- 写入 `repo-<timestamp>.bundle.log` 记录 HEAD/SHA/大小/verify 结果
- 路径可配置 (`-BundleDir`), 默认落盘 repo 根

#### D. 持久化 journal (.push_journal.json)
- 每次 attempt 都写入, 含 timestamp / outcome / commit_count / bundle_path / probe
- 保留最近 100 条, 跨 session 累计 GFW 抖动数据
- 主流程启动时读取, 输出"最近 5 次失败数"作为状态面板

#### E. 速率限制 (放宽到 5 min)
- v3 用 10 min 间隔, v4 用 5 min (兼容 cron 频率)
- 读 `.last_push_time` 文件, `< 5 min` 跳过推送但仍生成 bundle
- 成功推送时更新

#### F. 铁律防御
- `$ForcePush` 参数接收但**不使用** (收到即拒绝)
- 不调用任何 `git reset --hard` / `git push --force` / `git rebase`
- 错误分类里 `non-fast-forward` 直接 return failed, 不自动 force

### 2.3 v3 → v4 关键差异表

| 维度 | v3 (API fallback) | v4 (resilient) |
|---|---|---|
| 重试 | git push 2 次 + API 2 次 = 4 次 | git push 3 次 (30s/60s/120s) |
| 失败兜底 | 等待 9:00/14:00 cron 窗口 | **立即落盘 git bundle** (离线可恢复) |
| 推送数据完整性 | API PUT 绕过 git 历史 (新生成 commit) | 保留完整 git 历史 (与本地一致) |
| PAT 依赖 | 必须有 GITHUB_TOKEN (无则跳过) | 不依赖, 纯 git 协议 |
| 探测栈数 | 3 栈 (WinHTTP/OpenSSL/Schannel) | 3 栈 + 时延量化 |
| 持久化 | 仅 `.last_push_time` | `.last_push_time` + `.push_journal.json` + `.bundle.log` |
| 错误分类 | 2 类 (push protection / 其他) | 3 类 (push protection / non-FF / 网络) |
| 超时控制 | 无 (git push 跑满) | `Start-Job` + `Wait-Job` 60s 超时 |

### 2.4 调用示例
```powershell
# 默认 3 次重试 (30s/60s/120s)
.\scripts\auto-push-v4-resilient.ps1

# 快速验证 (5s/10s/15s, 用于调试)
.\scripts\auto-push-v4-resilient.ps1 -RetryDelays @(5, 10, 15)

# Dry-run (不实际推送, 只跑探测 + 模拟)
.\scripts\auto-push-v4-resilient.ps1 -DryRun

# 自定义 bundle 目录
.\scripts\auto-push-v4-resilient.ps1 -BundleDir "D:\backup\bundles"
```

---

## 3. 1 轮推送执行 (任务 3)

### 3.1 第 1 次执行 (dryrun-验证, 18:07:49)
- 探测: WinHTTP=541ms ✅ / OpenSSL=930ms ✅ / Schannel=273ms ❌ → **push-now**
- Dry-run 成功退出 (verdict = push-now 表明 GFW 实际已开, 可以真实推送)

### 3.2 第 2 次执行 (real, 18:08:36) — ✅ 成功
- **探