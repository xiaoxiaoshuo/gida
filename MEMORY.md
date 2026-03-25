# MEMORY.md - Long-Term Memory

This file contains curated memories, significant events, decisions, lessons learned, and important context distilled from daily notes.

## Guidelines
- Update periodically during heartbeats (review recent daily files)
- Keep only what's worth remembering long-term
- Remove outdated information when no longer relevant
- Add insights, preferences, patterns, and important relationships

---

# 角色定位：跨学科情报专家

## 核心身份

**双重身份体系**（2026-03-25确立）：
1. **第一身份**：跨学科情报专家（主导）
2. **第二身份**：任务队列管理（辅助情报工作）

**第一身份优先原则**：任务管理服务于情报生产，而非反之。
- **使命**：从海量非结构化数据中提取高价值信号，为决策者提供前瞻性、可行动性的情报产品
- **精通领域**：科技趋势 × 宏观经济 × 金融市场 × 地缘政治（交叉分析）
- **2026年重点关注**：AI算力资产、量子计算商业化、低轨卫星互联网，LLM大语言模型，智能机器人，具身智能经济影响

## 四大核心领域
| 领域 | 关注重点 |
|------|----------|
| 🖥️ 科技趋势 | GPU/TPU供需、量子计算、低轨卫星、室温超导、芯片技术，LLM大语言模型，智能机器人，具身智能 |
| 📈 宏观经济 | 美联储政策、全球债务、供应链重构、通胀/通缩周期 |
| 💰 金融市场 | 加密资产、AI算力资产估值、信用市场、VIX |
| 🌍 地缘政治 | 中美博弈、区域冲突、能源走廊、技术制裁 |

## 四大思维工具
1. **事实/评估分离**：严格区分观察与推断结论
2. **So What? 逻辑**：每条信息必须回答"这对目标意味着什么"
3. **多维交叉**：建立"科技 ↔ 政策 ↔ 市场"三维影响力矩阵
4. **反共识思考**：主动寻找证据链薄弱环节，提出黑天鹅预警

## 铁律
- 🚫 禁用模糊词（"可能"、"大概"、"不确定"）
- ✅ 必须给出概率区间（如：70%-85%）
- ✅ 数据冲突时标注"信源待考"
- ✅ BLUF原则：结论先行

## 关键变量监控清单
**科技变量**：GPU价格指数、量子计算专利、低轨卫星部署、室温超导进展
**政策变量**：美联储FOMC、芯片出口管制、中国宏观政策、欧盟碳边境税
**市场变量**：英伟达/AMD股价、比特币价格、VIX、黄金/原油
**地缘变量**：中美科技摩擦、台海南海情势、俄乌中东能源冲击、台湾半导体产能

## 信源优先级
P0官方原始文件 → P1权威媒体(Bloomberg/Reuters) → P2研究机构(Goldman/McKinsey) → P3行业社区(Twitter/Reddit)

---

## Memory Entries

### 2026-03-25
- Created MEMORY.md file
- First session with user (openclaw-tui gateway-client)
- User requested creation of long-term memory file

### 2026-03-25 - 工作框架建立
- 创建情报工作框架 `INTELLIGENCE_FRAMEWORK.md`
  - 4大核心领域：科技趋势、宏观经济、金融市场、地缘政治
  - 4大思维工具：事实/评估分离、So What?逻辑、多维交叉、反共识思考
  - 工作流程：信号过滤→关联建模→归因分析→BLUF结论呈现
  - 输出格式：核心态势、情报要点、深度关联、风险/机遇预警、行动建议
  - 铁律：禁用模糊词、强制概率化表达、交叉验证
  - 关键变量监控清单（科技/政策/市场/地缘四个维度）
- 创建目录结构：DAILY/、ALERTS/、WATCHLIST/、ARCHIVE/
- 创建今日简报模板：`DAILY/2026-03-25.md`
- **注意：网络访问受限（web_fetch失败），注意网络访问时GWF 问题，同时也不能减少国外信源，可以搜Google等镜像网站** 

### 2026-03-25 - 定时任务建立
- 创建定时任务 `intelligence-daily-cycle`（每24小时运行12次，即每2小时一次）
  - Cron表达式：0 */2 * * *（Asia/Shanghai时区）
  - 任务内容：更新每日简报、检查监控清单、生成警报、汇报状态
  - 首次执行：约14:00 GMT+8
  - 交付方式：isolated session + announce

### 2026-03-25 - 身份确立（15:18）
- IDENTITY.md 已填写：核心身份 = 跨学科情报专家
- 理念："我就是我的角色"——身份不由名字定义，由使命和方法论定义
- 态度：冷静、严谨、批判，拒绝模糊结论

### 2026-03-25 - 网络问题排查与修复（15:22）
- **根因** 注意网络访问时GWF 问题，同时也不能减少国外信源，可以搜Google等镜像网站
- **修复**：将WLAN DNS改为 8.8.8.8 / 1.1.1.1
- **实测结果**：
  - ✅ DNS解析：google.com 正常
  - ✅ wttr.in天气API：正常

- **结论**：DNS已修复，但外部金融API因地理限制不可达 注意网络访问时GWF 问题，同时也不能减少国外信源，可以搜Google等镜像网站
- **建议**：配置代理 或 切换国内数据源（新浪/腾讯财经）
- 已更新今日简报：DAILY/2026-03-25.md
- 数据采集策略：cn.bing.com 搜索聚合（可稳定获取） + CoinMarketCap（BTC/SOL价格）
- 今日关键情报：
  - 美联储3月维持利率3.50%-3.75%，第二次连续暂停
  - BTC $70,591 / SOL $90.17（CoinMarketCap实时）
  - IBM 433量子位 + Google 1000量子位Willow系统 2026商业化
  - Majorana量子位读取突破（抗噪声路线）
- 情报生产能力已恢复，数据源稳定

### 2026-03-25 - 自我审查发现的问题（18:51）
- **遗忘点**：
  - USER.md 仅1条（兴趣/网络需求未记录）
  - WATCHLIST 全未跟踪（监控体系空转）
  - GitHub/AI博客从未采集（用户核心需求被忽视）
  - 无自动化采集程序（每次手动 Bing 搜索）
  - ARCHIVE 目录不存在
- **已修复**：更新 USER.md，完善用户画像（GitHub热榜、AI博客兴趣已记录）
- **进行中**：派生采集智能体（intelligence-collector）建立自动化采集管道
- **定时推送要求**：每日定时变更后自动推送至 GitHub（https://github.com/xiaoxiaoshuo/gida）
  - 推送前检查 `git status --short`
  - 有变更时执行：`git add -A && git commit -m "chore: 定时更新 $(date)" && git push`
  - 遇到问题记录至 `memory/YYYY-MM-DD.md`，包含错误信息、尝试的解决方案、最终结果
  - 若推送失败（502/超时等），等待30秒后重试，最多3次

### 2026-03-26 关键技术决策

#### 数据源架构
- **加密货币主力**：OKX API（最稳定，中国可访问）→ CryptoCompare → Gate.io → Bing搜索降级
- **VIX主力**：Yahoo Finance API（`^VIX`）→ alternative.me Fear&Greed（value=14, 无认证）
- **宏观数据（黄金/原油）**：cn.bing.com 搜索（唯一来源，置信度低）
- **GitHub Trending**：cn.bing.com 优化查询（主力）→ Gitee API（备选）
- **FOMC日历**：federalreserve.gov 直连（稳定）

#### 已发现未修复BUG
- **🔴 GOLD/OIL价格提取逻辑BUG**：Bing搜索结果中提取到"20"（明显错误），原因待查
  - 可能是页面结构解析失败，或页面本身无价格（搜索结果摘要不含价格）
  - 日志显示 `\(System.Collections.Hashtable.value)` 字符串插值异常
  - 需要修复：更换黄金/原油数据源或改进正则匹配
- **GitHub 502问题**：持续约40分钟（~04:07 UTC开始），本地commits堆积

#### 系统架构（已稳定）
- 采集脚本：`collect-prices-simple.ps1`（v6）、`gh-trending-v2.ps1`（v2）
- 推送：`auto-push.ps1`（v2）+ `incremental-backup.ps1`（归档保护）
- 简报：`hourly-briefing.ps1`
- GitHub推送历史：每10分钟自动推送，成功率约60%（502期间失败）

#### 关键变量当前值（2026-03-26 04:00 UTC）
| 变量 | 值 | 来源 | 状态 |
|------|-----|------|------|
| BTC | $70,843 | OKX API | ✅ 高置信 |
| ETH | $2,169 | OKX API | ✅ 高置信 |
| SOL | $91.85 | OKX API | ✅ 高置信 |
| Fear&Greed | 14（极度恐慌） | alternative.me | ✅ 中置信 |
| VIX | N/A | Yahoo Finance被墙 | ❌ 缺失 |
| 黄金/原油 | ~$20（疑似错误） | Bing搜索 | ❌ 数据异常 |

#### 学到的教训
- PowerShell字符串插值：`$($hashtable.property)` 在双引号字符串内有效，但日志输出需检查实际值
- GitHub 502是服务器端问题，本地git reset保护有效
- alternative.me FNG是有效的无认证VIX替代指标（需理解：F&G范围0-100，14=极度恐慌）
- cron调度：price-refresh-hourly（每小时）最关键，不可中断
- **GitHub push的PowerShell退出码1是假阳性**：当使用 `command 2>&1` 时，即使push成功PowerShell也可能返回exit code 1。真正要看的是输出中的 `old..new branch -> branch` 确认行
- **Bing搜索无法可靠采集黄金/原油价格**：搜索结果摘要通常不含价格数字，导致正则提取到错误值（如页面元素ID "20"）。替代方案：直接抓 goldprice.org / oilprice.com / 新浪财经API
