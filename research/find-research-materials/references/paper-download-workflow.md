# 论文批量下载 + 概览文档生成

当用户说"把论文下载下来"、"整理成文档"时使用此流程。

## 步骤

### 1. 确定论文列表

从前面的搜索结果中收集所有目标论文：arxiv_id、简短英文描述（用作文件名）、作者、发表时间、摘要。

### 2. 批量下载 PDF

用 `execute_code`（不用 terminal，因为需要精确控制速率和错误处理）：

```python
import urllib.request, time, os

dest = "/mnt/e/目标目录/文献"  # Windows 路径用 /mnt/<盘符>/
os.makedirs(dest, exist_ok=True)

papers = [
    ("arxiv_id_1", "short_descriptive_name_1"),
    ("arxiv_id_2", "short_descriptive_name_2"),
    # ...
]

for i, (arxiv_id, short_name) in enumerate(papers):
    filename = f"{arxiv_id}_{short_name}.pdf"
    filepath = os.path.join(dest, filename)
    
    # 跳过已存在的文件（支持断点续传）
    if os.path.exists(filepath) and os.path.getsize(filepath) > 1000:
        print(f"[{i+1}/{len(papers)}] SKIP: {filename}")
        continue
    
    url = f"https://arxiv.org/pdf/{arxiv_id}"
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        resp = urllib.request.urlopen(req, timeout=60)
        data = resp.read()
        if len(data) < 500:
            raise Exception(f"文件太小: {len(data)} bytes")
        with open(filepath, 'wb') as f:
            f.write(data)
        print(f"[{i+1}/{len(papers)}] OK: {filename} ({len(data)/1024:.0f} KB)")
    except Exception as e:
        print(f"[{i+1}/{len(papers)}] FAIL: {arxiv_id} - {e}")
    
    # arXiv 限速：每 3.5 秒一个请求
    if i < len(papers) - 1:
        time.sleep(3.5)
```

**注意事项**：
- 必须添加 `User-Agent` header，否则 arXiv 可能拒绝
- 检查文件大小 > 500 bytes 防止下载到错误页面
- 跳过已存在文件，支持断点续传
- 3.5 秒间隔严格遵守 arXiv 限速（1 req / 3s）
- 文件命名：`{arxiv_id}_{简短英文名}.pdf`，不要用中文名（跨平台兼容）

### 3. 生成文献概览 Markdown 文档

用 `write_file` 写入，结构：

```markdown
# <主题> —— 文献概览

> 整理日期: YYYY-MM-DD
> 论文来源: arXiv
> 共计: N 篇

---

## 一、分类1
### [1] arxiv_id — 论文标题
- 作者 / 发表时间 / 类别
- arXiv 链接 + PDF 文件名
- 摘要（中文概括）
- 关键词

## 二、分类2
...

---

## 推荐阅读顺序
1. 先读综述 → ...
2. 核心方向 → ...
3. 子方向 → ...

## 重点研究团队
| 团队 | 机构 | 方向 |
```

**分类原则**：
- 直接相关的（精准命中用户主题）放前面
- 综述论文单独标注 ⭐
- 各子方向独立章节
- 不要把所有论文揉成一锅——用户会找不到重点

**摘要处理**：
- 用中文概括（用户群体是中国学生）
- 控制在 2-3 句以内
- 说清：要解决什么问题 + 用了什么方法 + 有什么亮点
