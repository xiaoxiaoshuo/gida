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

*最后更新：2026-03-26*
