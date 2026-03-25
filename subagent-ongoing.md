# 子智能体：持续情报监控与网络诊断

**任务ID**: intelligence-monitor-20260326
**创建时间**: 2026-03-26 04:50 GMT+8
**优先级**: P1（网络恢复后立即执行）

---

## 🎯 核心任务

### 1. 网络连通性诊断与监控
- **定期检查**：每小时ping关键服务（google.com, okx.com, goldprice.org, oilprice.com）
- **故障检测**：识别网络重定向、防火墙规则变更等问题
- **解决方案记录**：详细记录故障现象和修复方案
- **输出**：`network-status.json`（状态、延迟、可达性）

### 2. 深度新闻采集与分析
- **数据源**：
  - DeepSeek博客（deepseek.com/blog）
  - OpenAI官方新闻（openai.com/news）
  - arXiv论文摘要（量子计算、LLM、芯片技术）
  - 国内科技媒体（36氪、钛媒体等）
- **关键词**：AI大模型、量子霸权、Chiplet技术、GPU短缺、FOMC声明
- **输出格式**：JSON结构化文章元数据和摘要

### 3. 市场情绪与量化信号监控
- **Fear&Greed Index**：alternative.me API监控
- **VIX替代指标**：分析市场恐慌程度变化
- **BTC/ETH价格波动**：异常波动检测和预警
- **输出**：`market-sentiment.json`（情绪指数、波动率、异常事件）

### 4. 政策与地缘政治动态
- **FOMC会议跟踪**：美联储政策声明和点阵图更新
- **央行政策**：中国人民银行、欧洲央行最新动态
- **出口管制**：半导体相关管制措施变化
- **台海/中美科技摩擦**：最新事态发展评估
- **输出**：`policy-updates.json`（政策要点、影响评估、时间线）

### 5. GitHub开源项目热度监控
- **趋势分析**：AI/ML项目stars增长率、fork数变化
- **新项目追踪**：每日新增热门项目收录
- **开发者活跃度**：commit频率、issue解决速度
- **输出**：`github-trending.json`（排名、增长指标、分类标签）

---

## 📊 执行策略

### 网络正常时
```
每小时执行：
1. 数据采集（API+Web抓取）
2. 质量检查（数据完整性验证）
3. 本地归档（JSON文件保存）
4. 简报生成（DAILY/briefings.md更新）

每日执行：
1. 深度分析（关联性分析、趋势预测）
2. 报告生成（周报、月报）
3. 策略建议（基于数据洞察）
```

### 网络故障时
```
降级模式：
1. 使用本地缓存数据继续简报生成
2. 收集系统日志和网络诊断信息
3. 等待网络恢复后自动切换回正常模式
4. 记录故障时间和影响范围
```

---

## 🔧 技术实现要求

### 数据源适配
- **OKX API**：加密货币价格（主用）
- **alternative.me FNG**：VIX替代指标（备用）
- **新浪财经**：黄金/原油价格（国内备选）
- **cn.bing.com搜索**：Bing聚合搜索（最低优先级）

### 错误处理机制
- **重试策略**：指数退避重试（最多5次）
- **降级方案**：自动切换至备用数据源
- **异常记录**：详细的错误日志和堆栈跟踪
- **健康检查**：定期验证各数据源可用性

### 性能优化
- **并发控制**：限制同时进行的HTTP请求数量
- **缓存机制**：本地缓存常用数据避免重复获取
- **资源管理**：内存使用和CPU占用监控
- **超时设置**：合理配置请求超时时间（API:10s, Web:15s）

---

## 📈 输出规范

### JSON数据结构
```json
{
  "timestamp": "ISO8601",
  "source": "数据源标识",
  "data_type": "news|sentiment|policy|github|network",
  "content": { /* 具体数据内容 */ },
  "confidence": "high|medium|low",
  "status": "success|partial|failed",
  "metadata": {
    "url": "来源URL",
    "extraction_method": "API|Bing|Manual",
    "processing_time_ms": 123,
    "data_quality_score": 75
  }
}
```

### 文件组织
```
data/
├── intelligence/
│   ├── news_YYYY-MM-DD_HH-mm.json
│   ├── sentiment_YYYY-MM-DD_HH-mm.json
│   ├── policy_YYYY-MM-DD_HH-mm.json
│   └── github_YYYY-MM-DD_HH-mm.json
├── network/
│   └── connectivity_status_YYYY-MM-DD_HH-mm.json
└── archives/
    └── cached_data_YYYY-MM-DD.tar.gz
```

---

## ⚠️ 注意事项

### 安全约束
- 遵守各网站robots.txt协议
- 控制请求频率避免被封禁
- 敏感数据加密存储
- 日志脱敏处理（去除个人隐私信息）

### 合规要求
- 仅采集公开可用数据
- 尊重版权和知识产权
- 不进行大规模数据爬取
- 遵循相关法律法规

### 故障处理
- 网络中断时启用本地缓存
- 数据源失效时自动切换备选方案
- 系统错误时发送告警通知
- 定期备份关键数据防止丢失

---

## 🚀 启动命令

```powershell
# 启动子智能体
.\scripts\intelligence-monitor.ps1 -Mode "continuous" -Schedule "hourly"

# 启动单次执行
.\scripts\intelligence-monitor.ps1 -Mode "single" -Task "network-check|news-fetch|sentiment-analysis"

# 查看帮助
.\scripts\intelligence-monitor.ps1 -Help
```

---

**子智能体任务文档版本**: v1.0
**维护者**: OpenClaw Intelligence System
**最后更新**: 2026-03-26 04:50 GMT+8