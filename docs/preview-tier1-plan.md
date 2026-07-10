# Tier 1 格式预览 — 开发计划

> 依据：[preview-format-tech-evaluation.md](./preview-format-tech-evaluation.md)  
> 关联：[file-format-support-analysis.md](./file-format-support-analysis.md)  
> 目标：补齐 Tier 1 缺失的 8 类格式预览，总净增约 **1,100 行**，分 **5 步**交付。  
> 预估工期：**3.5–5 个工作日**（单人全职）。

---

## 总览

| 阶段 | 主题 | 格式 | 预估 | 净增行数 | 用户可见 |
|------|------|------|------|---------|---------|
| **T0** | 零成本文本扩展 + RTF | toml / srt / vtt / gpx / rtf | 0.5 天 | ~30 行 | 是 |
| **T1** | 电子书预览 | epub | 0.5 天 | ~300 行 | 是 |
| **T2** | 邮件预览 | eml | 0.5 天 | ~260 行 | 是 |
| **T3** | 压缩包扩展 | rar / 7z | 1–2 天 | ~150–200 行 | 是 |
| **T4** | 字体预览 | ttf / otf（woff2 延后） | 1 天 | ~330 行 | 是 |

原则：

- 每步独立 PR，合并后 `swift build` + 相关 `swift test` 通过。
- 复用现有七层管线，不重构 `PreviewSession` 骨架。
- 新增用户可见文案遵守 `.cursor/rules/i18n-ui-strings.mdc`（`Localizable.xcstrings` + `L10n.swift` + `L10nTests`）。
- **明确不做**：mobi（第二期）、srt/vtt/gpx 地图可视化（第二期）、woff2（T4 子阶段）。

---

## 现有预览管线（改动对照）

```
文件扩展名
  │
  ▼
BuiltinPreviewExtensions (L1 声明)
  │
  ▼
PreviewLoadDispatch.resolve() → PreviewLoadRoute (L2 路由)
  │
  ▼
PreviewSession.loadContent() (L3 加载)
  │
  ▼
PreviewLoadPayload (L4 数据)
  │
  ▼
PreviewSessionContentState (L5 状态)
  │
  ▼
FileContentView.body (L6 渲染)
  │
  ▼
ThumbnailGenerator (L7 缩略图，部分格式需自定义)
```

| 层 | 文件 | 本计划涉及 |
|----|------|-----------|
| L1 声明 | `CustomPreviewRuleStore.swift` → `BuiltinPreviewExtensions` | T0–T4 全部 |
| L2 路由 | `PreviewLoadRoute.swift` / `PreviewLoadDispatch` | T0(rtf) / T1(epub) / T2(eml) / T4(font) |
| L3 加载 | `PreviewSession+Loading*.swift` | T0(rtf) / T1–T4 |
| L4 数据 | `PreviewLoadPayload.swift` | T1 / T2 / T4 |
| L5 状态 | `PreviewSessionNestedState.swift` | T1 / T2 / T4 |
| L6 渲染 | `FileContentView.swift` | T0(rtf) / T1–T4 |
| L7 缩略图 | `ThumbnailGenerator.swift` | T3（rar/7z 需自定义，~30 行） |

---

## T0：零成本文本 + RTF（🥇 优先，~30 行）

**类型**：`feat`  
**依赖**：无  
**预估**：2–4 小时（含测试）

### T0-A：纯文本扩展（4 行，15 分钟）

**文件**：

- `Sources/Explorer/CustomPreviewRuleStore.swift`
- `Tests/ExplorerTests/PreviewLoadDispatchTests.swift`
- `Tests/ExplorerTests/CustomPreviewRuleStoreTests.swift`

**任务**：

- [ ] `BuiltinPreviewExtensions.text` 增加：`toml`、`srt`、`vtt`、`gpx`
- [ ] `catalogByMode` 同步更新展示列表
- [ ] `PreviewLoadDispatchTests` 补充路由断言（扩展名 → `.builtInText`）
- [ ] `CustomPreviewRuleStoreTests` 补充 `matchesBuiltIn` 覆盖

**验收**：

- 选中 `.toml` / `.srt` / `.vtt` / `.gpx` 文件，预览区显示语法高亮文本（gpx 按 XML 高亮即可）
- `swift test --filter PreviewLoadDispatch` 通过

---

### T0-B：RTF 富文本（~25 行）

**类型**：`feat`  
**依赖**：T0-A（可同 PR）  
**文件**：

- `Sources/Explorer/CustomPreviewRuleStore.swift`
- `Sources/Explorer/Preview/PreviewLoadRoute.swift`
- `Sources/Explorer/Preview/PreviewSession+Loading.swift`（或对应 Office 加载扩展）
- `Sources/Explorer/Preview/FileContentView.swift`
- `Tests/ExplorerTests/PreviewLoadDispatchTests.swift`

**任务**：

- [ ] `BuiltinPreviewExtensions.text` 增加 `rtf`
- [ ] `PreviewLoadRoute` 新增 `.rtf` case
- [ ] `PreviewLoadDispatch`：`ext == "rtf"` → `.rtf`
- [ ] `PreviewSession+Loading` 新增 `loadRTFPreview()`：
  - `NSAttributedString(rtf: data, documentAttributes: nil)`
  - 写入 `PreviewLoadPayload.officeRichText`（复用 docx 富文本管线）
- [ ] `FileContentView`：rtf 走 `usesWordDocumentFormattedMode` 分支
- [ ] 测试：加载样例 `.rtf`，断言 `officeRichText != nil`

**验收**：

- RTF 文件显示格式化富文本（非纯文本 fallback）
- 与 docx 富文本预览体验一致

---

## T1：EPUB 电子书预览（🥈，~300 行）

**类型**：`feat`  
**依赖**：无硬依赖（建议 T0 完成后开始）  
**预估**：半天

### 新建文件

| 文件 | 职责 |
|------|------|
| `Sources/Explorer/Preview/EpubPreviewLoader.swift` | ZIP 解包 → `container.xml` → `.opf` 解析 → 章节 HTML 提取 |
| `Sources/Explorer/Preview/Views/EpubPreviewView.swift` | WKWebView 渲染 + 章节导航（上一章/下一章） |

### 管线集成

- [ ] `BuiltinPreviewExtensions` 注册 `epub`
- [ ] `PreviewLoadRoute` 新增 `.epub`
- [ ] `PreviewLoadDispatch`：`ext == "epub"` → `.epub`
- [ ] `PreviewLoadPayload` 新增 `epubMetadata`（书名/作者/封面）+ 章节内容字段
- [ ] `PreviewSession+Loading` 新增 `loadEpubPreview()`（异步，100–500ms 典型耗时）
- [ ] `FileContentView` 新增 epub 渲染分支
- [ ] i18n：章节导航、加载失败、无封面等文案

### 实现要点

```
ZIP 解包 → META-INF/container.xml → .opf
  → metadata（dc:title, dc:creator）+ manifest + spine
  → 按 spine 顺序加载 XHTML 章节
  → WKWebView 渲染（复用现有 HTML 沙箱隔离）
```

### 测试

- [ ] `Tests/ExplorerTests/EpubPreviewLoaderTests.swift`：解析标准 epub 样例
- [ ] `PreviewLoadDispatchTests`：`epub` → `.epub`
- [ ] 手动：普通小说 epub、含图片 epub（漫画类，验证内存 <100MB）

### 风险缓解

| 风险 | 措施 |
|------|------|
| WKWebView XSS | 复用现有 iframe/独立进程沙箱 |
| 漫画类大图片 epub | 图片懒加载，章节按需加载 |
| mobi 需求 | 第一期跳过，见第二期 backlog |

---

## T2：EML 邮件预览（🥈，~260 行）

**类型**：`feat`  
**依赖**：T1（复用 WKWebView 渲染经验）  
**预估**：半天

### 新建文件

| 文件 | 职责 |
|------|------|
| `Sources/Explorer/Preview/EmlPreviewLoader.swift` | MIME 解析：headers + multipart body |
| `Sources/Explorer/Preview/Views/EmlPreviewView.swift` | 头部信息卡片 + HTML/纯文本正文 + 附件列表 |

### 管线集成

- [ ] `PreviewLoadRoute` 新增 `.eml`
- [ ] `PreviewLoadDispatch`：`ext == "eml"` → `.eml`
- [ ] `PreviewLoadPayload` 新增 `emlHeaders` / `emlHTMLBody` / `emlPlainBody` / `emlAttachments`
- [ ] `PreviewSessionNestedState` 对应状态字段
- [ ] `PreviewSession+Loading` 新增 `loadEmlPreview()`
- [ ] `FileContentView` 新增 eml 分支
- [ ] i18n：发件人/收件人/主题/日期/附件等标签

### 实现要点

```
Foundation MIME 解析
  → headers: From, To, Subject, Date, Content-Type
  → body: text/plain 走文本预览 / text/html 走 WKWebView
  → attachments: 仅列文件名 + 大小，不预览内容
```

### 测试

- [ ] `Tests/ExplorerTests/EmlPreviewLoaderTests.swift`：单 part / multipart / base64 编码样例
- [ ] 手动：Gmail 导出 `.eml`、带附件邮件

---

## T3：RAR / 7Z 压缩包（🥈，~150–200 行）

**类型**：`feat`  
**依赖**：无（建议 T1/T2 完成后再做）  
**预估**：1–2 天（含方案选型）

### 前置决策（Day 1 上午）

| 方案 | 优点 | 缺点 | 推荐 |
|------|------|------|------|
| **A：libarchive SPM** | 性能好、无外部进程 | +~2MB 包体积、C 互操作 | 长期推荐 |
| **B：unar / 7z CLI** | 零依赖、实现快 | 进程开销、需处理未安装 | 快速验证可用 |

- [ ] Spike：两种方案各用 1 个 rar + 1 个 7z 样例验证列表输出
- [ ] 确定方案后记录于 PR 描述

### 实现（复用现有 archive 管线）

当前 `ArchivePreviewLoader.isArchiveFileName()` 仅支持 zip/tar，需扩展 `.rar`、`.7z`。

- [ ] `BuiltinPreviewExtensions.matchesArchive()` + `isArchiveFileName()` 增加 `.rar`、`.7z`
- [ ] `ArchivePreviewLoader` 新增 rar/7z 列表分支（复用 `ArchiveEntryPreview` + `ArchiveListPreview` 视图）
- [ ] 复用现有 **8s timeout + 分页**（`summaryMaxEntries = 200`）
- [ ] `ThumbnailGenerator`：rar/7z 自定义缩略图（~30 行，QuickLook 不支持）
- [ ] 错误处理：加密 rar5 → 友好错误文案（i18n）

### 测试

- [ ] `ArchivePreviewLoaderTests`：rar/7z 列表解析、超时、空包
- [ ] `PreviewLoadDispatchTests`：`.rar` → `.archive`
- [ ] 手动：>1GB 大压缩包（验证 timeout 不卡 UI）

### 若选 libarchive（方案 A）

- [ ] 新建 `LibArchiveWrapper.swift`（~80 行 C 互操作）
- [ ] SPM / Xcode 添加 libarchive 依赖

---

## T4：字体预览 TTF / OTF（🥉，~330 行）

**类型**：`feat`  
**依赖**：T0–T3 完成  
**预估**：1 天

### 范围

- **第一期**：`ttf`、`otf`（CoreText 原生）
- **延后**：`woff2`（需 Brotli 库，+~200KB）

### 新建文件

| 文件 | 职责 |
|------|------|
| `Sources/Explorer/Preview/FontPreviewLoader.swift` | CTFont 加载 + 元数据提取 + 样张位图生成 |
| `Sources/Explorer/Preview/Views/FontPreviewView.swift` | 信息卡片 + 多字号样张 + 可选字符表网格 |

### 管线集成

- [ ] `BuiltinPreviewExtensions` 新增 `font` 集合：`ttf`, `otf`
- [ ] `PreviewLoadRoute` 新增 `.font`
- [ ] `PreviewLoadPayload` 新增 `fontMetadata` / `fontPreviewImage`
- [ ] `PreviewSession+Loading` 新增 `loadFontPreview()`（**独立 dispatch 队列**，防 CoreText 崩溃影响主线程）
- [ ] `FileContentView` 新增 font 分支
- [ ] i18n：字体名、风格、版本、版权、字形数等
- [ ] 可选：`ThumbnailGenerator` 自定义字体缩略图（~50 行）

### 测试

- [ ] `FontPreviewLoaderTests`：系统字体 + 用户下载 ttf/otf
- [ ] 手动：CJK 字体样张、超大字体文件（>10MB）

---

## PR 拆分建议

| PR | 内容 | 合并顺序 |
|----|------|---------|
| PR-1 | T0：toml/srt/vtt/gpx + rtf | 1 |
| PR-2 | T1：epub 预览 | 2 |
| PR-3 | T2：eml 预览 | 3 |
| PR-4 | T3：rar/7z（含方案选型说明） | 4 |
| PR-5 | T4：ttf/otf 字体预览 | 5 |

每 PR 附带：

- `swift build` 通过
- 对应 `PreviewLoadDispatchTests` / Loader 单元测试
- 手动验收 checklist

---

## 里程碑时间线（建议）

| 日期 | 交付物 |
|------|--------|
| D1 上午 | T0 合并 → 5 种格式立即可用 |
| D1 下午 – D2 上午 | T1 epub 合并 |
| D2 下午 | T2 eml 合并 |
| D3–D4 | T3 rar/7z 合并 |
| D5 | T4 字体预览合并 |

---

## 第二期 backlog（本计划不纳入）

| 格式/能力 | 理由 |
|-----------|------|
| `.mobi` | 二进制解析复杂，Amazon 已弃用 |
| `.woff2` | 需 Brotli 依赖 |
| srt/vtt 时间轴可视化 | ~200 行，ROI 低于第一期 |
| gpx MapKit 轨迹 | ~400 行，文本预览已够用 |
| `.msg` / `.mbox` | 邮件归档扩展 |

---

## 全局验收清单

- [ ] 8 类格式均能在预览区正确加载，切换文件无残留状态
- [ ] 大文件（rar>1GB、epub 漫画）不阻塞 UI，有 timeout/分页
- [ ] 加密/损坏文件显示友好错误，不崩溃
- [ ] 中英文界面无语言键泄露
- [ ] 缩略图：文本类 QuickLook 自动覆盖；rar/7z、字体按需自定义
- [ ] App 包体积：零依赖方案无增长；libarchive 方案 +~2MB 可接受
