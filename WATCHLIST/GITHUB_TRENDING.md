# WATCHLIST | GitHub Trending AI/ML 项目监控清单

> 建立时间：2026-03-26  
> 状态：🟢 已更新 (2026-03-26 10:46)  
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

*最后更新：2026-03-26 10:46 GMT+8*
