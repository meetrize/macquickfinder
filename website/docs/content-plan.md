# MeoFind 宣传站 — 文案与素材清单

完整方案见仓库根目录 [`docs/website-plan.md`](../../docs/website-plan.md)。

## 首屏背景图

将制作好的首屏背景放入 `public/assets/`：

| 文件名 | 用途 | 建议规格 |
|--------|------|----------|
| `hero-bg.png` | 深色主题首屏背景（必需） | 2560×1440 或更宽，PNG/WebP |
| `hero-bg-light.png` | 浅色主题首屏背景（可选） | 同上；未提供时回退到 `hero-bg.png` |

放入文件后刷新页面即可显示；未放置时首屏保持纯色背景，不会出现裂图。

## 截图占位与文件名约定

将截图放入 `public/assets/screenshots/`，按下列文件名替换占位：

| 文件名 | 用途 | 建议画面 |
|--------|------|----------|
| `hero-main.png` | Hero 右侧主界面 | 完整三栏：侧边栏 + 列表 + 预览 |
| `browse-views.png` | 浏览区块 | 列表 / 缩略图切换 |
| `sidebar-devices.png` | 侧边栏 | 收藏夹 + 外置磁盘 |
| `preview-toolbar.png` | 预览 | 代码或 PDF 预览 + 工具栏 |
| `preview-browser.png` | 预览浏览器 | 底部胶片条 |
| `snippets-panel.png` | Snippets | 片段列表 + 执行 |
| `output-jobs.png` | 输出面板 | 多 Job 标签 + 命令输出 |
| `remote-server.png` | 远程 | 连接服务器 sheet |
| `layout-snap.png` | 布局 | 窗口贴靠半屏 |
| `settings-general.png` | 设置 | 语言 / 默认文件管理器 |

## 视频

| 文件名 | 用途 | 时长 |
|--------|------|------|
| `demo-main.mp4` | Hero / 演示区 | 60–90s |
| `demo-preview.mp4` | 预览专题 | 30–45s |

放入 `public/assets/videos/`，并在 `index.html` 中取消 video 注释。

## 演示项目（截图 / 录屏素材）

仓库内 [`MeoFind-Showcase/`](../../MeoFind-Showcase/) 提供开箱即用的演示目录：

- 示例 Swift / Python / Markdown / JSON / CSV / YAML
- 可导入的 `snippets-showcase.json`
- 截图清单 `docs/screenshot-checklist.md`
- 安装说明 `SETUP.md`

复制到 `~/Documents/` 后在 MeoFind 中打开并加入收藏夹即可开始截图。

## 版本与下载

编辑 `public/version.json`：

```json
{
  "version": "1.0",
  "releaseDate": "2026-06-29",
  "downloadUrl": "https://github.com/YOUR_ORG/macquickfinder/releases/latest",
  "minOS": "13.0"
}
```
