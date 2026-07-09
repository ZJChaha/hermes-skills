---
name: literature-review
description: "Ultimate literature review pipeline: multi-platform search → download PDFs + code → generate overview MD → write survey paper (.docx). Covers papers, GitHub repos, Chinese sites, and network fallbacks."
version: 3.0.0
author: Hermes Agent
---

# Literature Review — 终极文献综述流水线

Six-stage pipeline: directory check → multi-platform search → download (papers + code) → overview MD → read & analyze → survey paper (.docx).

## 触发条件

- "找XX方向的论文" / "搜XX文献" / "帮我做XX文献综述"
- "找XX开源项目/入门资料/GitHub仓库"
- "下载XX论文并整理"
- 任何涉及学术文献搜索、下载、综述的请求

## ⚡ 入口分流（触发后首先判断）

根据用户意图，走不同分支。**必须在 Step 0 之前判断**：

```
用户请求
├── 🧠 检索/下载文献 (论文、综述、文献综述)
│   → Step 0 → Step 1(10平台搜索) → Step 2.1(论文PDF) → Step 3-5
│
└── 💻 查找开源资料/代码/GitHub项目
    → Step 0 → Step 1.11(GitHub搜索) → Step 2.2(代码下载) → Step 3(简化版MD)
```

**判断关键词**：
- **走文献分支**：论文、文献、综述、survey、review、paper、下载论文、搜文献、学术
- **走开源分支**：开源、代码、GitHub、项目、仓库、repo、入门资料、demo、源码、实现

**如果一句话里两者都有**（如"找XX方向的论文和开源代码"）→ 两条分支都走，先去文献分支搜论文，再去开源分支搜代码。

---

## Step 0: 确认下载目录（必须，搜索前执行）

**在开始任何搜索之前**，检查用户是否已指定下载目录。

- 已指定路径 → 直接使用，转 Step 1
- **未指定 → 立即 `clarify`**，不要猜测或默认：

```
clarify(question="请指定论文下载和文档保存的目录（例如 /mnt/d/论文/方向名/）：")
```

用户输入后再继续。此目录保存 PDF、代码包、文献概览 MD 和综述 docx。

---

## Step 1: 多平台搜索（10平台全覆盖）

**强制规则**：必须搜索所有适用的平台。一个平台 = 一类独特文献源，跳过 = 漏论文。搜索完成后逐项打勾自查。

### 10 搜索平台总表

| # | 平台 | 覆盖范围 | API / 方式 | 最适用 | 中国可达? |
|---|------|---------|-----------|--------|----------|
| 1 | **arXiv** | CS/Math/Physics/EE | XML API | 工程、机器人、AI | ✅ |
| 2 | **Semantic Scholar** | 全学科 | JSON API | 跨学科、引用数据 | ⚠️ 429限速 |
| 3 | **OpenAlex** | 全学科期刊 | JSON API | 综述、期刊论文 | ✅ |
| 4 | **Crossref** | 全学科期刊 | JSON API | 期刊论文（arXiv缺的） | ✅ |
| 5 | **MDPI** | 开放获取期刊 | web_search+API | 工程、传感器、机器人 | ⚠️ |
| 6 | **OA Library** | 开放获取聚合 | web_search | 跨学科OA | ⚠️ 可能403 |
| 7 | **PubMed** | 生物医学 | Entrez E-utilities | 医学、生物 | ✅ |
| 8 | **ncpssd** | 中文社科 | web_search(site:) | 中文社会科学 | ⚠️ |
| 9 | **medsci/梅斯** | 中文医学 | web_search(site:) | 中文医学 | ⚠️ |
| 10 | **web_search** | 全Web | DuckDuckGo | 补充、中文关键词 | ❌ 常超时 |

**按主题自动选平台**：
- 工程/机器人/AI → ①②③④⑤⑥⑩（全上，PubMed和中文社科跳过）
- 生物医学 → ⑦②③⑨
- 中文社科 → ⑧⑩
- 通用学术 → 全平台，仅跳过明显无关的

**执行自查清单**（Step 1 完成后逐项确认）：

```
□ arXiv      □ Semantic Scholar    □ OpenAlex
□ Crossref   □ MDPI                □ OA Library
□ PubMed(如适用)  □ ncpssd(如适用)  □ medsci(如适用)
□ web_search
```

### 1.1 arXiv API

```python
import urllib.request, urllib.parse, xml.etree.ElementTree as ET

ns = {'a': 'http://www.w3.org/2005/Atom', 'arxiv': 'http://arxiv.org/schemas/atom'}

def search_arxiv(query, max_results=12):
    encoded = urllib.parse.quote(query, safe='')
    url = f"https://export.arxiv.org/api/query?search_query={encoded}&max_results={max_results}&sortBy=relevance&sortOrder=descending"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    resp = urllib.request.urlopen(req, timeout=15)
    root = ET.parse(resp).getroot()
    papers = {}
    for entry in root.findall('a:entry', ns):
        arxiv_id = entry.find('a:id', ns).text.strip().split('/abs/')[-1]
        base_id = arxiv_id.split('v')[0]
        if base_id in papers: continue
        title = entry.find('a:title', ns).text.strip().replace('\n', ' ').replace('  ', ' ')
        published = entry.find('a:published', ns).text[:10]
        authors = ', '.join(a.find('a:name', ns).text for a in entry.findall('a:author', ns)[:5])
        summary = entry.find('a:summary', ns).text.strip()[:500]
        cats = ', '.join(c.get('term') for c in entry.findall('a:category', ns))
        papers[base_id] = {
            'title': title, 'authors': authors,
            'published': published, 'categories': cats,
            'abstract': summary, 'arxiv_id': arxiv_id, 'source': 'arxiv'
        }
    return list(papers.values())
```

- 关键词策略：`all:` 前缀 + 空格分隔，必须 `urllib.parse.quote()` 编码
- 多轮分裂搜索覆盖子方向，不要死磕单次复杂组合
- arXiv 上少有正式发表的综述（survey 多在期刊）→ 用 OpenAlex/Crossref 补

### 1.2 Semantic Scholar API

```python
url = f"https://api.semanticscholar.org/graph/v1/paper/search?query={urllib.parse.quote(q)}&limit=10&fields=title,authors,year,citationCount,externalIds,abstract"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
```

- **限速极严**：1 req/sec。遇 429 → 等 5 秒重试一次，再失败 → 跳过
- S2 结果中的 `externalIds.ArXiv` 和 `externalIds.DOI` 用于去重

### 1.3 OpenAlex API

```python
url = f"https://api.openalex.org/works?search={urllib.parse.quote(q)}&per_page=15&sort=cited_by_count:desc&filter=publication_year:2015"
```

- 找综述/期刊论文首选，无限速
- JSON 返回，`abstract_inverted_index` 需重组为文本
- `cited_by_count` 可用于判断论文影响力

### 1.4 Crossref API

```python
url = f"https://api.crossref.org/works?query={urllib.parse.quote(q)}&rows=10&filter=type:journal-article"
```

- **⚠️ Crossref 能找到 arXiv 完全遗漏的期刊论文**。2026-07-09 实测：双臂+空中操作搜索，arXiv 找到 0 篇期刊论文，Crossref 找到 5 篇（Mechatronics、IEEE Access、MDPI Machines 等）。永远同时跑 arXiv + Crossref。
- 返回 JSON，通过 DOI 索引

### 1.5 MDPI

```python
# 方案A: web_search
"aerial manipulation dual arm" site:mdpi.com

# 方案B: 直接 API (web_search 挂了时)
url = f"https://www.mdpi.com/search?q={'+'.join(urllib.parse.quote(w) for w in keywords)}&format=json"
```

MDPI 出版 Machines、Robotics、Sensors、Applied Sciences — 机器人方向覆盖率很高。

### 1.6 OA Library (oalib.com)

```python
url = f"https://www.oalib.com/search?q={urllib.parse.quote(query)}"
```
或 `site:oalib.com` via web_search。注意：部分区域返回 403。

### 1.7 PubMed Entrez API

```python
# Step 1: Search PMIDs
search_url = f"https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&retmax=15&term={urllib.parse.quote(query)}"
# Step 2: Fetch abstracts
fetch_url = f"https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id={','.join(pmids)}&rettype=abstract"
```

仅生物医学方向使用。3 req/sec（无 key），10 req/sec（有 key）。

### 1.8-1.9 中文平台 (ncpssd, medsci)

```
"关键词" site:ncpssd.org
"关键词" site:medsci.cn
```

中文社科/医学专用。工程方向通常跳过。

### 1.10 web_search

```
"dual arm aerial manipulation" survey
双臂协作 无人机 综述
```

⚠️ **中国大陆 DuckDuckGo 后端大概率超时** — 失败 2 次后停止，改为直接 API 调用。

### 1.11 GitHub 仓库搜索（开源资料搜集）

当用户需要开源代码/项目时：

```bash
curl -s "https://api.github.com/search/repositories?q=关键词&sort=stars&order=desc&per_page=15" | python3 -c "import json,sys; [print(f'{r[\"stargazers_count\"]}⭐ {r[\"full_name\"]}\n  {r[\"html_url\"]}\n  {r[\"description\"]}') for r in json.load(sys.stdin)['items']]"
```

- 分多轮搜索，不同关键词覆盖子方向
- 热门仓库直接 `curl https://api.github.com/repos/owner/repo` 获取详情
- 如果有论文方向的仓库（如 datawhalechina/xxx），优先下载

### 1.12 中文资料搜索策略

知乎/CSDN/B站/博客园有反爬，curl 大概率失败。策略：
- 不反复重试（浪费 token）
- 在最终文档里列推荐搜索关键词，用户手动搜
- GitHub 上搜到中文项目优先下载

### 1.13 去重合并

所有平台搜索完成后，按 `arxiv_id`（去掉 vN 后缀）和 `DOI` 去重。保留引用数最高的记录。

### 1.14 展示结果给用户确认

搜索完成后列出论文标题/作者/年份/来源，让用户确认哪些要下载，再进入 Step 2。

---

## Step 2: 下载

### 2.1 论文 PDF 下载

**优先级**（按成功率尝试）：

| 优先级 | 来源 | 方法 | 速度 |
|--------|------|------|------|
| 1 | **arXiv** | 直链 `arxiv.org/pdf/{id}` | 快，1 req/3.5s |
| 2 | **Sci-Hub** | 两步：抓 meta → 下 storage URL | 中，~3s |
| 3 | **MDPI / OA Library** | 开放获取直链 | 快 |
| 4 | **Library Genesis** | 搜 DOI → 下镜像 | 慢，需重试 |
| 5 | **科研通 (ablesci.com)** | 社区互助（手动） | 慢 |
| 6 | **全国图书馆参考咨询联盟** | 馆际互借（手动） | 慢 |
| 7 | **ResearchGate** | 常需登录 | 手动 |

#### arXiv 下载 ⚡ 先下到 /tmp 再 cp 到目标目录

```python
import urllib.request, shutil, os, tempfile

dest = "/mnt/e/目标目录"  # Step 0 的用户目录
os.makedirs(dest, exist_ok=True)

for i, (arxiv_id, short_name) in enumerate(papers):
    filename = f"{arxiv_id}_{short_name}.pdf"
    filepath = os.path.join(dest, filename)

    if os.path.exists(filepath) and os.path.getsize(filepath) > 500:
        print(f"[{i+1}/{len(papers)}] SKIP: {filename}")
        continue

    # ⚡ Download to /tmp (ext4) first, then copy to /mnt/
    # /mnt/ cross-filesystem I/O is 5-10x slower than ext4
    tmp = tempfile.NamedTemporaryFile(suffix='.pdf', delete=False)
    try:
        url = f"https://arxiv.org/pdf/{arxiv_id}"
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        data = urllib.request.urlopen(req, timeout=30).read()
        if len(data) < 500:
            raise Exception(f"Too small: {len(data)} bytes")
        tmp.write(data)
        tmp.close()
        shutil.copy(tmp.name, filepath)
        os.unlink(tmp.name)
        print(f"[{i+1}/{len(papers)}] OK: {filename} ({len(data)//1024} KB)")
    except Exception as e:
        tmp.close()
        os.unlink(tmp.name)
        print(f"[{i+1}/{len(papers)}] FAIL: {filename} — {e}")
```

- **不要加 time.sleep()** — PDF 直链无需限速，sleep 白耗时间
- 单文件超时 30s（大论文也够），不要设 60s+
- **终端 curl 也可用**: `curl -sL -o /tmp/x.pdf ... && cp /tmp/x.pdf "$DEST/"`
- 同理由：`execute_code` 超时通常不是网络问题，是 /mnt/ 写入慢

#### Sci-Hub（付费论文）⚠️ 成功率低，优先浏览器手动下载

Sci-Hub 的反爬在不断升级。两段法（抓 meta → 下 storage URL）**间歇性可用**：

| 域名 | 2026-07-08（昨晚） | 2026-07-09（今天） |
|------|-------------------|-------------------|
| `sci-hub.ru` | ✅ 能拿到论文页面+ `citation_pdf_url` | ❌ "are you a robot?" CAPTCHA |
| `sci-hub.st` | ⚠️ 连通但论文"不可用" | ❌ altcha 验证码 |
| `sci-hub.se` | ❌ 超时 | ❌ 超时 |

**结论**：Sci-Hub 反爬时松时严，不要依赖。优先尝试 `sci-hub.ru`（昨晚验证可用），成功时 meta 标签是 `citation_pdf_url`（不是旧的 `pdf_url`）。如果被 CAPTCHA 拦住，直接让用户浏览器手动下载。

⚠️ **技术细节**：用 terminal curl 而非 Python urllib（urllib 必被 CAPTCHA，curl 冷启动偶过）。详见 `references/sci-hub-techniques.md`。

#### Library Genesis

```bash
curl -s "https://libgen.is/scimag/?s=<DOI>" | grep -oP 'href="[^"]*\.pdf[^"]*"'
```

#### ⚠️ 下载后必须验证

用 PyPDF2 打开 PDF，检查第一页标题是否为目标论文。arXiv ID 可能猜错、Sci-Hub 可能返回错误论文。错误的立即删除。

**命名规范**：`{FirstAuthor}{Year}_{Short_English_Title}.pdf`（不要中文名，跨平台兼容）。

### 2.2 GitHub 代码包下载

⚡ **先下到 /tmp，再 cp 到目标目录**：

```python
import urllib.request, zipfile, shutil, os, tempfile

dest = "/mnt/d/目标路径"
os.makedirs(dest, exist_ok=True)

repos = [("owner/repo", "https://github.com/owner/repo/archive/refs/heads/main.zip")]

for name, url in repos:
    tmp = tempfile.NamedTemporaryFile(suffix='.zip', delete=False)
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        data = urllib.request.urlopen(req, timeout=60).read()
        tmp.write(data)
        tmp.close()
        with zipfile.ZipFile(tmp.name, 'r') as zf:
            zf.extractall(dest)
    finally:
        os.unlink(tmp.name)
```

或终端一行：`curl -sL "$URL" -o /tmp/x.zip && unzip -q /tmp/x.zip -d "$DEST" && rm /tmp/x.zip`

---

## Step 3: 生成文献信息概要 MD（自动，下载后立即执行）

**下载完成后自动生成**，不要等用户要求。用 `write_file` 写入 `{用户目录}/文献信息概要.md`。

### MD 结构模板

```markdown
# <主题方向> —— 文献信息概要

> 📅 整理日期: YYYY-MM-DD
> 🔍 搜索平台: arXiv / OpenAlex / Crossref / MDPI / ...
> 📄 共计: N 篇 | 已下载: M 篇 | 未获取: K 篇 | 代码仓库: L 个
> 💾 保存路径: /mnt/d/xxx/

---

## 📋 论文总览

| # | 年份 | 第一作者 | 标题 | 类型 | ID/DOI | PDF | 引用 |
|---|------|---------|------|------|--------|-----|------|
| 1 | 2023 | Zhang | ... | 方法 | 2301.xxxxx | ✅ | 45 |
| 2 | 2022 | Wang | ... | 综述 | 10.xxxx/xxx | ❌ | 451 |

---

## 🔑 各论文详细信息

### [1] arxiv_id — 论文完整标题
- **作者**: ...（全部列出）
- **发表时间**: YYYY-MM-DD | **类别**: cs.RO
- **来源**: arXiv / Crossref / OpenAlex
- **链接**: https://arxiv.org/abs/xxx
- **PDF 文件**: `xxx_shortname.pdf`
- **摘要（中文概括）**: 2-3 句话，要解决什么问题 + 用了什么方法 + 有什么亮点
- **关键词**: tag1, tag2, tag3

---

## 📊 分类汇总

### 🔬 综述论文 (Survey/Review)
- [N] ... ⭐

### 🎯 核心方法 (Core Methods)
- 子方向1: [N] [M] ...
- 子方向2: [N] ...

### 🛠️ 应用/系统 (Applications/Systems)
- [N] ...

### 💻 开源代码/项目 (GitHub)
- ⭐xxx owner/repo — 简介 — 链接

---

## 📖 推荐阅读顺序

1. 先读综述 → [N] [M] ... (了解全局)
2. 核心方法 → [N] ... (深入技术)
3. 子方向 → [N] ... (补充视角)

---

## 🏫 重点研究团队

| 团队/第一作者 | 机构 | 主要方向 | 代表论文 |
|-------------|------|---------|---------|

---

## 🔗 未获取论文（需手动下载）

| # | 标题 | DOI | 原因 |
|---|------|-----|------|

---

## 📝 搜索关键词回顾

- 英文: ...
- 中文: ...
- GitHub: ...
```

### 实现要点

- 摘要用中文 2-3 句概括
- PDF 列 ✅(已下载) / ❌(未获取)
- 未获取论文给出 DOI 供手动下载
- 代码仓库标注 ⭐ 数和链接

---

## Step 4: 阅读论文摘要与标题，建立全局理解

**不需要提取全文！** 用 PyPDF2 提取摘要+章节标题即可。

### 4a. 提取函数

```python
import sys
sys.path.insert(0, '/home/zjc/.hermes/hermes-agent/venv/lib/python3.14/site-packages')
from PyPDF2 import PdfReader

def extract_abstract_and_headings(filepath):
    reader = PdfReader(filepath)
    full_text = ""
    for page in reader.pages:
        full_text += (page.extract_text() or "") + "\n"

    lines = full_text.split('\n')
    headings, abstract_lines = [], []
    in_abstract = False

    for line in lines:
        s = line.strip()
        if not s: continue
        if s.lower().startswith('abstract'):
            in_abstract = True; continue
        if in_abstract:
            if (s[0].isdigit() and ('.' in s[:4])) or \
               s.lower().startswith(('introduction', 'keywords', 'index terms')):
                in_abstract = False
                headings.append(s); continue
            abstract_lines.append(s)
        if s[0].isdigit() and ('.' in s[:4]): headings.append(s)
        elif len(s) < 80 and s.isupper(): headings.append(s)
        elif s.lower().startswith(('chapter', 'section', 'appendix', 'reference', 'acknowledgment')):
            headings.append(s)

    return ' '.join(abstract_lines)[:2000], headings, len(reader.pages)
```

### 4b. 逐篇分析

```python
for pdf_name in sorted(os.listdir(pdf_dir)):
    if not pdf_name.endswith('.pdf'): continue
    abstract, headings, pages = extract_abstract_and_headings(os.path.join(pdf_dir, pdf_name))
    print(f"\n{'='*60}")
    print(f"📄 {pdf_name}  ({pages} pages)")
    print(f"{'='*60}")
    print(f"\n📝 ABSTRACT:\n{abstract[:1500]}")
    print(f"\n📑 SECTIONS:")
    for h in headings: print(f"   • {h}")
```

**每篇回答五个问题**：
1. 要解决什么问题？（Problem）
2. 提出的方法是什么？（Method）
3. 和本综述其他论文的关系？（Connection）
4. 实验/验证方式？（Evaluation）
5. 局限性？（Limitation）

### 4c. 跨论文综合分析

- **共享基础**：多篇论文共同引用的理论/框架
- **方法谱系**：谁基于谁、谁引用了谁
- **分歧/争论**：互相矛盾的观点
- **研究缺口**：文献集体缺失的部分
- **演进趋势**：早期→近期的发展脉络

---

## Step 5: 撰写综述论文 (.docx)

基于 Step 4 的分析，写综述。

安装依赖：`~/.hermes/hermes-agent/venv/bin/pip install python-docx`

### 文档结构（中文学术格式）

1. **标题页** — 标题、作者、日期
2. **摘要 + 关键词** — 200-300 字中文
3. **引言** — 研究背景、问题定义、本文贡献
4. **理论基础/背景** — 前置知识、共同框架
5. **核心方法综述** — 按子主题组织，对比不同方法
   - 5.1 方法类别A
   - 5.2 方法类别B
   - ...
6. **关键技术挑战** — 从 Step 4c 研究缺口展开
7. **应用前景**
8. **结论与展望**
9. **参考文献** — 编号引用

### 格式化代码

```python
from docx import Document
from docx.shared import Pt, Cm

doc = Document()
section = doc.sections[0]
section.page_width = Cm(21.0)
section.page_height = Cm(29.7)
section.left_margin = Cm(3.18)
section.right_margin = Cm(3.18)
section.top_margin = Cm(2.54)
section.bottom_margin = Cm(2.54)

style = doc.styles['Normal']
style.font.name = '宋体'
style.font.size = Pt(12)
style.paragraph_format.line_spacing = 1.5
style.paragraph_format.first_line_indent = Cm(0.74)

for i in range(1, 4):
    hs = doc.styles[f'Heading {i}']
    hs.font.name = '黑体'
    hs.font.bold = True
```

### 写作原则

- 中文撰写
- **按主题组织，不逐篇流水账** — 同主题下对比不同方法优劣
- 引用格式 `[1]`、`[2-5]`，对应文献概览编号
- 每个方法写清：思路 → 核心机制 → 优缺点
- 综述不是摘要翻译，是更高层次的归纳对比
- 保存到 `{用户目录}/综述_{主题}.docx`

---

## 🌐 网络问题处理（中国大陆）

### 从 WSL 能直连的 API（优先使用）

1. **arXiv API** (`export.arxiv.org`) — ✅ 通常直连
2. **Crossref API** (`api.crossref.org`) — ✅ 通常直连
3. **OpenAlex API** (`api.openalex.org`) — ✅ 通常直连
4. **GitHub API** (`api.github.com`) — ✅ 直连（WSL 镜像网络）

### 大概率失败的（不要死磕）

| 工具 | 现象 | 策略 |
|------|------|------|
| `web_search` | 超时 | 失败2次→停，改用直接API |
| `web_extract` | 超时/不可达 | 用API返回的摘要字段 |
| Semantic Scholar | 429 | 等5秒重试1次→跳过 |
| Sci-Hub | CAPTCHA | 所有域名加人机验证，告知用户浏览器手动下载 |
| 知乎/CSDN/B站 | 反爬 | 列搜索关键词给用户 |

### WSL 镜像网络模式（一劳永逸）

让 WSL 共享 Windows 网络栈，VPN 直接生效：

1. 创建/编辑 `C:\Users\<用户名>\.wslconfig`
2. 写入：
   ```
   [wsl2]
   networkingMode=mirrored
   ```
3. PowerShell 执行 `wsl --shutdown`，重开 WSL

之后所有 API 直连，无需代理配置。

### Windows Python 代理执行（临时方案）

```bash
powershell.exe -Command "python -u script.py"
```

Windows Python 路径: `C:\Users\ZJC\AppData\Local\hermes\hermes-agent\venv\Scripts\python.exe`

注意：PowerShell stdout 是 UTF-16 LE。

---

## ⚠️ Pitfalls（踩过的坑）

### 搜索
- **Crossref 能找到 arXiv 遗漏的期刊论文** — 永远同时跑 arXiv + Crossref
- arXiv `ti:` 对格式敏感 → 优先 `all:` 宽泛关键词
- 不要 `ti:"exact phrase"` 含特殊字符 → 400 错误
- URL 必须 `urllib.parse.quote()` 编码 — `urlopen` 不会自动编
- **停用 `web_search` 后不要循环重试** — 2次失败即切换策略
- Semantic Scholar 限速 1 req/sec — 429 后等5秒，再失败跳过
- 多平台结果去重用 `arxiv_id.split('v')[0]` + `DOI`

### 下载
- **/mnt/ 跨文件系统写入慢 5-10 倍** — 必须先下到 `/tmp`（ext4），再 `cp` 到目标目录。直接在 /mnt/ 写 PDF 会导致 execute_code 超时
- **不要加 time.sleep() 在 PDF 下载循环里** — arXiv 直链无限速，sleep 纯属浪费时间
- 单文件下载超时 30s 足够（大论文也够了），不要设 60s+
- **Sci-Hub 反爬时松时严** — 优先试 `sci-hub.ru`；meta 标签已改为 `citation_pdf_url`；被拦就浏览器手动下载
- **不要被 Sci-Hub 首页 200 OK 迷惑** — 首页无 CAPTCHA，但下论文时触发验证
- arXiv ID 不能猜 — 必须 API 搜索确认，猜错会下到无关论文
- 下载后必验证 — PyPDF2 检查第一页标题 + EOF marker
- 论文命名不要中文 — 跨平台兼容问题

### 综述写作
- **绝对不要翻译 PDF** — 用户拒绝机器翻译结果
- 综述不是摘要翻译 — 是归纳对比，不是流水账
- python-docx 按需安装 — pip 不在 PATH，用 venv 全路径

### 流程
- **必须先问目录再动手** — 不在未确认目录时开始搜索
- **必须搜索所有适用平台** — 10 个平台不是装饰，每个都有独特文献
- 中文网站搜不到就放弃 — 列关键词给用户，不反复重试
