# MeoFind Showcase

演示专用示例项目，用于 **截图、录屏与宣传站素材**。

> 建议将整个目录复制到 `~/Documents/MeoFind-Showcase/`，在 MeoFind 侧边栏 **收藏夹** 中固定该路径，所有截图在同一目录下完成。

## 特性一览

| 模块 | 演示文件 |
|------|----------|
| 代码预览 | `src/main.swift`、`src/AppModule.swift` |
| Python | `src/utils/helpers.py` |
| Markdown | 本文件、`docs/architecture.md` |
| JSON / YAML / CSV | `package.json`、`data/config.yaml`、`data/users.csv` |
| 图片 | `assets/logo.png` |
| PDF | `releases/MeoFind-v1.0.pdf`（产品宣传文档） |
| 压缩包 | `archives/project-backup.zip` |
| Snippets | `snippets-showcase.json`（导入 MeoFind） |

## 快速开始

```bash
# 1. 复制到文稿（可选）
cp -R MeoFind-Showcase ~/Documents/

# 2. 在 MeoFind 中打开 ~/Documents/MeoFind-Showcase

# 3. 导入演示 Snippets
#    Snippets 面板 → ⋯ → 导入… → 选择 snippets-showcase.json

# 4. 将目录加入收藏夹（右键 → 收藏）
```

## 推荐截图流程

1. 打开 `README.md` → 右侧 Markdown 预览（`hero-main.png`）
2. 选中 `src/main.swift` → 代码高亮 + 工具栏（`preview-toolbar.png`）
3. 切换缩略图视图浏览 `assets/`（`browse-views.png`）
4. 运行 Snippet「复制路径」→ 输出面板 Job（`output-jobs.png`）
5. 展开 Preview Browser 切换文件（`preview-browser.png`）

完整清单见 [`docs/screenshot-checklist.md`](docs/screenshot-checklist.md)。

## 技术栈（虚构示例）

- Swift / SwiftUI — 主应用
- Python 3 — 工具脚本
- Shell — Snippets 自动化

---

*本目录为演示数据，不含真实用户或密钥信息。*
