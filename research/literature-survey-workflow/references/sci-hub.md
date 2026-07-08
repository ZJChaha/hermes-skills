# Sci-Hub Access Reference

## Domain Status (tested 2026-07-08 from mainland China via WSL)

| Domain | Status | Notes |
|--------|--------|-------|
| `sci-hub.se` | ❌ TIMEOUT | Connection hangs, likely blocked/filtered |
| `sci-hub.st` | ⚠️ PARTIAL | Connects (2s) but returns "article not available" for many queries |
| `sci-hub.ru` | ⚠️ CAPTCHA | Connects (2s), finds the paper but returns anti-bot verification page |

## Anti-bot Protection

Sci-Hub now serves a captcha challenge ("I am not a robot") for programmatic requests (curl, Python urllib). The page title confirms the paper was found, but the PDF is gated behind the captcha.

**Workarounds**:
- **Manual browser download**: Open `https://sci-hub.ru/<DOI>` in a real browser. The captcha passes silently and the PDF loads. Save locally, then process with PyPDF2.
- **arXiv first**: Always prefer arXiv when the paper has a preprint — no anti-bot, no rate limits (beyond 1 req/3.5s).

## When to use Sci-Hub vs arXiv

- **arXiv**: Preprints of CS, math, physics, EE papers. Free, fast, no captcha. Use first.
- **Sci-Hub**: Paywalled papers (IEEE, Springer, Elsevier) with no arXiv preprint. Manual browser download required.

## URL format

```
https://sci-hub.ru/<DOI>
```

Example: `https://sci-hub.ru/10.1038/nature14236`
