# 采集系统状态

**最后更新**: 2026-03-26 07:36 GMT+8

---

## 网络状态
| 指标 | 状态 |
|------|------|
| OKX_API | ✅ 正常 |
| Kitco黄金 | ✅ 正常 |
| OilPrice原油 | ✅ 正常 |
| alternative.me VIX | ✅ 正常 |
| GitHub Push | ✅ 正常 |

## 采集脚本状态
| 脚本 | 版本 | 状态 |
|------|------|------|
| collect-prices-simple.ps1 | v6b | ✅ 正常 |
| collect-tech-news.ps1 | - | ✅ 正常 |
| collect-policy.ps1 | - | ✅ 正常 |

## 修复记录

### 2026-03-26
- **GitHub 502修复**: 配置HTTPS走443端口 (原SSH/22)
- **VIX替代源**: alternative.me_FNG 已替换失效的Yahoo Finance
- **黄金采集修复**: Kitco字体样式正则 `font-normal">([0-9],[0-9]{3}\.[0-9]{2})</div>` 已验证
- **原油采集修复**: oilprice.com直接抓取，已验证

## 已知问题
- VIX来源为alternative.me FNG指数（非正宗VIX），质量评级"中"
- BTC/ETH/SOL全部走OKX单源，建议后续增加备用API
