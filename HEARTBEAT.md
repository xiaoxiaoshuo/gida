# HEARTBEAT.md

## 快照 | 2026-04-21 11:35 GMT+8

- ⏰ **11:35定时扫描 - AI新闻采集已修复**
- 价格采集: ✅ 11:23成功
- AI新闻采集: ✅ 修复完成（20条 TechCrunch 10 + MIT 10）
- VentureBeat/The Verge: ⚠️ RSS被屏蔽（0条）
- GitHub Push: ✅ 11:24成功

### 📊 数据新鲜度（11:35）
| 文件 | 状态 | 最后更新 |
|------|------|----------|
| prices_latest.json | ✅ | 11:24 |
| fear-greed_latest.json | ✅ | 11:24 |
| gold_latest.json | ✅ | 11:24 |
| oil_latest.json | ✅ | 11:24 |
| hacker-news_latest | ✅ | 10:49 |
| github-trending_latest.json | ✅ | 11:03 |
| tech-news_latest.json | ✅ | 11:05 |
| ai-news_latest.json | ✅ | 11:32（20条） |

### 🔧 修复记录
1. **collect-ai-news-rss.ps1** - 修复RSS解析问题（处理XmlElement和数组类型）
2. **sync-ai-news-md.ps1** - 自动同步JSON→Markdown
3. 当前可用源：TechCrunch AI + MIT Technology Review（各10条）

### 📈 当前市场信号
- BTC $75,600 / ETH $2,303 / SOL $85.19
- GOLD $4,798 / OIL $86.59 / F&G 33 (Fear)
- 市场情绪：从极度恐慌14→33（Fear），仍偏谨慎但正在修复