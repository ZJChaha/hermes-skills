# Sci-Hub Access Reference

## ⚠️ 2026-07-09 STATUS: BROKEN FROM WSL TERMINAL

All Sci-Hub domains now require CAPTCHA verification. Programmatic download from terminal/curl/Python is **no longer possible**.

| Domain | Status | Details |
|--------|--------|---------|
| `sci-hub.ru` | ❌ CAPTCHA | "are you a robot?" — cold start sometimes bypasses, but 2nd request always blocked |
| `sci-hub.st` | ❌ CAPTCHA | altcha widget, "你是机器人吗？" |
| `sci-hub.se` | ❌ TIMEOUT | Connection hangs |

**Only working method**: User opens `https://sci-hub.ru/{DOI}` in Windows browser, solves CAPTCHA manually, downloads PDF.

## Historical (NO LONGER WORKS)

The "two-step method" described below worked before CAPTCHA was added (~2025 and earlier):

1. Scrape `sci-hub.ru/<DOI>` for `<meta name="citation_pdf_url">` (note: meta tag name changed from `pdf_url` to `citation_pdf_url`)
2. Download from the storage URL with `Referer` header

This method is now broken because the HTML page itself is blocked by CAPTCHA — you never reach step 1.

## When Sci-Hub fails

- **arXiv**: Check if paper has a preprint — many journal papers have arXiv versions
- **Open Access**: Some papers are OA via MDPI, institutional repositories (KTH Diva, HAL, etc.)
- **Browser manual**: Tell user to open `sci-hub.ru/{DOI}` in Windows browser
- **ResearchGate**: Authors sometimes upload PDFs
- **Library Genesis**: `libgen.is` may have the paper (search by DOI)
