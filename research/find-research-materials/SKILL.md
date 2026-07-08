---
name: find-research-materials
description: 帮用户搜索某方向的开源资料（GitHub仓库、论文），下载代码，整理成文档保存到指定目录。适用于"帮我找XX方向的入门资料"类请求。
---

# 研究资料搜集流程

## 触发条件
用户说"找资料"、"搜XX开源项目"、"入门资料"等。

## 步骤

### 1. 创建目标目录
```bash
mkdir -p "/mnt/d/目标路径"
```

### 2. 搜索 GitHub 仓库
用 `terminal` + `curl` 直接调 GitHub Search API（不需要 web_search 工具）：
```bash
curl -s "https://api.github.com/search/repositories?q=关键词&sort=stars&order=desc&per_page=15" | python3 -c "..."
```
- 分多轮搜索，每轮换不同关键词覆盖不同子方向
- 用 python3 内联脚本格式化输出：stars、full_name、url、description
- 已知热门仓库可直接 `curl https://api.github.com/repos/owner/repo` 获取详细信息

### 3. 搜索论文（arXiv API）
```bash
curl -s "http://export.arxiv.org/api/query?search_query=all:关键词&sortBy=relevance&max_results=15"
```

**核心策略：交叉领域 → 拆分搜索 (split-search)**
当用户要的论文横跨多个领域（如"双臂协作 + 空中操作 + 无人机"），一次搜索往往返回大量不相关结果或空结果。**一旦前两轮合并搜索效果差，立即拆分为各子方向独立搜索**，如用户明确指示"分开找"时务必照做：
- 方向A：关键词独立搜（如 `all:dual+arm+manipulation+robot`）
- 方向B：关键词独立搜（如 `all:aerial+manipulation+UAV`）
- **不要反复用复杂组合 query 死磕**，arXiv 的搜索引擎对多词 AND 逻辑支持不好
- 拆分搜索后，用 `execute_code` 并行搜多轮，去重合并结果

**搜索工具选择（按场景）**：

**找综述/期刊论文（Survey/Review）→ OpenAlex / Crossref**：
- arXiv 上几乎没有正式发表的综述论文（survey/review 通常发在期刊而非预印本）
- OpenAlex API (`api.openalex.org/works?search=...`)：返回 JSON，覆盖期刊论文，含引用数，无严格限速，是找综述的首选。用 `execute_code` + `urllib.request` 调用
- Crossref API (`api.crossref.org/works?query=...`)：备选，返回 JSON，通过 DOI 索引期刊论文
- 详见 `references/academic-apis.md`

**找预印本/前沿方法 → arXiv**：
- arXiv API：返回 Atom XML，用 `execute_code` + `xml.etree.ElementTree` 解析（比 bash 内联 python 可维护）
- 适合找最新方法论文（preprint），不适合找综述

**Semantic Scholar**：返回 JSON，结果质量好，但限速极严（两三次查询就 429）。仅在 arXiv 和 OpenAlex 都失败时用，且要加 delay。

**通用策略**：
- 如果用户明确要"综述/review/survey" → 跳过 arXiv，直接用 OpenAlex + Crossref
- 如果用户要"最新方法/前沿" → 用 arXiv
- 如果搜索面广 → 多 API 并行 + 去重合并
- `web_extract(urls=[\"https://arxiv.org/abs/ID\"])` 读取摘要页可能失败（取决于 extract_backend），直接用 API 返回的 summary 字段即可
- 注意：arXiv API 经常返回空，不要死磕；GitHub 上通常有关联论文链接
- 如果用户已有论文目录、需要分析方向后找类似论文并下载 → 见 `references/paper-expansion.md`
- 如果用户要求下载论文 PDF 并整理为概览文档 → 见 `references/paper-download-workflow.md`
- **双臂协作+空中操作控制方向论文搜索案例** → 见 `references/dual-arm-survey-search.md`（包含搜索策略、API选择、下载结果和教训）

### 4. 搜索中文资料
中文网站（知乎/CSDN/B站/博客园）有反爬，curl 大概率失败。策略：
- 如果域名是 `zhihu.com` / `csdn.net` / `bilibili.com` / `google.com` → 大概率超时或被拦
- **不要反复重试**（浪费时间和token）
- 改为在最终文档里列出推荐搜索关键词，让用户手动搜
- 如果 GitHub 搜到中文项目（如 datawhalechina/xxx），优先下载

### 5. GFW 网络问题（中国大陆）
在中国大陆从 WSL 搜论文时，以下工具**大概率失败**：
- `web_search` / `web_extract` → timeout / Network unreachable
- Semantic Scholar API → 429 (被墙或限速)
- Google Translate API → Network unreachable

**优先使用能从 WSL 直接访问的 API**：
1. **arXiv API** (`export.arxiv.org`) — 通常可直连，用 `execute_code` + `urllib` 调用
2. **Crossref API** (`api.crossref.org`) — 通常可直连，用 `execute_code` + `urllib` 调用
3. **OpenAlex API** (`api.openalex.org`) — 通常可直连，找综述/期刊论文首选

**如果以上都失败，有两层解决方案**：

**方案 A（推荐，一劳永逸）：WSL 镜像网络模式**
让 WSL 直接共享 Windows 的网络栈，VPN 在 WSL 内直接生效：
1. 创建/编辑 `C:\Users\<用户名>\.wslconfig`（WSL 路径: `/mnt/c/Users/<用户名>/.wslconfig`）
2. 写入：
   ```
   [wsl2]
   networkingMode=mirrored
   ```
3. 在 Windows PowerShell 执行 `wsl --shutdown`，重新打开 WSL

之后 VPN 直接在 WSL 里生效，curl、Python urllib 全部可用，无需任何代理配置。

**方案 B（临时）：Windows Python 代理执行**
如果不想重启 WSL，在 WSL 中通过 `powershell.exe` 调用 Windows 侧 Python，利用 Windows 网络栈（VPN 对其生效）：
- Windows Python 路径: `C:\Users\ZJC\AppData\Local\hermes\hermes-agent\venv\Scripts\python.exe`
- 执行: `powershell.exe -Command "python -u script.py"`
- PowerShell stdout 是 UTF-16 LE，写入文件后需用 `utf-16-le` 解码
- 参考 `github-push-from-wsl` 技能查看更多 Windows 工具执行模式

### 6. 下载代码包
用 `execute_code`（不要用 terminal，/mnt/d 跨文件系统慢容易超时）：
```python
import zipfile, os
from hermes_tools import terminal

save_dir = "/mnt/d/目标路径"
repos = [
    ("owner/repo", "https://github.com/owner/repo/archive/refs/heads/main.zip"),
]
for name, url in repos:
    terminal(f'curl -sL "{url}" -o "{save_dir}/{name}.zip" --connect-timeout 15 --max-time 120', timeout=130)
```
- 大文件（>100MB）逐个下载，避免超时

### 7. 解压并删除压缩包
用 `execute_code` + Python `zipfile` 模块（比 WSL 的 unzip 快，不超时）：
```python
import zipfile, os
base = "/mnt/d/目标路径"
for f in os.listdir(base):
    if f.endswith('.zip'):
        with zipfile.ZipFile(os.path.join(base, f), 'r') as zf:
            zf.extractall(base)
```
然后 `rm *.zip` 删除。

### 8. 下载论文 PDF
优先从以下源获取（按成功率排序）：
1. **arXiv** — `https://arxiv.org/pdf/{arxiv_id}`。如果 OpenAlex/Crossref 返回了 `arxiv_id`，直接下载
2. **开放获取仓库** — 部分期刊论文在 KTH Diva、HAL、机构库有免费版本。用 Unpaywall API 查找
3. **Sci-Hub** — 仅限付费论文。**重要：Sci-Hub 从 WSL 大概率被墙，告诉用户从 Windows 浏览器打开 `https://sci-hub.st/{DOI}` 下载**。不要尝试从 WSL 终端 curl Sci-Hub
4. **直接告诉用户** — 如果以上全失败，给出 DOI 链接让用户自己下载

**⚠️ 下载后必须验证**：用 pymupdf 打开 PDF，提取第一页标题，确认是否为目标论文。arXiv ID 可能猜错、Sci-Hub 可能返回错误论文。错误的 PDF 立即删除。

### 9. 生成汇总文档
用 `write_file` 写入 TXT 文档，包含：
- 分类：核心项目 / 教程 / Awesome List / 数据集 / 仿真平台 / 前沿变体
- 每个项目：名称、⭐数、GitHub链接、论文链接、简介
- 推荐学习路线
- 中文网站搜索关键词（因为自动抓不到）
- **标注哪些已下载、哪些未下载（含 DOI 供手动获取）**

## 核心原则
- GitHub API 是主要数据源，可靠且结构化
- execute_code 做所有 Python 处理，避免 bash 内联 Python 的引号转义问题
- /mnt/d 跨文件系统操作优先用 Python（zipfile、os），避免 shell 命令超时
- 中文网站搜不到就放弃，不要反复重试，改为列关键词给用户
- 下载和解压分开做，大文件给足超时时间
- **绝对不要尝试翻译 PDF 论文**：用户明确拒绝机器翻译结果（"翻译的不好，以后不让你翻译了"）。Google Translate / 任何自动化 PDF 翻译都不可用。只做搜索、下载、整理。
