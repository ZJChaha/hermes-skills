# Sci-Hub Access Reference

## Domain Status (tested 2026-07-08 from mainland China via WSL mirror networking)

| Domain | Status | Notes |
|--------|--------|-------|
| `sci-hub.st` | ✅ WORKING | Primary domain. Connects reliably, has good paper coverage. |
| `sci-hub.ru` | ❌ TIMEOUT | Was working but now unreachable. |
| `sci-hub.se` | ❌ TIMEOUT | Connection hangs, likely blocked/filtered. |

## Working Download Method (Two-Step)

Sci-Hub's HTML page has anti-bot protection, but the raw PDF storage URLs do NOT. The trick:

**Step 1 — Scrape the PDF URL from the HTML page meta tag:**
```bash
curl -sL --connect-timeout 30 \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
  "https://sci-hub.st/<DOI>" \
  | grep -oP 'pdf_url"\s*content="\K[^"]+'
```
This returns a path like `/storage/2024/7295/b6e10fab190565e277a2761c6d168781/mnih2015.pdf`

**Step 2 — Download the PDF directly (the storage URL has no captcha):**
```bash
curl -sL -o output.pdf \
  -H "User-Agent: Mozilla/5.0" \
  -H "Referer: https://sci-hub.st/<DOI>" \
  "https://sci-hub.st${PDF_PATH}"
```

**Python equivalent** — see `scripts/batch_scihub_download.sh` for the full batch workflow.

### Combined one-liner for batch use:

```bash
DOI="10.1017/S0263574719001450"
OUT="paper.pdf"
PAGE=$(curl -sL --connect-timeout 30 -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "https://sci-hub.st/$DOI")
PDF_PATH=$(echo "$PAGE" | grep -oP 'pdf_url"\s*content="\K[^"]+')
if [ -n "$PDF_PATH" ]; then
  curl -sL -H "User-Agent: Mozilla/5.0" -H "Referer: https://sci-hub.st/$DOI" \
    -o "$OUT" "https://sci-hub.st$PDF_PATH" && file "$OUT"
else
  echo "NOT ON SCI-HUB: $DOI"
fi
```

## Pitfalls

- **Referer header required**: The PDF storage endpoint checks Referer — omit it and download may fail.
- **sci-hub.st only**: All other domains (.ru, .se, .do, .ee, .tw) are down from mainland China (2026-07).
- **Verify PDFs**: Always check with `file` command. Some downloads are HTML error pages. Delete files < 50KB or where `file` says "HTML document".
- **Long timeouts**: sci-hub.st can take 30s on first request. Set `--connect-timeout 30` minimum.
- **Clean up failed downloads**: Remove empty/small files before next attempt.
- **WSL mirror networking required**: Without `networkingMode=mirrored` in `.wslconfig`, Sci-Hub unreachable from WSL.

- **"该文章在 Sci-Hub 上不可用"** — Paper not in Sci-Hub's database. Try arXiv, ResearchGate, or the publisher directly.
- **"未找到与您的请求匹配的文章"** — DOI not recognized. Check DOI is correct.
- **404 / timeout on PDF** — Paper found but PDF storage link expired. Retry once.

## When to use Sci-Hub vs arXiv

- **arXiv**: Preprints of CS, math, physics, EE papers. Free, fast, no captcha. Use first.
- **Sci-Hub**: Paywalled papers (IEEE, Springer, Elsevier) with no arXiv preprint. Use the two-step method.
- **ResearchGate**: Fallback for papers neither on arXiv nor Sci-Hub. May require login.

## URL format

```
https://sci-hub.st/<DOI>
```

Example: `https://sci-hub.st/10.1038/nature14236`
