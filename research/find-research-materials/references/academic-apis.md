# 学术论文搜索 API 参考

## OpenAlex API（首选 — 期刊论文/综述）

```
GET https://api.openalex.org/works?search=<query>&per_page=20&filter=type:article
```

特点：
- JSON 返回，结构清晰
- 覆盖期刊论文（ROAD, IEEE, Elsevier 等）
- 包含 `cited_by_count`（引用数），方便评估论文影响力
- 无明显限速，可连续调用
- 用 `execute_code` + `urllib.request` 调用

解析示例：
```python
import urllib.request, json

url = "https://api.openalex.org/works?search=dual+arm+manipulation&per_page=20"
req = urllib.request.Request(url, headers={"User-Agent": "mailto:research@example.com"})
with urllib.request.urlopen(req, timeout=30) as resp:
    data = json.loads(resp.read())

for item in data.get("results", []):
    title = item.get("title", "")
    year = item.get("publication_year", 0)
    doi = (item.get("doi") or "").replace("https://doi.org/", "")
    citations = item.get("cited_by_count", 0)
    
    source = (item.get("primary_location") or {}).get("source") or {}
    venue = source.get("display_name", "")
    
    authors = ", ".join([
        (a.get("author") or {}).get("display_name", "")
        for a in item.get("authorships", [])[:4]
    ])
```

过滤综述/评论：
```python
tl = title.lower()
is_survey = any(k in tl for k in [
    "survey", "review", "overview", "comprehensive", 
    "state of the art", "state-of-the-art", "taxonomy",
    "综述", "回顾", "概述", "进展"
])
```

## Crossref API（备选 — 期刊论文）

```
GET https://api.crossref.org/works?query=<query>&rows=20&filter=type:journal-article
```

特点：
- 通过 DOI 索引，覆盖几乎所有期刊
- 支持 `filter=from-pub-date:2020-01-01` 按年份过滤
- 响应较慢，偶尔 429（限速比 Semantic Scholar 宽松）

解析示例：
```python
import urllib.request, json, urllib.parse

url = f"https://api.crossref.org/works?query={urllib.parse.quote(query)}&rows=15&filter=type:journal-article"
req = urllib.request.Request(url, headers={"User-Agent": "Hermes/1.0 (mailto:research@example.com)"})
with urllib.request.urlopen(req, timeout=30) as resp:
    data = json.loads(resp.read())

for item in data.get("message", {}).get("items", []):
    title = item.get("title", ["?"])[0]
    year = item.get("published-print", {}).get("date-parts", [[0]])[0][0]
    doi = item.get("DOI", "")
    container = (item.get("container-title") or [""])[0]
    authors = ", ".join([
        f"{a.get('given','')} {a.get('family','')}"
        for a in item.get("author", [])[:4]
    ])
```

## arXiv API（预印本/前沿方法）

详见 SKILL.md 原有内容。用于找预印本和最新方法，不适合找综述。

## Semantic Scholar API（限速严格，最后手段）

```
GET https://api.semanticscholar.org/graph/v1/paper/search?query=<query>&limit=10&fields=title,year,authors,externalIds
```

限制：两三次查询后必 429。仅当其他 API 都失败时使用，每次查询间隔 ≥ 3 秒。
优先使用 OpenAlex 替代，两者覆盖范围相似但 OpenAlex 无限速。

## DBLP（不推荐）

经常返回 500 或空结果，CS 论文覆盖率不如 OpenAlex。不再使用。

## API 选择决策树

```
用户要什么？
├── 综述/Review/Survey → OpenAlex → Crossref（备选）
├── 最新方法/前沿 → arXiv → OpenAlex（补充）
├── 高引用经典 → OpenAlex（按 cited_by_count 排序）
├── 特定 DOI 论文 → Crossref（DOI 精确查）
└── 不确定 → OpenAlex + arXiv 并行，合并去重
```

## PDF 下载注意事项

- DOI 链接重定向到出版商（ScienceDirect/Springer），大部分有付费墙
- Semantic Scholar 的 `openAccessPdf` 字段可能提供免费 PDF
- 瑞典/欧洲大学的开放获取仓库（如 diva-portal.org）在国内可能被墙
- 如果下载失败，在汇总文档中列出 DOI，让用户自己下载
