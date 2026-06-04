---
date: 2026-06-04
time: 13:00
source: Let's Encrypt Official Blog
url: https://letsencrypt.org/2026/06/03/pq-certs
signal: P1 #20 HN 229分
confidence: A
collector: subagent-pqc-1300
note: 主URL 404,实际文章发布于 2026-06-03
---

# BLUF
- Let's Encrypt 官方宣布:采用 Merkle Tree Certificates (MTCs) 作为 Web PKI 后量子迁移路径,目标 2026 末 staging、2027 production。
- 弃用直接 X.509 + ML-DSA 路线:单次 TLS 握手将从当前 ~5KB 暴涨到 >10KB,Cloudflare 实测会导致相当比例连接失败。
- 战略意义:MTC 把"证书透明度"内嵌为发行属性,长期根 CA、代码签名、身份系统等高价值目标获得 store-now-decrypt-later 防御;Chrome 已宣布 MTC 为公开 Web 首选路径。

# 200字事件核心
Let's Encrypt 于 2026-06-03 正式公布后量子 Web PKI 路线图:选定 Merkle Tree Certificates (MTCs) 作为承载后量子认证的证书形态,放弃直接在 X.509/TLS 中嵌入 ML-DSA 的方案。核心论点:ML-DSA-44 单签名 2,420B(对比 RSA-2048 的 256B、ECDSA-P256 的 64B)、公钥 1,312B,典型 TLS 握手包含 5 签 2 钥,替换后将突破 10KB,Cloudflare 实测下相当比例连接在真实网络中失败。MTC 改为批量签发:CA 一次性签名整批证书(landmarks),浏览器独立同步;握手仅需 1 签 1 公钥 1 inclusion proof,体积反比现在更小。Let's Encrypt 目标 2026 Q4 推出 staging MTC 签发环境、2027 推出 production-ready。Chrome、Cloudflare 已联合 IETF PLANTS 工作组推进标准化,Chrome 已公开声明 MTC 为公开 Web 首选路径。

# 150字技术细节
- **签名算法**:MTC 体系本身不绑定特定签名,但 Let's Encrypt 明确指向 NIST 后量子标准 ML-DSA(Go 1.27 已纳入标准库);MTC landmarks 是一次性签名整批证书的根级签名。X.509 中 ML-DSA 编码规范是 RFC 9881,TLS 握手中 ML-DSA 仍为 IETF draft。
- **证书链结构**:MTC 证书属于已发布的 Merkle Tree,无需额外 CT 旁路签名 — 透明度是发行属性而非外挂(对比现行 CT 生态)。Handshake 路径 = 1 signature + 1 public key + 1 inclusion proof;fallback 为 standalone 形式(握手略大),用于客户端 landmark 过期场景。
- **客户端兼容性**:当前 ACME 客户端零影响;MTC 落地需要 ACME 协议扩展、revocation/operational tooling 升级;浏览器侧 Chrome 已表态支持,需跟踪 PLANTS WG 与 mtcs@chromium.org 邮件列表。

# 100字行动建议
对加密钱包(BTC/ETH)与 SSL pinning 场景紧迫性低于通用 Web(签名主体是 CA,非用户密钥),但仍需关注三点:(1) 服务端立即启用 X25519MLKEM768 混合后量子密钥交换,防御 harvest-now-decrypt-later;(2) 维护 ACME pipeline 的团队应在 2026 Q4 跟踪 MTC staging,预备客户端适配;(3) 长期身份/code-signing 根密钥持有者应提前评估迁移到 PQC 签名的窗口期,NSA CNSA 2.0 与 NIST 草案均把 RSA-2048/ECDSA-P256 的截止日设在 2030/2035。
