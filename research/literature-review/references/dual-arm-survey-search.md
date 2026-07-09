# 双臂协作 + 空中操作 综述搜索策略


## 搜索策略（2026-07-08 验证有效）

### 第一步：OpenAlex 主搜索（找综述）
OpenAlex 覆盖期刊论文，含引用数，无限速。搜索 query 覆盖：
- `dual arm robot control survey review`
- `aerial manipulation UAV control survey review`
- `bimanual manipulation control survey`
- `双臂 协作 机器人 控制 综述`
- `空中 操作 无人机 控制 综述`

过滤条件：标题含 survey/review/综述，且含 dual arm / bimanual / aerial manipulation 等关键词。

### 第二步：OpenAlex 精准补充
- `dual arm coordination control survey`
- `aerial manipulation control review survey`
- `双臂 协调 控制 综述 机器人`
- `cooperative manipulation control review`

限定 `year >= 2018` 避免太旧的论文。

### 第三步：Crossref 补充
Crossref 做中文和备选英文搜索。去重合并。

### 关键发现
- **Meng 2019** — "Survey on Aerial Manipulator: System, Modeling, and Control" — 控制方向最佳综述（中科院）
- **Smith 2012** — "Dual Arm Manipulation—A Survey" — 经典双臂综述（551引用）
- **Franchi 2026** — arXiv:2607.04719 — 空中操作最新理论框架
- **Suomalainen 2022** — "A Survey of Robot Manipulation in Contact" — 接触操作（力控核心）

### NOT found
- "双臂阻抗控制综述" — 该子方向无专门综述
- "双臂力位混合控制综述" — 无
- "自适应空中操作控制综述" — 无

## PDF 下载结果

| 论文 | 来源 | 状态 |
|------|------|------|
| Franchi 2026 | arXiv:2607.04719 | ✅ 下载 |
| Smith 2012 | KTH Diva (Open Access) | ✅ 下载 |
| Suomalainen 2022 | arXiv:2112.01942 | ✅ 下载 |
| Meng 2019 | Robotica 期刊 | ❌ 付费（DOI: 10.1017/S0263574719001450） |
| Krebs 2022 | IEEE RA-L | ❌ 付费（DOI: 10.1109/LRA.2022.3196158） |
| Mohiuddin 2019 | Unmanned Systems | ❌ 付费（DOI: 10.1142/S2301385020500089） |

## 教训
1. **arXiv ID 不能猜**：Krebs 和 Meng 的 arXiv ID 猜错，下载了完全无关的论文。必须先通过 arXiv API 搜索确认 ID
2. **下载后必须验证**：用 pymupdf 打开 PDF 检查第一页标题
3. **Sci-Hub 走 Windows 浏览器**：WSL 终端 curl 全失败，但用户从 Windows 浏览器用 VPN 可以访问
4. **期刊综述不在 arXiv**：大部分综述论文发在期刊（IEEE/Elsevier），arXiv 上没有预印本
