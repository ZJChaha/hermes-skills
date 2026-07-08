# Paper Collection Expansion: Analyze → Categorize → Search → Download

Use this when the user has a directory of existing papers and wants to:
- Understand what research direction they cover
- Find similar/related papers from open-access sources (arxiv)
- Download them to the same directory

## Step 1: Extract text from local PDFs (batch)

Use `execute_code` with pymupdf, not terminal. Install if needed:

```bash
~/.hermes/hermes-agent/venv/bin/pip install pymupdf
```

Then batch-extract first few pages (abstract + intro) from all PDFs:

```python
import pymupdf, os

dir_path = "/mnt/e/目标目录"
for pdf_file in os.listdir(dir_path):
    if not pdf_file.endswith('.pdf'): continue
    doc = pymupdf.open(os.path.join(dir_path, pdf_file))
    text = ""
    for i in range(min(5, len(doc))):
        text += doc[i].get_text()
    # Analyze text[:3000] for research direction
    doc.close()
```

## Step 2: Categorize research directions

From titles and abstracts, group papers into sub-directions (e.g., flight control, state estimation, trajectory planning, obstacle avoidance, aerial manipulation). Present a summary table to the user.

## Step 3: Search for similar papers by sub-topic

Use `web_search` with `site:arxiv.org` prefix, one search per sub-direction:

```
site:arxiv.org quadrotor trajectory planning autonomous exploration 2024 2025
site:arxiv.org UAV state estimation multi-sensor fusion IMU visual SLAM 2024
site:arxiv.org multi-UAV cooperative obstacle avoidance dynamic environment 2024
```

Collect arxiv IDs (format: XXXX.XXXXX) from search results.

## Step 4: Download arxiv PDFs

Use terminal with curl — arxiv PDFs are at `https://arxiv.org/pdf/XXXX.XXXXX`:

```bash
cd "/mnt/e/目标目录" && \
curl -sL -o "Descriptive_Name.pdf" "https://arxiv.org/pdf/2606.01038" -w "  [%{http_code}] %{filename_effective}\n"
```

- Always use `-sL` (silent + follow redirects)
- Use `-w` to print HTTP status code for verification
- Name files descriptively in English (easier for search)
- Download 3-4 at a time (parallel in one terminal call is fine for arxiv)

## Step 5: Verify downloads

Check file sizes — arxiv PDFs should be >100KB. Anything smaller may be an error page:

```bash
ls -lh /mnt/e/目标目录/*NewlyDownloaded*.pdf
```

## Pitfalls

- arXiv API (`export.arxiv.org`) often returns empty. Don't use it — use `web_search` to discover arxiv papers, then download PDFs directly via `arxiv.org/pdf/ID`.
- Chinese academic PDFs (like 广东工业大学 theses) often have garbled text from pymupdf due to embedded fonts. The title page and abstract usually extract fine — focus on those.
- Don't use `web_extract` for local PDFs — it only works with URLs.
