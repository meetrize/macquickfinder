# MeoFind Showcase 安装说明

## 1. 复制到常用位置

```bash
cp -R /path/to/macquickfinder/MeoFind-Showcase ~/Documents/
```

## 2. 在 MeoFind 中打开

1. 启动 MeoFind
2. `⌘O` 或路径栏输入 `~/Documents/MeoFind-Showcase`
3. 右键根目录 → **加入收藏夹**

## 3. 导入 Snippets

1. 打开 Snippets 面板（`⌘⇧S`）
2. 点击 **⋯** → **导入…**
3. 选择 `snippets-showcase.json`
4. 若有冲突，选择 **重命名** 或 **跳过**（内置片段同名时）

## 4. 可选：补充媒体文件

```bash
# PDF（已包含在 releases/MeoFind-v1.0.pdf，也可重新生成）
# python3 Scripts/generate-meofind-brochure-pdf.py

# 横版 banner（可从 logo 扩展）
# 放入 assets/hero-banner.jpg

# 短视频 / 音频
# 放入 media/demo-screencast.mp4
# 放入 media/intro-audio.mp3
```

## 5. Git 演示（可选）

Snippet **Git 状态** 需要在演示目录内初始化 Git：

```bash
cd ~/Documents/MeoFind-Showcase
git init
git add -A
git commit -m "chore: 初始化演示项目"
```

之后运行该 Snippet 即可得到真实的 `git status -sb` 输出。

## 6. 截图输出位置

截完成后，按文件名放入：

```
macquickfinder/website/public/assets/screenshots/
```

详见 `docs/screenshot-checklist.md`。
