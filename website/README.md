# MeoFind 宣传网站

单页产品落地页，介绍 MeoFind 特性、截图与下载入口。

设计文档：[`docs/website-plan.md`](../docs/website-plan.md)  
素材清单：[`docs/content-plan.md`](docs/content-plan.md)

## 开发

```bash
cd website
npm install
npm run dev
```

浏览器打开 http://localhost:5173

右上角 **☀/🌙** 可切换浅色/深色外观，偏好会保存在本地；首次访问会跟随系统 `prefers-color-scheme`。

## 构建

```bash
npm run build
```

产物在 `website/dist/`，可部署到任意静态托管。

## 预览构建结果

```bash
npm run preview
```

## 更新下载链接

编辑 `public/version.json` 中的 `downloadUrl` 与 `version`。

## 补充截图

将 PNG/WebP 放入 `public/assets/screenshots/`，文件名见 `docs/content-plan.md`。
