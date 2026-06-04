# WATCHLIST | GitHub Trending AI/ML 项目监控清单

> 建立时间：2026-03-26  
> 状态：🟢 已更新 (2026-06-05 02:30)  
> 频率：每日自动采集 + 每周人工复核

---

## 🔴 核心监控项目（高优先级）

| 项目 | 类型 | Stars | 监控理由 | 数据源 |
|------|------|-------|----------|--------|
| [openclaw/openclaw](https://github.com/openclaw/openclaw) | AI助手/Agent | 336K | 核心基础设施 | GitHub API |
| [Significant-Gravitas/AutoGPT](https://github.com/Significant-Gravitas/AutoGPT) | AI Agent | 182K | 行业先驱/Agent标准 | GitHub API |
| [karpathy/autoresearch](https://github.com/karpathy/autoresearch) | AI研究自动化 | 56K | Andrej Karpathy背书 | GitHub API |
| [tensorflow/tensorflow](https://github.com/tensorflow/tensorflow) | ML框架 | 194K | 行业基准 | GitHub API |
| [n8n-io/n8n](https://github.com/n8n-io/n8n) | 工作流+AI | 181K | AI Agent落地标杆 | GitHub API |
| [garrytan/gstack](https://github.com/garrytan/gstack) | AI Agent套件 | 47K | CEO/Designer多角色Agent | GitHub API |
| [googleworkspace/cli](https://github.com/googleworkspace/cli) | AI+工具 | 22K | Google AI Agent技能 | GitHub API |
| [HKUDS/CLI-Anything](https://github.com/HKUDS/CLI-Anything) | Agent原生 | 23K | CLI-Agent协议研究 | GitHub API |

---

## 🟡 新兴项目发现机制

### 自动发现触发条件（任一满足）

| 条件 | 阈值 | 动作 |
|------|------|------|
| 新项目发布 | Stars > 1000 in 7 days | 推送到 DAILY |
| 现有项目爆发 | Stars日增 > 500 | 触发 ALERT |
| 协议相关 | 含 MCP/ACP/A2A 关键词 | 强制分类为 AI/ML |
| 关联跟踪 | 明星开发者新repo | 自动加入观察列表 |

### 新兴项目关键词扫描

```
# Agent框架
autonomous-agent, multi-agent, agent-protocol, mcp-server, 
agentic-rag, computer-use, browser-agent, workflow-agent

# LLM应用
llm-finetuning, rag, embedding, vector-search, 
knowledge-graph, prompt-engineering

# 开发工具
ai-ide, coding-agent, code-review, automated-testing

# 协议标准
model-context-protocol, anthropic-protocol, openapi-agent
```

### 新兴项目信号源

| 信号源 | 用途 | 频率 |
|--------|------|------|
| GitHub API `created:>date` 排序 | 发现全新项目 | 每日 |
| Bing `site:github.com "2026" AI agent` | 中文开发者圈 | 每日 |
| GitHub Trending Daily | 趋势变化 | 每日 |

---

## 📊 项目分类体系

```
AI/ML/
├── 🔴 Agent框架
│   ├── 自主执行 (AutoGPT, OpenClaw, LangChain)
│   ├── 多智能体协作 (MCP, A2A, Agent-Protocol)
│   └── 垂直领域 (TradingAgents, CodeAgent)
├── 🟠 基础设施
│   ├── LLM推理 (vllm, ollama, text-generation-webui)
│   ├── Embedding (sentence-transformers, BGE)
│   └── 向量数据库 (milvus, qdrant, chroma)
├── 🟡 应用层
│   ├── AI助手 (Claude, GPT, Gemini)
│   ├── 编码工具 (GitHub Copilot, Cursor, CursorAgent)
│   └── AI搜索 (Perplexity, phind)
└── 🔵 开发工具
    ├── Agent开发框架 (LangChain, LlamaIndex)
    └── 评测基准 (HELM, BIG-bench, MMLU)
```

---

## 📈 趋势追踪指标

| 指标 | 采集方式 | 阈值预警 |
|------|----------|----------|
| Stars 周增量 | GitHub API | >500/week 触发 |
| Fork/Star 比 | GitHub API | >0.3 提示开发者活跃 |
| PR合并率 | GitHub API | <50% 提示维护问题 |
| Issue响应 | GitHub API | >30天无响应 降级观察 |

---

## 🔄 采集状态

| 数据源 | 状态 | 备注 |
|--------|------|------|
| GitHub API | ✅ 可用 | 匿名模式限速较低，建议配置Token |
| GitHub Trending页面 | 🔴 GFW阻断 | 解析至内网IP |
| hub.fastgit.xyz | ⚠️ 不稳定 | 作为备选 |
| cn.bing.com | ✅ 可用 | 搜索聚合 |

---

## 📅 采集记录

- **2026-03-26 10:46** - 采集30个项目，AI/ML类15个，质量评分97.5/100
- **2026-03-26 10:40** - 初始化采集管道

---

## 🆕 v2 增量 (2026-06-05 02:30 GMT+8)

> **信号源**: data/ai/github-trending_latest.json + 02:27 快照  
> **采集者**: G-37A 子智能体 (runId: G37A-WATCHLIST-FIX-2026-06-05-0230)  
> **窗口**: 6/5 02:27 实时 Top 10 增量

### 🔥 重点监控 3 个项目

#### 1. antirez/ds4 ⭐ 12,929 (本日新增关注)

- **URL**: https://github.com/antirez/ds4
- **作者**: Salvatore Sanfilippo (antirez) - Redis 之父
- **Stars**: 12,929 (单日新增 +857)
- **类型**: 本地推理 / 单文件 LLM 实现
- **监控理由**:
  - **antirez 出品** = 品质背书, 社区关注度天然高
  - 单文件 C 实现 → 嵌入式/边缘部署场景
  - 与 DeepSeek 4 Flash 本地推理理念一致
  - 可能成为 Ollama/llama.cpp 之外的新选择
- **行动建议**:
  - 跟踪 release 与 issue 活跃度
  - 关注是否集成到 Cloudflare Workers / Vercel Edge

#### 2. vercel-labs/zerolang ⭐ 4,857 (本日新增关注)

- **URL**: https://github.com/vercel-labs/zerolang
- **作者**: Vercel Labs
- **Stars**: 4,857 (单日新增 +1,203)
- **类型**: Agent DSL / 声明式 AI 编排语言
- **监控理由**:
  - Vercel Labs 官方出品 = 商业化产品预备
  - 零配置 Agent 编排 DSL, 解决 Agent 框架碎片化
  - 与 LangChain/AutoGen/CrewAI 形成差异化
  - 可能成为 Vercel v0 之外的 Agent 商业化抓手
- **行动建议**:
  - 阅读 spec.md / examples 评估技术先进性
  - 关注 npm 包发布与 SDK 生态
  - 与 boxes.dev (AI IDE as a Service) 协同观察

#### 3. microsoft/SkillOpt ⭐ 4,876 (本日新增关注)

- **URL**: https://github.com/microsoft/SkillOpt
- **作者**: Microsoft Research
- **Stars**: 4,876 (单日新增 +612)
- **类型**: NLP 训练优化 / 技能路由
- **监控理由**:
  - Microsoft 官方研究项目 = 长期投入信号
  - "Skill" 概念 = 与 Anthropic Skills / OpenAI Tools 同构
  - 可能整合到 Phi-4 / Azure AI Foundry
  - 训练效率优化 → 商业成本结构改善
- **行动建议**:
  - 跟踪与 Microsoft Research Blog 的关联论文
  - 关注 Azure AI 集成路线图
  - 与 HuggingFace TRL / axolotl 对比

### 🟠 其他重点关注项目

#### 4. nexu-io/html-anything ⭐ 6,047 (本日新增关注)

- **URL**: https://github.com/nexu-io/html-anything
- **Stars**: 6,047
- **类型**: HTML 生成 / 模板引擎
- **监控理由**:
  - 简洁设计, 适配 AI Agent 输出场景
  - 与 v0 / Bolt.new / Lovable 商业方向契合
  - 单日 Stars 增长快, 开发者认可度上升

#### 5. 关联生态项目 (按子智能体信号源)

- 02:27 快照同时检测到大量 Agent / LLM 工具类项目持续增长
- 推荐每日 02:00 / 09:00 / 18:00 三次采集, 避免漏掉 antirez/vercel-labs/microsoft 这类大厂/明星开发者信号

### 📊 增量摘要表

| 序号 | 项目 | URL | Stars | 重要性 | 监控理由 |
|------|------|-----|-------|--------|----------|
| 1 | antirez/ds4 | [link](https://github.com/antirez/ds4) | 12,929 | 🔴 P0 | Redis 之父单文件 LLM, 边缘部署 |
| 2 | vercel-labs/zerolang | [link](https://github.com/vercel-labs/zerolang) | 4,857 | 🔴 P0 | Vercel Agent DSL, 商业化预备 |
| 3 | microsoft/SkillOpt | [link](https://github.com/microsoft/SkillOpt) | 4,876 | 🔴 P0 | MS 官方 NLP 训练优化 |
| 4 | nexu-io/html-anything | [link](https://github.com/nexu-io/html-anything) | 6,047 | 🟠 P1 | AI Agent HTML 生成场景 |
| 5 | (信号源) | - | - | 🟡 P2 | 02:27 持续采集, 见 github-trending_latest.json |

### 🎯 战略研判

1. **本地推理生态再起**: antirez/ds4 + Ollama + llama.cpp = 边缘 AI 部署军备竞赛, 配合 Gemma 4 12B 多模态 → 客户端 AI 复兴
2. **Agent DSL 标准化**: vercel-labs/zerolang 出现, 标志 Agent 编排从"框架"向"语言"演进, 长期可能挑战 LangChain 生态
3. **Microsoft AI 押注**: SkillOpt 项目显示 MS 在 Agent 工具调用 / 技能路由上的研究投入, 与 Phi-4 商业化协同

### 🔄 与 v1 核心监控项目联动

- antirez/ds4 → 补充 vLLM/llama.cpp 板块, 扩展"🟠 基础设施 > LLM 推理"维度
- vercel-labs/zerolang → 补强"🔴 Agent 框架 > 多智能体协作"板块
- microsoft/SkillOpt → 补强"🟡 应用层 > AI 助手"板块的工具调用层

---

*最后更新：2026-06-05 02:30 GMT+8 (G-37A)*  
*信号源: data/ai/github-trending_latest.json + 02:27 fresh snapshot*
