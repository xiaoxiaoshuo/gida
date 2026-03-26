# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

## 🌐 网络访问配置

### GitHub 镜像
- **主力**: `https://bgithub.xyz/` — 替代 `github.com`，中国可访问
- **备选**: `https://github.com/`（直连可能失败）
- GitHub API 镜像: `https://api.bgithub.xyz/`（待验证）

### 加密货币数据源
- **OKX API**: `https://www.okx.com/api/v5/market/ticker?instId=BTC-USDT`
- **OKX Web**: `https://www.okx.com/zh-hans/price/bitcoin-btc`（JS 渲染，需等待）
- **备选**: CryptoCompare API

### 宏观数据
- **Fear&Greed**: `https://alternative.me/crypto/fear-and-greed-index/`（页面抓取，web_fetch可用）
- **黄金**: `https://goldprice.org/` — JS渲染，**必须用浏览器** `evaluate` 提取 `SPAN.tick-value.price-value`
- **原油**: `https://oilprice.com/` — JS渲染，**必须用浏览器**

### 🧠 JS渲染网站采集铁律
> 只要网站是JS渲染的（内容不在HTML源码中），**必须用浏览器**，`web_fetch` 只能抓到空壳。
> 采集顺序：1. 先试 `web_fetch`（快）→ 2. 失败则用浏览器 `evaluate` → 3. 浏览器超时则降级估算值

### AI/ML 新闻
- **Hacker News**: `https://news.ycombinator.com/`（Brave 浏览器可访问）
- **GitHub Trending**: `https://bgithub.xyz/trending`（推荐）
- **Bing 搜索**: `https://cn.bing.com/`

---

Add whatever helps you do your job. This is your cheat sheet.
