# Sci-Hub 下载技术细节（2026-07-09 实测）

## terminal curl vs Python urllib

**关键发现**：terminal curl 和 Python urllib 在 Sci-Hub 上表现完全不同。

| 方式 | sci-hub.ru | sci-hub.st | 结论 |
|------|-----------|-----------|------|
| terminal curl | ⚠️ 冷启动偶过（26068 chars），第二次 CAPTCHA | ❌ DDoS-Guard / CAPTCHA | 优先用 curl |
| Python urllib | ❌ 始终 CAPTCHA（7313 chars） | ❌ 始终 CAPTCHA | **不要用** |

**原因推测**：Python urllib 的 TLS 指纹 / header 顺序 / 连接特征被 Sci-Hub 识别为 bot。terminal curl 的指纹更接近浏览器。

**实践**：尝试 Sci-Hub 下载时，**只用 terminal curl，不用 execute_code + urllib**。给足等待时间（30s+ connect-timeout），第一次请求最可能成功。

## 三个域名的不同阻断机制

| 域名 | 阻断类型 | 详情 |
|------|---------|------|
| `sci-hub.ru` | altcha CAPTCHA | "are you a robot?" — 页面 7313 chars |
| `sci-hub.st` | DDoS-Guard JS Challenge | "Checking your browser" — 需要执行 JS |
| `sci-hub.se` | 网络超时 | 从 WSL 不可达 |

## 元标签变化

旧版（~2024）：`<meta property="pdf_url" content="...">`
新版（2025+）：`<meta name="citation_pdf_url" content="//sci-hub.cat/storage/...">`

注意新版是**协议相对 URL**（`//` 开头），需要补 `https:`。

## 冷启动技巧

- Sci-Hub 对新 IP / 长时间未请求的会话有一定"宽容期"
- 第一次请求成功率最高
- 连续请求 2+ 次后必触发 CAPTCHA
- **策略**：每次只发一个请求，失败就放弃，不要循环重试

## 成功案例（2026-07-08 晚间）

```bash
DOI="10.1038/nature14236"
curl -sL --connect-timeout 30 \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
  "https://sci-hub.ru/$DOI"
# 返回: 26068 chars, 包含 citation_pdf_url
# PDF: //sci-hub.cat/storage/zero/7295/b6e10fab190565e277a2761c6d168781/mnih2015.pdf
```

但这个成功**不能稳定复现**——同一 session 内第二次请求就被 CAPTCHA 了。
