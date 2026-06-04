# WATCHLIST | 必读技术博客源

> 建立时间：2026-03-26  
> 采集频率：每周（周三/周六）  
> 当前状态：⚠️ 部分不可达（GWF影响）

---

## 🔴 顶级优先级（每周必读）

### AI/ML 公司官方博客

| 来源 | URL | 频率 | GFW状态 | 数据质量 |
|------|-----|------|---------|----------|
| **DeepSeek Blog** | https://deepseek.com/blog | 每周 | ⚠️ 部分JS渲染 | 高（官方一手） |
| **OpenAI Blog** | https://openai.com/blog | 每周 | 🔴 阻断 | 中（需代理） |
| **Anthropic Research** | https://www.anthropic.com/research | 每周 | 🔴 阻断 | 高（官方一手） |
| **Google AI Blog** | https://blog.google/technology/ai/ | 每周 | 🔴 阻断 | 高 |
| **Google DeepMind** | https://deepmind.google/discover/ | 每周 | 🔴 阻断 | 高 |
| **Meta AI Blog** | https://ai.meta.com/blog/ | 每周 | 🔴 阻断 | 高 |
| **Microsoft Research** | https://www.microsoft.com/en-us/research/blog/ | 每周 | 🔴 阻断 | 高 |
| **AWS ML Blog** | https://aws.amazon.com/blogs/machine-learning/ | 每周 | ⚠️ 偶尔阻断 | 高 |
| **NVIDIA ML Blog** | https://developer.nvidia.com/blog/ | 每周 | ⚠️ 偶尔阻断 | 高 |

### 关键发现

> **DeepSeek V3.2 正式版发布（2026-03-12）**  
> - 强化 Agent 能力，融入思考推理  
> - 236B 参数，64K 上下文  
> - API 定价：1元/百万输入，2元/百万输出  
> - 兼容 OpenAI API 接口

---

## 🟡 高价值技术博客

### LLM/推理框架

| 来源 | URL | 频率 | 备注 |
|------|-----|------|------|
| **vLLM Blog** | https://docs.vllm.ai/en/latest/ | 每月 | 官方文档+Release notes |
| **Ollama Blog** | https://ollama.com/blog | 每周 | 本地LLM部署 |
| **Hugging Face** | https://huggingface.co/blog | 每周 | AI/ML 行业门户 |
| **LangChain Blog** | https://blog.langchain.dev/ | 每周 | Agent 开发框架 |
| **LlamaIndex Blog** | https://www.llamaindex.ai/blog | 每周 | RAG 生态 |
| **CrewAI Blog** | https://blog.crewai.com/ | 每周 | 多Agent框架 |

### AI Agent 专项

| 来源 | URL | 频率 | 备注 |
|------|-----|------|------|
| **AutoGPT Blog** | https://newsletter.autogpt.net/ | 每周 | Agent 先驱 |
| **Multi-Agent Orchestration** | https://docs.crewai.com/ | 每周 | Agent 协作协议 |
| **MCP (Model Context Protocol)** | https://modelcontextprotocol.io/ | 每周 | Anthropic 发起 |
| **A2A (Agent-to-Agent)** | https://arxiv.org/abs/XXXX | 按需 | Agent 通信协议 |

### 量化/金融

| 来源 | URL | 频率 | 备注 |
|------|-----|------|------|
| **Quantopian Blog** | https://www.quantopian.com/posts | 每周 | 量化策略 |
| **Alphalens** | http://quantopian.github.io/alphalens | 每月 | 因子分析 |

---

## 🔵 行业趋势博客

### 新闻聚合（绕过GWF）

| 来源 | URL | 频率 | 备注 |
|------|-----|------|------|
| **36kr AI** | https://36kr.com/information/AI | 每日 | 中文AI新闻 |
| **机器之心** | https://jiqizhixin.com/ | 每日 | 技术深度 |
| **量子位** | https://www.qbitai.com/ | 每日 | AI 前沿 |
| **GitHub Trending** | https://github.com/trending | 每日 | 间接通过Bing |
| **Hacker News** | https://news.ycombinator.com/ | 每日 | 行业讨论 |

### 海外技术媒体

| 来源 | URL | 频率 | 备注 |
|------|-----|------|------|
| **The Verge AI** | https://www.theverge.com/ai-artificial-intelligence | 每日 | 科技综合 |
| **Ars Technica AI** | https://arstechnica.com/ai/ | 每日 | 技术深度 |
| **Wired AI** | https://www.wired.com/tag/artificial-intelligence/ | 每日 | 科技文化 |
| **MIT Technology Review** | https://www.technologyreview.com/ | 每周 | 学术视角 |

---

## 📅 采集频率配置

### 每周采集日历

| 周期 | 目标 | 执行脚本 |
|------|------|----------|
| **周三 10:00** | Tech Blog 全量扫描 | collect-tech-news.ps1 |
| **周六 10:00** | AI/ML 深度追踪 | collect-tech-news.ps1 |
| **每日 08:00** | 加密货币价格 | collect-prices-simple.ps1 |
| **每日 09:00** | GitHub Trending | gh-trending-v2.ps1 |

### 触发式采集（异常信号）

| 触发条件 | 采集目标 |
|----------|----------|
| 重大模型发布 | DeepSeek/OpenAI/Anthropic 官方博客 |
| 政策变动 | 36kr/华尔街见闻 |
| 市场异常 | OKX API 价格 + Bing 新闻 |

---

## 📊 数据质量评估

| 来源 | 可达性 | 更新频率 | 内容质量 | 备注 |
|------|--------|----------|----------|------|
| DeepSeek | ⚠️ JS渲染 | 高 | ⭐⭐⭐⭐⭐ | 直接内容难提取 |
| OpenAI | 🔴 GFW | 高 | ⭐⭐⭐⭐⭐ | 必须代理 |
| Anthropic | 🔴 GFW | 高 | ⭐⭐⭐⭐⭐ | 必须代理 |
| 36kr | ✅ 可达 | 高 | ⭐⭐⭐⭐ | 中文一手 |
| GitHub Trending | 🔴 GFW | 每日 | ⭐⭐⭐ | Bing替代方案 |

---

## ⚠️ GWF应对策略

### 当前可用信源（非代理）

```
✅ cn.bing.com          - 搜索聚合（主要渠道）
✅ deepseek.com         - 官方博客（部分JS渲染）
✅ 36kr.com              - 中文科技新闻
✅ jiqizhixin.com        - 机器之心
✅ qbitai.com            - 量子位
✅ OKX API              - 加密货币价格
```

### 需要代理/镜像的信源

```
🔴 openai.com          - OpenAI官方
🔴 anthropic.com        - Anthropic官方
🔴 google.com           - Google AI Blog
🔴 huggingface.co       - 模型/数据集
🔴 github.com (直接)    - Trending页面
```

---

## 🆕 v2 增量 (2026-06-05 02:30 GMT+8)

> **信号源**: data/ai/ai-news_latest.md (02:27 fresh 3min, 46 条)  
> **采集者**: G-37A 子智能体 (runId: G37A-WATCHLIST-FIX-2026-06-05-0230)  
> **窗口**: 6/3 - 6/4 关键博客与公司动态

### 🔥 P0 级信号（必读）

#### 1. VoidZero Is Joining Cloudflare ⭐⭐⭐⭐⭐

- **URL**: https://blog.cloudflare.com/voidzero-joins-cloudflare/
- **时间戳**: 2026-06-04 (HN 270+ pts)
- **来源**: Hacker News / Cloudflare Blog
- **摘要**: VoidZero (由 Vite/Rollup 作者 Evan You 创立) 正式加入 Cloudflare。Cloudflare 借此整合 JS 工具链生态 (Vite/Rollup/esbuild/Oxc), 推动边缘计算上的 JS 构建工具链统一。
- **影响**: 
  - Cloudflare Workers 生态可能内置 Vite/Rollup,边缘 SSR 性能进一步提升
  - 传统 webpack 生态承压
  - JS 工具链整合可能延伸到 Workers AI 部署链路
- **行动建议**: 关注 Cloudflare Workers AI 与 VoidZero 集成的后续公告

#### 2. The ways we contain Claude across products (Anthropic Engineering)

- **URL**: https://www.anthropic.com/engineering/how-we-contain-claude
- **时间戳**: 2026-06-03 发布
- **来源**: Anthropic Engineering Blog
- **摘要**: Anthropic 公开 Claude 在不同产品 (Claude.ai, API, Bedrock, Vertex AI) 中的"边界控制"机制 - 包括 system prompt 强化、输出过滤、Jailbreak 防御栈。配合 6/15 S-1 提交时间窗, 透明度建设意图明显。
- **影响**:
  - 投资人/监管层关切: 安全治理投入可量化
  - 行业基准: 其他大模型厂商安全堆栈将被迫公开
  - 监管博弈筹码: Anthropic 主动披露 = 防御性合规策略
- **行动建议**: S-1 路演前最后一次"软披露", 关注 6/15 后续

#### 3. Gemma 4 12B: A unified, encoder-free multimodal model (Google AI)

- **URL**: https://blog.google/innovation-and-ai/technology/developers-tools/introducing-gemma-4-12b/
- **时间戳**: 2026-06-04
- **来源**: Google AI Blog
- **摘要**: Google 发布 Gemma 4 12B - 统一无编码器多模态模型,支持文本/图像/视频/音频原生输入。12B 参数量,主打"小而强"的开源生态位。
- **影响**:
  - 12B 段位竞争升级: Qwen3-12B / Llama 4 12B / Gemma 4 12B 三足鼎立
  - 多模态"无编码器"路线确认, 与 Apple AIMv2 / InternVL 一致
  - 本地部署 + Apple Silicon / Snapdragon X 优化空间打开
- **行动建议**: 跟踪 HuggingFace 下载量与开发者采用率, 关注 6/12 FOMC 前流动性事件

### 🟠 P1 级信号（重要）

#### 4. KVarN: Native vLLM KV-cache quantization back end (Huawei)

- **URL**: https://github.com/huawei-csl/KVarN
- **时间戳**: 2026-06-04
- **来源**: Hacker News / GitHub
- **摘要**: Huawei CSL 团队发布 vLLM 原生 KV-cache 量化后端,支持 INT4/INT8 量化,显存占用降低 50-70%, 推理吞吐量提升 1.5-2x。
- **影响**:
  - 长上下文场景 (128K+) 部署成本大幅下降
  - 配合 Ascend NPU 优化, 国产推理栈完整度提升
  - 与 DeepSeek V3.2 / Qwen3 长上下文生态协同
- **行动建议**: 监控 vLLM 上游合并进度, 关注 Ascend 910C/910D 配套

#### 5. Uber's $1,500/month AI limit is a useful signal for AI tool pricing (Simon Willison)

- **URL**: https://simonwillison.net/2026/Jun/3/uber-caps-usage/
- **时间戳**: 2026-06-03
- **来源**: Simon Willison's Blog
- **摘要**: Uber 内部对 AI 编码工具 (Cursor/Copilot/Claude Code) 设定了 $1,500/工程师/月 的硬性预算上限, 反映企业级 AI 工具消费已从"试用"进入"管控"阶段。
- **影响**:
  - 定价心理学锚点: $1,500/月 成为一个新基准线
  - 企业 IT 采购 AI 工具进入"成本可预测"时代
  - 倒逼 AI 工具厂商提供 ROI 证明
- **行动建议**: 跟踪企业级 AI 工具 ARR 增速, 关注 Cursor / Cognition / Replit 商业化进展

### 🟡 P2 级信号（关注）

#### 6. Claude Code and Codex Can Have Real-Time Conversation via Git (Medium)

- **URL**: https://medium.com/@Koukyosyumei/claude-code-and-codex-can-have-real-time-conversation-via-git-f95b696c1c05
- **时间戳**: 2026-06-04
- **来源**: Medium / Hacker News
- **摘要**: 开发者展示 Claude Code 与 OpenAI Codex 通过 Git 仓库进行实时对话/协作的工作流 - 利用 Git 作为"消息队列"。
- **影响**:
  - AI Agent 协作新范式: Git = Agent 中间件
  - 与 MCP (Model Context Protocol) 生态互补
  - 编码 Agent 多模型协作的早期实验

#### 7. Show HN: Boxes.dev - Claude Code 和 Codex 云端运行

- **URL**: https://boxes.dev
- **时间戳**: 2026-06-04
- **来源**: Show HN
- **摘要**: Boxes.dev 提供云端容器, 允许开发者在浏览器中运行 Claude Code 和 Codex, 告别 localhost 限制, 解决本地环境配置痛点。
- **影响**: 
  - 编码 Agent 商业化新方向: "AI IDE as a Service"
  - 与 GitHub Codespaces / Replit 竞争

### 📊 增量摘要表

| 序号 | 博客/公司 | 标题 | 重要性 | URL |
|------|----------|------|--------|-----|
| 1 | Cloudflare | VoidZero Is Joining Cloudflare | 🔴 P0 | [link](https://blog.cloudflare.com/voidzero-joins-cloudflare/) |
| 2 | Anthropic | The ways we contain Claude across products | 🔴 P0 | [link](https://www.anthropic.com/engineering/how-we-contain-claude) |
| 3 | Google AI | Gemma 4 12B: unified multimodal | 🔴 P0 | [link](https://blog.google/innovation-and-ai/technology/developers-tools/introducing-gemma-4-12b/) |
| 4 | Huawei CSL | KVarN: vLLM KV-cache quantization | 🟠 P1 | [link](https://github.com/huawei-csl/KVarN) |
| 5 | Simon Willison | Uber's $1,500/month AI limit | 🟠 P1 | [link](https://simonwillison.net/2026/Jun/3/uber-caps-usage/) |
| 6 | Medium (Koukyosyumei) | Claude Code + Codex via Git | 🟡 P2 | [link](https://medium.com/@Koukyosyumei/claude-code-and-codex-can-have-real-time-conversation-via-git-f95b696c1c05) |
| 7 | Boxes.dev | AI IDE as a Service | 🟡 P2 | [link](https://boxes.dev) |

### 🎯 战略研判

1. **Cloudflare 战略升级**: VoidZero 加入 + Workers AI + 6月 Anthropic 合作 = Cloudflare 正从 CDN 转型为"全栈 AI 云", 直接对标 AWS/Azure/GCP 三巨头
2. **Google 开源反击**: Gemma 4 12B 多模态 + 12B 段位卡位 = 应对 DeepSeek/Qwen 冲击
3. **Anthropic 安全叙事**: S-1 前的"软披露"工程文化, 估值故事铺垫
4. **企业 AI 进入"成本管控"期**: $1,500/月 锚点出现

---

*最后更新：2026-06-05 02:30 GMT+8 (G-37A)*
*信号源: data/ai/ai-news_latest.md*
