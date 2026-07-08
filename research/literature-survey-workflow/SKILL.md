---
name: literature-survey-workflow
description: "Search papers, download PDFs, generate overview, and write a survey paper in Word (.docx)."
version: 1.0.0
author: Hermes Agent
---

# Literature Survey Workflow

Four-step pipeline: search → download → overview → survey paper.

## Step 1: Search Papers

Multi-platform search to maximize coverage. **Always use 2+ platforms** for any non-trivial topic.

### Platform summary

| # | Platform | Scope | API | Best for |
|---|----------|-------|-----|----------|
| 1 | **arXiv** | CS, Math, Physics, EE | XML API, no key | Engineering, robotics, AI |
| 2 | **Semantic Scholar** | All academic fields | JSON API, no key | Cross-discipline, citation data |
| 3 | **PubMed** | Biomedicine, life sciences | Entrez E-utilities | Medical, biology |
| 4 | **MDPI** | Open access journals | Web search | Engineering, sensors, materials |
| 5 | **OA Library** | Open access aggregator | Web search | Cross-discipline OA papers |
| 6 | **国家哲学社会科学文献中心** | 中文社科文献 | Web search | Chinese social sciences |
| 7 | **MedSci/梅斯** | 中文医学期刊 | Web search | Chinese medical literature |
| 8 | **web_search** | All | DuckDuckGo | Supplementary, Chinese keywords |

### 1. arXiv API (primary for CS/EE/robotics)

```python
import urllib.request
import xml.etree.ElementTree as ET

ns = {'a': 'http://www.w3.org/2005/Atom', 'arxiv': 'http://arxiv.org/schemas/atom'}

def search_arxiv(query, max_results=12):
    url = f"https://export.arxiv.org/api/query?search_query={query}&max_results={max_results}&sortBy=submittedDate&sortOrder=descending"
    resp = urllib.request.urlopen(url, timeout=15)
    root = ET.parse(resp).getroot()
    papers = {}
    for entry in root.findall('a:entry', ns):
        arxiv_id = entry.find('a:id', ns).text.strip().split('/abs/')[-1]
        base_id = arxiv_id.split('v')[0]
        if base_id in papers: continue
        title = entry.find('a:title', ns).text.strip().replace('\n', ' ').replace('  ', ' ')
        published = entry.find('a:published', ns).text[:10]
        authors = ', '.join(a.find('a:name', ns).text for a in entry.findall('a:author', ns)[:5])
        summary = entry.find('a:summary', ns).text.strip()[:300]
        cats = ', '.join(c.get('term') for c in entry.findall('a:category', ns))
        papers[base_id] = {'title': title, 'authors': authors,
            'published': published, 'categories': cats,
            'abstract': summary, 'arxiv_id': arxiv_id}
    return list(papers.values())
```

### 2. Semantic Scholar API (cross-discipline, JSON)

```python
url = f"https://api.semanticscholar.org/graph/v1/paper/search?query={urllib.request.quote(q)}&limit=10&fields=title,authors,year,citationCount,externalIds,abstract"
```
Note: 1 req/sec rate limit. If 429, wait and retry.

### 3. PubMed Entrez API (biomedical)

```python
import urllib.request, xml.etree.ElementTree as ET
# Step 1: Search for PMIDs
search_url = f"https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&retmax=15&term={urllib.request.quote(query)}"
# Step 2: Fetch details
fetch_url = f"https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id={','.join(pmids)}&rettype=abstract"
```
Note: 3 req/sec without API key, 10 req/sec with key (register at NCBI).

### 4-7. Platform-specific web_search

For platforms without structured APIs, use web_search with `site:` prefix:

```
"keyword1 keyword2" site:mdpi.com
"关键词" site:ncpssd.org
"keyword" site:medsci.cn
"keyword" site:oalib.com
```

### 8. General web_search

Use for:
- Chinese keywords (e.g., "双臂协作机器人 综述")
- Finding papers missed by structured APIs
- Cross-validation

**Keyword strategy**:
- If the exact topic has few results, split into related sub-directions
- Try `ti:`, `abs:`, `all:` prefixes on arXiv
- Mix English + Chinese keywords for Chinese platforms
- Combine results across platforms, deduplicate by DOI/arXiv ID

Present results to user and confirm the list before downloading.

## Step 2: Download PDFs

**Download priority** (try in order):

| Priority | Source | Method | Speed |
|----------|--------|--------|-------|
| 1 | **arXiv** | Direct PDF link | Fast, 1 req/3.5s |
| 2 | **Sci-Hub** | Two-step (scrape meta → download storage URL) | Medium, ~3s |
| 3 | **MDPI / OA Library** | Open access direct download | Fast |
| 4 | **Library Genesis** | Search DOI → download mirror | Slow, may need retry |
| 5 | **科研通 (ablesci.com)** | Community paper request (manual) | Slow, human-dependent |
| 6 | **全国图书馆参考咨询联盟** | Library document delivery (manual) | Slow, human-dependent |
| 7 | **ResearchGate** | Often blocked, needs browser login | Manual |

### arXiv download (preferred)
```python
import time, os

dest = "/mnt/e/目标目录"
os.makedirs(dest, exist_ok=True)

for i, (arxiv_id, short_name) in enumerate(papers):
    filename = f"{arxiv_id}_{short_name}.pdf"
    url = f"https://arxiv.org/pdf/{arxiv_id}"
    
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    data = urllib.request.urlopen(req, timeout=60).read()
    with open(os.path.join(dest, filename), 'wb') as f: f.write(data)
    
    if i < len(papers) - 1:
        time.sleep(3.5)  # respect arXiv rate limit
```

### Sci-Hub download (paywalled papers)
See `references/sci-hub.md`. Two-step: scrape `sci-hub.st/<DOI>` for `<meta property="pdf_url">`, then download that storage URL with Referer header.

### Library Genesis (libgen)
Search by DOI. Domain may change — try `libgen.is`, `libgen.li`, `libgen.gs`, `libgen.st`.
```bash
# Search by DOI on libgen
curl -s "https://libgen.is/scimag/?s=<DOI>" | grep -oP 'href="[^"]*\.pdf[^"]*"'
```

### 科研通 (ablesci.com)
Chinese paper-request community. Post a request with DOI, other users fulfill it. Requires account. Use as last resort for hard-to-find Chinese papers.

### 全国图书馆参考咨询联盟 (ucdrs.superlib.net)
Chinese library consortium. Can request document delivery for papers in Chinese library databases. Manual process, good for CNKI/万方 papers not on Sci-Hub.

**Naming convention**: `{FirstAuthor}{Year}_{Short_English_Title}.pdf`

## Step 3: Generate Literature Overview (.md)

Create a markdown file cataloging all papers with:
- Numbered list with arXiv ID, title, authors, date, categories
- Short Chinese summary (1-2 sentences)
- Keywords
- arXiv link and PDF filename reference
- Recommended reading order
- Key research teams table

Save to the same directory as PDFs. See the arxiv skill for parsing details.

## Step 4: Read Full Papers and Understand

Read EVERY page of each key paper — not just abstract/intro. Use PyPDF2 (already installed in Hermes venv).

### 4a. Extract Full Text

```python
import sys
sys.path.insert(0, '/home/zjc/.hermes/hermes-agent/venv/lib/python3.14/site-packages')
from PyPDF2 import PdfReader

def extract_full_paper(filepath):
    """Extract all text from a PDF and return structured sections."""
    reader = PdfReader(filepath)
    full_text = ""
    for page in reader.pages:  # ALL pages — not just first 8
        text = page.extract_text() or ""
        full_text += text + "\n"
    return full_text, len(reader.pages)
```

### 4b. Understand Each Paper

For each key paper, after extracting the full text, produce a structured summary:

```python
# For each key paper, read and understand:
for pdf_name in key_papers:
    filepath = os.path.join(pdf_dir, pdf_name)
    full_text, total_pages = extract_full_paper(filepath)
    
    # Print structured analysis for me (the agent) to use when writing the survey:
    print(f"\n{'='*60}")
    print(f"PAPER: {pdf_name}  |  PAGES: {total_pages}")
    print(f"{'='*60}")
    
    # Key sections to identify and summarize:
    # - Problem statement / motivation
    # - Related work (what this paper builds on)
    # - Proposed method (algorithm, architecture, design)
    # - Experimental setup and results
    # - Key contributions and limitations
    # - Connections to other papers in the survey
    
    # Print a substantial portion so the agent can truly understand the content
    print(full_text[:12000])  # Print first 12000 chars (~3000 words)
    if len(full_text) > 12000:
        print(f"\n... [truncated, {len(full_text)} total chars, {total_pages} pages]")
        # Also extract methodology and conclusion sections if identifiable
```

### 4c. Cross-Paper Understanding

After reading all papers, identify cross-cutting themes:

- **Shared foundations**: theories, frameworks cited by multiple papers (e.g. Franchi's medium-aware framework)
- **Methodological lineage**: which papers build on / respond to which others
- **Contradictions / debates**: where papers disagree or propose competing approaches
- **Gaps**: what the collective literature does NOT address
- **Progression**: how the field evolved from earlier to recent work

This cross-paper understanding is critical for writing a coherent survey that goes beyond paper-by-paper summaries.

## Step 5: Write Survey Paper (.docx)

Use `python-docx` (install: `~/.hermes/hermes-agent/venv/bin/pip install python-docx`).

**Document structure** (Chinese academic format):
1. Title page (title, author, date)
2. 摘要 + 关键词
3. 引言 (motivation, problem statement, contribution)
4. 理论基础 / 背景 (theoretical foundations)
5. 核心方法综述 (main technical content, organized by sub-themes)
6. 关键技术挑战 (key challenges)
7. 应用前景 (applications)
8. 结论与展望 (conclusion + future directions)
9. 参考文献 (numbered references)

**Formatting**:
```python
from docx import Document
from docx.shared import Pt, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH

doc = Document()
# Page margins: A4 standard
section.left_margin = Cm(3.18)
section.right_margin = Cm(3.18)
section.top_margin = Cm(2.54)
section.bottom_margin = Cm(2.54)

# Body style: 宋体 12pt, 1.5 line spacing, first-line indent
style = doc.styles['Normal']
style.font.name = '宋体'
style.font.size = Pt(12)
style.paragraph_format.line_spacing = 1.5
style.paragraph_format.first_line_indent = Cm(0.74)

# Headings: 黑体 bold
heading.font.name = '黑体'
```

**Tips**:
- Write in Chinese, using the extracted paper content as source material
- Use `execute_code` for the entire docx creation script (not terminal)
- Save to user's desktop: `/mnt/c/Users/ZJC/Desktop/综述标题.docx`
- Reference citations should use the numbering from the downloaded paper list

## Fallbacks

If web_search times out (common with DuckDuckGo backend): try multiple query formulations, or rely solely on arXiv API results.
If web_extract fails: use PyPDF2 on downloaded PDFs instead.
If Semantic Scholar hits 429: wait 5 seconds and retry once.

### Sci-Hub for Paywalled Papers

When a paper is behind a paywall and has no arXiv preprint, use Sci-Hub's **two-step download** (detailed in `references/sci-hub.md`):

1. Fetch `https://sci-hub.st/<DOI>` and extract `pdf_url` from `<meta property="pdf_url">`
2. Download the PDF directly from that storage URL with a `Referer` header

The PDF storage URLs have no anti-bot protection — only the HTML page does. This fully automates Sci-Hub downloads.

**Batch download** via `scripts/batch_scihub_download.sh`:
```bash
# Prepare a DOI list (one per line: "DOI  ShortName")
echo "10.1017/S0263574719001450 Meng2019_Aerial" > /tmp/dois.txt
echo "10.1109/LRA.2022.3196158 Krebs2022" >> /tmp/dois.txt

bash scripts/batch_scihub_download.sh /mnt/e/目标目录 /tmp/dois.txt
```

**Fallback**: If Sci-Hub doesn't have the paper, try ResearchGate or the publisher's open-access page.

## Pitfalls

- arXiv title search (`ti:`) is sensitive to formatting — prefer `all:` with broader keywords
- Don't use `ti:"exact phrase"` with special characters — it causes 400 errors
- Fuse 3 queries maximum when checking for duplicates using `split('v')[0]` on arXiv IDs
- `pip` may not be on PATH — always use `~/.hermes/hermes-agent/venv/bin/pip`
- PyPDF2 is already installed; python-docx needs to be installed per-session
