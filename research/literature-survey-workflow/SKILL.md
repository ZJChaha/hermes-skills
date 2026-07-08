---
name: literature-survey-workflow
description: "Search papers, download PDFs, generate overview, and write a survey paper in Word (.docx)."
version: 1.0.0
author: Hermes Agent
---

# Literature Survey Workflow

Four-step pipeline: search → download → overview → survey paper.

## Step 1: Search Papers

Use arXiv API (no key, simple curl/urllib). Search with multiple keyword combinations to maximize recall.

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

**Keyword strategy**:
- If the exact topic has few results, split into related sub-directions (e.g. "dual-arm aerial" → search "dual-arm manipulation" + "aerial manipulation" separately)
- Try `ti:`, `abs:`, `all:` prefixes
- For Chinese topics, also do web_search with Chinese keywords as supplement

**Also try Semantic Scholar** (returns JSON, better relevance):
```python
url = f"https://api.semanticscholar.org/graph/v1/paper/search?query={urllib.request.quote(q)}&limit=10&fields=title,authors,year,citationCount,externalIds,abstract"
```
Note: 1 req/sec rate limit. If 429, wait and retry.

Present results to user and confirm the list before downloading.

## Step 2: Download PDFs

Create target directory, then download with rate limiting (arXiv: 1 req / 3.5 sec).

```python
import time, os

dest = "/mnt/e/目标目录"
os.makedirs(dest, exist_ok=True)

for i, (arxiv_id, short_name) in enumerate(papers):
    filename = f"{arxiv_id}_{short_name}.pdf"
    filepath = os.path.join(dest, filename)
    url = f"https://arxiv.org/pdf/{arxiv_id}"
    
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    data = urllib.request.urlopen(req, timeout=60).read()
    with open(filepath, 'wb') as f: f.write(data)
    
    if i < len(papers) - 1:
        time.sleep(3.5)  # respect arXiv rate limit
```

**Naming convention**: `{arXiv_ID}_{Short_English_Name}.pdf`

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

When a paper is behind a paywall and has no arXiv preprint, Sci-Hub can be used as a last resort. See `references/sci-hub.md` for current domain status and anti-bot workarounds. In short: open `https://sci-hub.ru/<DOI>` in a real browser (curl gets blocked by captcha), save the PDF locally, then resume with PyPDF2 extraction.

## Pitfalls

- arXiv title search (`ti:`) is sensitive to formatting — prefer `all:` with broader keywords
- Don't use `ti:"exact phrase"` with special characters — it causes 400 errors
- Fuse 3 queries maximum when checking for duplicates using `split('v')[0]` on arXiv IDs
- `pip` may not be on PATH — always use `~/.hermes/hermes-agent/venv/bin/pip`
- PyPDF2 is already installed; python-docx needs to be installed per-session
