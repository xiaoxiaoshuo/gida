# LLM 前沿动态追踪 — 2026-06-02

> **报告类型**: 跨厂商 OpenAI / Anthropic / DeepSeek / Qwen / Kimi 周度对比
> **编制时间**: 2026-06-02 20:25 GMT+8
> **数据截止**: 2026-06-02 12:30 UTC
> **信源数**: 12+ 独立来源 (官方页面 × 5、CNBC、TechCrunch、CBS、Sky News、MSN、SEC EDGAR、Qbitai、GitHub orgs)
> **置信度**: 核心事实 A 级, 推断 B-C 级
> **执行人**: 元规划者 gida 子智能体 (LLM前沿追踪)

---

## 🎯 BLUF (Bottom Line Up Front)

1. **6/1 三大美国 AI 资本事件 = "AI 公开市场首日"** — Anthropic 保密 S-1 (估值 $965B) + OpenAI frontier models 登陆 AWS (5 月底合作落地) + Alphabet $80B 股权融资 (6/1 收盘) — 公开市场 6 小时内接收万亿定价信号
2. **OpenAI 内部节奏被监管打断**: 6/1 同日 Anthropic S-1 抢跑 + 佛罗里达州 AG James Uthmeier 起诉 OpenAI/Altman (暴力事件首例州级诉讼), Sam Altman 7 月 IPO 计划承压
3. **中国厂商分化**: DeepSeek V4 已是"市场在用"产品 (chat.deepseek.com 搭载, 1M 上下文) / Qwen 3.7 Max Preview 5/19 抢发闭源预览 (战略转向) / Kimi K2.6 持续迭代 (Claw Groups 群组多 Agent 内测); **与美西差距 6-12 个月且扩大中**

---

## 1. OpenAI 最新动态 (按重要性)

### 🔴 P0: 6/1 佛罗里达州诉讼 (官方未公开回应)
- **诉讼方**: 佛罗里达州总检察长 **James Uthmeier** (新任, 2025-01 接管 Ashley Moody)
- **诉讼对象**: OpenAI + Sam Altman (个人) + 多个未具名董事
- **诉讼内容**: 暴力事件相关首例州级 AI 安全诉讼 (具体案由未在可信信源中明确, Bing CN 搜索被本地法过滤)
- **OpenAI 应对**: 截至 2026-06-02 12:30 UTC, openai.com/news 页面**无任何官方声明** (最新产品公告 6/1, 安全/治理公告 5/28-5/29, 均不涉及 Florida 诉讼)
- **判断**: 极不寻常 — 通常被诉公司 24h 内至少发布简短声明, 沉默可能意味 1) 准备 2) 法律建议"不要公开评论" 3) 等待 SEC 静默期 (与 9 月 IPO 传闻有关)
- **信源**: 主智能体上下文 (6/2 19:30 GMT+8 报告已确认), 佛罗里达州官方 URL `fllegaldocs.com` 404, Bing CN 过滤
- **置信度**: B+ (事件存在但细节不完整)

### 🔴 P0: 6/1 frontier models + Codex 登陆 AWS (官方公告)
- **标题**: "OpenAI frontier models and Codex are now available on AWS"
- **日期**: 2026-06-01 (Product 类)
- **URL**: https://openai.com/index/openai-frontier-models-and-codex-are-now-available-on-aws/
- **意义**: **OpenAI 首次与 Microsoft Azure 之外的顶级超大规模云 (AWS) 深度整合** — 标志 OpenAI 多云战略落地, 直接回应 Anthropic "三云中立" 优势
- **置信度**: A (官方页面)

### 🟠 P1: 5/28-5/29 安全/治理矩阵
- **5/28**: "OpenAI's Frontier Governance Framework" (Safety) — 模型自主治理 + 红队协议 + 内部安全等级
- **5/29**: "Strengthening societal resilience with Rosalind Biodefense" (Product) — 生物防御合作
- **5/29**: "A shared playbook for trustworthy third party evaluations" (Safety)
- **URL 模板**: https://openai.com/index/<slug>/
- **判断**: **3 个连续安全公告 = OpenAI 主动设防"AI 安全监管"叙事** — 6/1 Florida 诉讼背景下明显
- **置信度**: A

### 🟠 P1: 5/27 Codex 自改进 Tax Agent
- **标题**: "Building self-improving tax agents with Codex"
- **意义**: Codex Agent 在企业垂直领域落地 (税务), 与 Anthropic Claude Code + Mythos 路线针锋相对
- **置信度**: A

### 🟢 P2: 5/22 Gartner 企业编码 Agent 领导者
- **标题**: "OpenAI named a Leader in enterprise coding agents by Gartner"
- **意义**: 第三方机构背书, 削弱 Anthropic "企业首选" 叙事
- **置信度**: A

### 🟢 P2: 5/20 数学突破 (纯研究)
- **标题**: "An OpenAI model has disproved a central conjecture in discrete geometry" (Research)
- **意义**: 基础研究信用, 为 IPO 故事增加"AGI 路径" 证据
- **置信度**: A

### 🟢 P2: 5/18 Dell Technologies 合作
- **标题**: "OpenAI and Dell Technologies partner to bring Codex to hybrid and on-premises enterprise environments"
- **意义**: 与 5/18 之前 Dell 的 Anthropic 合作形成"客户重叠竞争"
- **置信度**: A

### ❓ 待验证 (无法在 CN 环境查证)
- **GPT-5.1 / GPT-5.5 发布计划**: 公开信源未确认, 官方 changelog/platform.openai.com 被 Cloudflare 拦截
- **Operator 产品更新**: 5/20 之后无重大公告
- **Sora 2 后续**: 2025-10 之后无重要更新
- **9 月 IPO 递交传闻**: 主智能体上下文标记为"传闻", 主源 CNBC 5/20 文章, 需 SEC EDGAR 持续监控
- **OpenAI 9 月 IPO 传闻信源**: https://www.cnbc.com/2026/05/20/openai-ipo-filing.html (OpenAI readying its own confidential filing)
- **置信度**: C

---

## 2. Anthropic 最新动态

### 🔴 P0: 6/1 保密 S-1 提交 SEC (官方公告)
- **标题**: "Anthropic confidentially submits draft S-1 to the SEC"
- **日期**: 2026-06-01
- **URL**: https://www.anthropic.com/news/confidential-draft-s1-sec
- **官方原文** (关键句):
  > "Today, Anthropic, PBC confidentially submitted a draft registration statement on Form S-1 to the U.S. Securities and Exchange Commission for a proposed initial public offering of our common stock. **This gives us the option to go public after the SEC completes its review.** The proposed initial public offering will depend on market conditions and other factors."
- **法律框架**: Rule 135 (Securities Act of 1933) — **不构成要约/要约邀请, 仅事实陈述**
- **EDGAR 可见性**: 保密 S-1 不会出现在 EDGAR 公开搜索 (JOBS Act 路径) — 我在 efts.sec.gov 搜索确认 0 结果
- **置信度**: A (官方页面 + 5 家独立媒体确认)

### 🔴 P0: 关键财务数据 (多源验证)
| 指标 | 数值 | 信源 |
|---|---|---|
| 估值 | **$965B** (post-money, Series H 5/28) | Anthropic 官方 + TechCrunch + CNBC + CBS |
| Series H 募资 | $65B | 官方 |
| Series H 领投 | Altimeter, Dragoneer, Greenoaks, Sequoia | 官方 |
| **ARR run-rate** | **$47B** (vs 2025 末 $9-10B) | CNBC 引述官方 + CBS |
| 5 个月增速 | +370-422% | 推算 |
| 估值/ARR 比率 | 20.5× | 推算 |
| 同期 OpenAI 估值 | $852B (3 月) | TechCrunch |
| 净亏损 | 未披露 (保密) | - |
- **核心判断**: **Anthropic 估值首次反超 OpenAI $113B** (+13%)
- **置信度**: A (估值/募资), A (ARR), C (亏损/现金流)

### 🟠 P1: 4/7 Mythos Preview + Project Glasswing
- **标题**: "Claude Mythos Preview" (4/7)
- **意义**: 高级网络安全模型, 已接入 ENISA (欧盟网络与信息安全局) (Bloomberg 6/1 报道)
- **战略合作**: 与 Trump 政府高层对话 (CNBC 4/17)
- **风险**: **3/9 Pentagon 拉黑, 5/1 正式列入"国家安全供应链风险", 取消 $200M+ 联邦合同**
- **现状**: 国防承包商停用, 私营部门加速, 消费市场 Claude 2/28 升至 #1
- **URL**: https://www.cnbc.com/2026/04/07/anthropic-claude-mythos-ai-hackers-cyberattacks.html
- **置信度**: A (多源)

### 🟠 P1: Claude Opus 4.8 (5/28 与 Series H 同步)
- **类别**: 升级 Opus 系列, 加强 coding/agentic/专业工作
- **URL**: https://www.anthropic.com/news/claude-opus-4-8
- **置信度**: A

### 🟠 P1: 米兰办公室开幕 (欧洲第 6 办公室)
- **意义**: 欧洲合规布局, 应对 EU AI Act
- **URL**: https://www.anthropic.com/news/milan-office-opening
- **置信度**: A

### 🟢 P2: financial-services 仓库
- **状态**: 29.4K ⭐, 4.1K 🍴, last push 2026-05-29 (与 Series H 同步)
- **内容**: 10 个企业级 Agent + 8 个 MCP 数据连接器 (Daloopa/Morningstar/S&P/FactSet/Moody's/MT Newswires/LSEG/S&P Capital IQ)
- **意义**: Anthropic 金融行业渗透率第一的硬证据
- **置信度**: A (GitHub)

### ❓ 待验证
- **Claude 4.5 / 5.0 路线图**: 官方未公开, 业内传闻 Claude 5.0 2026 Q4
- **Mythos 正式版**: 4 月仅 preview, 5-6 月无 GA 公告

---

## 3. DeepSeek 最新动态

### 🟠 P1: DeepSeek V4 (5/6 发布后约 1 个月)
- **状态**: 已在 chat.deepseek.com 上线, 同时提供 R1 推理模型 + V4
- **关键能力** (官方宣传):
  - 1M token 超长上下文
  - 强化 Agent 能力
  - R1 深度推理
  - 多模态处理
  - 文件上传
- **市场覆盖**: Windows 官方应用商店上线, 第三方镜像 (deepseeqk.com, deepseek.aigc.cn 等) 同步推出
- **信源**: 官方应用商店描述 + 多家第三方综述
- **置信度**: A (市场在用, 1 月历史锚定)

### 🟠 P1: 开源生态
- **GitHub deepseek-ai org** (https://github.com/deepseek-ai):
  - **DeepGEMM**: FP8 GEMM kernels (开源基础设施)
  - **DeepEP**: Expert-Parallel 通信库
  - **3FS**: 分布式文件系统 (AI 训练/推理)
  - **FlashMLA**: Multi-head Latent Attention Kernels
  - **DualPipe**: 双向 Pipeline 并行 (V3/R1 训练用, **Updated Jan 14, 2026**, 2,958 ⭐)
- **关键观察**: **2026 H1 GitHub 提交活跃度仍高** (DualPipe Jan 更新 = V3 持续优化, **V4 训练很可能复用 DualPipe**)
- **开源策略**: 持续开源基础架构 (训练/推理 kernel), 但旗舰模型 V4 走闭源 API
- **置信度**: A (GitHub)

### 🟢 P2: 5/15 商业化进展
- 5/15 多家第三方综述提及 "DeepSeek-V4 强化 Agent 能力与 R1 深度推理"
- 5/26 第三方页面 (ai.deepseekem.com) 提及 DeepSeek 2023 创立, 2026 已成全球低成本 LLM 标杆
- **历史成绩**: $6M 训练成本, $0.001/query (20× 低于 GPT-4)
- **置信度**: B (综述来源, 需主源验证)

### ❓ 待验证
- **V4.1 / V5 路线图**: 官方未公布, V4 刚 1 个月, 推测 V4.1 2-3 月内
- **V4 论文/技术报告**: 尚未在 Hugging Face 或 GitHub 发布 (对比 V3 是开源权重)
- **估值/融资**: DeepSeek (High-Flyer 旗下) 2025 末传闻 $50-100B 估值, 2026 状态待验证

---

## 4. Qwen (Alibaba) 最新动态

### 🟠 P1: Qwen 3.7 Max Preview (5/19 发布)
- **来源**: 量子位 (Qbitai) 5/19 报道
- **标题**: "Qwen最新3.7 Max预览版空降!两代超大杯并行迭代"
- **URL**: https://www.qbitai.com/2026/05/419822.html
- **关键事实**:
  - 阿里 Qwen 团队**已进入快速实验、高频交付阶段**
  - **两代超大杯并行迭代** = 3.6 Max-Preview + 3.7 Max-Preview 同步
  - 前负责人**林俊旸**已离职 (推特公开: "Qwen 的兄弟们, 按原来安排继续干, 没问题")
  - 团队无重大震荡
- **置信度**: A (Qbitai 是头部科技媒体)

### 🟠 P1: Qwen 3.6 Max-Preview 战略转向
- **关键事件**: **3.6 转向闭源** (5 月期间)
- **来源**: 知乎 "如何评价 qwen 3.6 转向闭源?" 讨论 (URL: https://www.zhihu.com/question/2022382258535809067)
- **核心策略**:
  - 受 **Minimax + Mimo 启发** (第三方闭源抢占榜单)
  - 预览版**闭源独占**
  - 与 Kilo Code 合作刷 OpenRouter 榜单
  - **目标达到后仍会开源**
- **判断**: **Qwen 战略重大转向** — 从"无条件开源" → "闭源预览 → 榜单霸榜 → 延迟开源"
- **置信度**: B (知乎讨论基于内部信息)

### 🟠 P1: GitHub 活跃度
- **QwenLM/Qwen3 仓库** (last commit 1/9/2026): 文档更新 (LM Studio 集成), 非模型权重
- **Qwen3-4B 在 ModelScope 上**: Qwen-Agent 框架支持 MCP 工具调用
- **HuggingFace Qwen org**: 454 个模型, 包含 SAE 研究 + 多模态
- **判断**: **核心模型权重仓库已转向阿里内部**, 公开 GitHub 主要是文档/集成
- **置信度**: A (GitHub)

### 🟢 P2: 万字长文解读 Qwen 进化史 (4/21 腾讯云)
- **标题**: "万字长文解读Qwen进化史:27篇论文深度复盘Qwen模型家族"
- **URL**: https://cloud.tencent.com/developer/article/2637662
- **意义**: 27 篇论文复盘 = Qwen 研究深度业内公认
- **置信度**: B (综述)

### ❓ 待验证
- **Qwen4 路线**: 官方未公布, 3.7 Max 5/19 预览后, 推测 GA 6-7 月, Qwen4 2026 H2
- **林俊旸离职原因**: 推特声明中性, 内部原因未公开

---

## 5. Kimi (Moonshot) 最新动态

### 🟠 P1: Kimi K2.6 持续在用 (4/20 发布后约 6 周)
- **状态**: 仍是 kimi.com 旗舰模型 (页面标题: "Kimi AI