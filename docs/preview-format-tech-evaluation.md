# Tier 1 格式预览支持 — 技术难度 & 代码量 & 性能评估

> 评估日期：2026-07-10
> 评估基准：`Sources/Explorer/Preview/` 现有架构
> 关联文档：`docs/file-format-support-analysis.md`（行业全景分析）

---

## 现有预览管线回顾

```
文件扩展名
  │
  ▼
BuiltinPreviewExtensions (声明式扩展名集合)
  │
  ▼
PreviewLoadDispatch.resolve() → PreviewLoadRoute (路由分发)
  │
  ▼
PreviewSession.loadContent() → switch route { ... } (加载执行)
  │
  ▼
PreviewLoadPayload (数据快照)
  │
  ▼
PreviewSessionContentState (持有 NSImage / PDFDocument / AVPlayer / String / ...)
  │
  ▼
FileContentView.body → 按类型渲染 SwiftUI 视图
```

关键改动点（按层次）：

| 改动层 | 文件 | 作用 |
|--------|------|------|
| L1 声明 | `CustomPreviewRuleStore.swift` → `BuiltinPreviewExtensions` | 注册扩展名 |
| L2 路由 | `PreviewLoadRoute.swift` → `PreviewLoadDispatch` | 新增 route case |
| L3 加载 | `PreviewSession+LoadingPipeline.swift` | 新增 load 方法 |
| L4 数据 | `PreviewLoadPayload.swift` | 可能需要新字段 |
| L5 状态 | `PreviewSessionNestedState.swift` | 可能需要新状态 |
| L6 渲染 | `FileContentView.swift` | 新增渲染分支 |
| L7 缩略图 | `ThumbnailGenerator.swift` | QuickLook 自动覆盖大部分 |

---

## 格式逐一评估

### 1. `.rar` / `.7z` — 压缩包

| 维度 | 评估 |
|------|------|
| **技术难度** | ⭐⭐ 中等 |
| **代码量** | ~150-200 行净增 |
| **性能影响** | 与现有 zip 解包相当，异步 + timeout 可控 |
| **依赖** | libarchive（SPM C 库）或 `unar` 命令行工具 |

**实现方案：**

```
方案 A（推荐）：集成 libarchive
  - SPM 添加 libarchive C 封装
  - 在 ArchivePreviewLoader 增加 rar/7z 分支
  - 复用现有 ArchiveEntryPreview 模型和视图

方案 B：调用系统 unar / 7z CLI
  - Process 调用，输出解析为 ArchiveEntryPreview
  - 无额外依赖，但性能略差
```

**涉及改动：**

| 文件 | 改动 | 行数 |
|------|------|------|
| `BuiltinPreviewExtensions` | `matchesArchive()` 增加 `.rar` `.7z` 后缀 | +2 |
| `ArchivePreviewLoader` | 新增 rar/7z 解包分支（方案A约60行；方案B约40行） | +60 |
| `PreviewLoadRoute` | 无需改动（走现有 `.archive` 路由） | 0 |
| 新建 `LibArchiveWrapper.swift` | C 互操作封装（仅方案A） | +80 |
| Xcode/SPM 配置 | 添加 libarchive 依赖 | +5 |

**总净增：~150 行（方案A）/ ~50 行（方案B）**

**风险：**
- 大压缩包（>1GB）解包列表可能慢 → 已有 8s timeout + 分页机制
- rar5 加密格式无法预览 → 显示友好错误即可

---

### 2. `.epub` / `.mobi` — 电子书

#### 2a. `.epub`

| 维度 | 评估 |
|------|------|
| **技术难度** | ⭐⭐ 中等 |
| **代码量** | ~250-300 行净增 |
| **性能影响** | epub 通常 <10MB，ZIP 解压 + HTML 渲染很快 |
| **依赖** | 零外部依赖（ZIP 用 Foundation，HTML 用 WKWebView） |

**实现方案：**

```
1. ZIP 解包 epub（Foundation FileManager / 第三方 ZIP 库）
2. 解析 META-INF/container.xml → 找到 .opf 文件路径
3. 解析 .opf → 提取 metadata（书名/作者/封面）+ spine（阅读顺序）
4. 按 spine 顺序加载 XHTML 章节
5. 在 WKWebView 中渲染（复用 iframe 隔离沙箱）
```

**涉及改动：**

| 文件 | 改动 | 行数 |
|------|------|------|
| `BuiltinPreviewExtensions` | 新增 `epub` 到 text 或新 category | +1 |
| `PreviewLoadRoute` | 新增 `.epub` case | +1 |
| `PreviewLoadDispatch` | `ext == "epub"` → `.epub` | +3 |
| 新建 `EpubPreviewLoader.swift` | ZIP 解包 + OPF 解析 + 章节提取 | ~150 |
| `PreviewLoadPayload` | 新增 `epubHTMLContent` / `epubMetadata` 字段 | +10 |
| `PreviewSession+LoadingPipeline` | 新增 `loadEpubPreview()` 方法 | +30 |
| 新建 `EpubPreviewView.swift` | WKWebView 渲染 + 章节导航 | ~100 |
| `FileContentView` | 新增 epub 渲染分支 | +10 |

**总净增：~300 行**

#### 2b. `.mobi`

| 维度 | 评估 |
|------|------|
| **技术难度** | ⭐⭐⭐⭐ 高 |
| **代码量** | ~500+ 行 |
| **性能影响** | 中等 |
| **依赖** | 需要 PalmDOC 解码 / MOBI 二进制解析 |

**建议：** mobi 格式已是 Amazon 弃用格式（被 KF8/AZW3 取代），建议 **第一期仅支持 epub**，mobi 可延后到第二/三期或通过 calibre CLI 间接支持。

---

### 3. `.rtf` — 富文本

| 维度 | 评估 |
|------|------|
| **技术难度** | ⭐ 极低 |
| **代码量** | ~30 行净增 |
| **性能影响** | 零（RTF 通常 <1MB） |
| **依赖** | 零（AppKit NSAttributedString 原生支持 RTF） |

**实现方案：**

```
RTF 是 AppKit 原生格式：
  NSAttributedString(rtf: data, documentAttributes: nil)

完全复用现有 docx 富文本预览管线：
  - 加载 → NSAttributedString → OfficeRichTextPreview
```

**涉及改动：**

| 文件 | 改动 | 行数 |
|------|------|------|
| `BuiltinPreviewExtensions` | `text` 集合增加 `"rtf"` | +1 |
| `PreviewLoadRoute` | 新增 `.rtf` case | +1 |
| `PreviewLoadDispatch` | `ext == "rtf"` → `.rtf` | +3 |
| `PreviewSession+LoadingPipeline` | 新增 `loadRTFPreview()`，约15行（复制 docx 逻辑但去掉 fallback） | +15 |
| `PreviewSessionNestedState` | 无需改动（复用 `officeRichText`） | 0 |
| `FileContentView` | rtf 复用 `usesWordDocumentFormattedMode` 或新增判断 | +5 |

**总净增：~25 行**

---

### 4. `.toml` — 配置文件

| 维度 | 评估 |
|------|------|
| **技术难度** | ⭐ 极低 |
| **代码量** | **1 行** |
| **性能影响** | 零 |
| **依赖** | 零 |

**实现方案：**

```
TOML 作为纯文本语法高亮即可，无需专门解析器。

在 BuiltinPreviewExtensions.text 集合中加入 "toml" 即可。
```

**涉及改动：**

| 文件 | 改动 | 行数 |
|------|------|------|
| `BuiltinPreviewExtensions` | `text` 集合增加 `"toml"` | +1 |

**总净增：1 行**

---

### 5. `.srt` / `.vtt` — 字幕

| 维度 | 评估 |
|------|------|
| **技术难度** | ⭐ 极低（纯文本模式）/ ⭐⭐⭐ 中等（时间轴可视化） |
| **代码量** | 1-2 行（纯文本）/ ~200 行（可视化） |
| **性能影响** | 零 |
| **依赖** | 零 |

**实现方案：**

```
方案 A（推荐第一期）：纯文本预览
  - 加入 text 集合，自动语法高亮（无专用高亮，但可读性足够）

方案 B（增强第二期）：时间轴 + 字幕预览
  - 解析 SRT/VTT 时间码
  - 渲染时间轴条 + 字幕卡片
  - 关联同目录视频文件播放位置
```

**涉及改动（方案A）：**

| 文件 | 改动 | 行数 |
|------|------|------|
| `BuiltinPreviewExtensions` | `text` 集合增加 `"srt"`, `"vtt"` | +2 |

**总净增（方案A）：2 行**

---

### 6. `.gpx` — GPS 轨迹

| 维度 | 评估 |
|------|------|
| **技术难度** | ⭐ 极低（XML 文本）/ ⭐⭐⭐⭐ 高（地图可视化） |
| **代码量** | 1 行（文本）/ ~400 行（地图） |
| **性能影响** | 零（文本）/ 中等（地图渲染大量轨迹点） |
| **依赖** | 零（文本）/ MapKit（地图） |

**实现方案：**

```
方案 A（推荐第一期）：XML 文本预览
  - GPX 本质是 XML，加入 text 集合即可
  - 用户可读经纬度/时间/海拔

方案 B（增强第二期）：MapKit 轨迹渲染
  - 解析 GPX XML → 提取 track/waypoint
  - MapKit MKMapView 渲染轨迹线 + 标注点
  - 显示海拔剖面图
```

**涉及改动（方案A）：**

| 文件 | 改动 | 行数 |
|------|------|------|
| `BuiltinPreviewExtensions` | `text` 集合增加 `"gpx"` | +1 |

**总净增（方案A）：1 行**

---

### 7. `.ttf` / `.otf` / `.woff2` — 字体

| 维度 | 评估 |
|------|------|
| **技术难度** | ⭐⭐⭐ 中高 |
| **代码量** | ~250-350 行净增 |
| **性能影响** | 字体加载 <50ms，字形表渲染中等 |
| **依赖** | CoreText（系统）、woff2 需解压（Brotli，非系统自带） |

**实现方案：**

```
1. CoreText 加载字体：
   - ttf/otf: CTFontManagerCreateFontDescriptorsFromURL()
   - woff2: 需要用 Brotli 解压为 ttf/otf，再走同样流程

2. 字体信息提取：
   - 字体名称 / 风格 / 版本 / 版权
   - 字形数量 / 字符集范围
   - 连字/变体特性

3. 字体样张渲染：
   - 用 CoreText 排版示例文本（"The quick brown fox..." + 中文样张）
   - 多字号展示（12pt / 24pt / 48pt / 72pt）
   - 字符表网格（可选）
```

**涉及改动：**

| 文件 | 改动 | 行数 |
|------|------|------|
| `BuiltinPreviewExtensions` | 新增 `font` 集合：`ttf`, `otf`, `woff2` | +3 |
| `PreviewLoadRoute` | 新增 `.font` case | +1 |
| `PreviewLoadDispatch` | font 集合匹配 → `.font` | +3 |
| `PreviewLoadPayload` | 新增 `fontMetadata` / `fontPreviewImage` 字段 | +10 |
| `PreviewSessionNestedState` | 新增 `fontMetadata` / `fontPreview` 字段 | +8 |
| 新建 `FontPreviewLoader.swift` | CTFont 加载 + 元数据提取 + 样张位图生成 | ~120 |
| `PreviewSession+LoadingPipeline` | 新增 `loadFontPreview()` | +25 |
| 新建 `FontPreviewView.swift` | 字体信息卡片 + 样张 + 字符表视图 | ~150 |
| `FileContentView` | 新增 font 渲染分支 | +10 |

**总净增：~330 行**

**风险：**
- woff2 解压需要 Brotli 解码（woff2 用 Brotli 而非 zlib），需额外引入 brotli 库，或第一期仅支持 ttf/otf
- 某些商业字体的许可限制 → 不影响预览功能

---

### 8. `.eml` — 邮件

| 维度 | 评估 |
|------|------|
| **技术难度** | ⭐⭐ 低-中 |
| **代码量** | ~200-250 行净增 |
| **性能影响** | EML 通常 <1MB，解析极快 |
| **依赖** | 零（Foundation MIME 解析即可） |

**实现方案：**

```
1. MIME 解析：
   - 解析 headers（From, To, Subject, Date, Content-Type）
   - 解析 multipart body → 提取 text/plain + text/html
   
2. 渲染：
   - 头部信息卡片（发件人/收件人/主题/日期）
   - HTML 正文用 WKWebView 渲染
   - 纯文本正文用现有文本预览
   - 附件列表（仅列出文件名，不预览附件内容）
```

**涉及改动：**

| 文件 | 改动 | 行数 |
|------|------|------|
| `BuiltinPreviewExtensions` | `text` 集合增加 `"eml"` | +1 |
| `PreviewLoadRoute` | 新增 `.eml` case | +1 |
| `PreviewLoadDispatch` | `ext == "eml"` → `.eml` | +3 |
| 新建 `EmlPreviewLoader.swift` | MIME 解析 + header/body 提取 | ~100 |
| `PreviewLoadPayload` | 新增 `emlHeaders` / `emlHTMLBody` / `emlAttachments` | +12 |
| `PreviewSessionNestedState` | 新增 eml 状态字段 | +8 |
| `PreviewSession+LoadingPipeline` | 新增 `loadEmlPreview()` | +25 |
| 新建 `EmlPreviewView.swift` | 邮件卡片头部 + WKWebView body | ~100 |
| `FileContentView` | 新增 eml 渲染分支 | +8 |

**总净增：~260 行**

---

## 📊 汇总对比

| 格式 | 难度 | 净增行数 | 新增文件 | 外部依赖 | 用户覆盖 | 推荐顺序 |
|------|------|---------|---------|---------|---------|---------|
| `.toml` | ⭐ | **1 行** | 0 | 无 | 3000万 | 🥇 |
| `.srt` `.vtt` | ⭐ | **2 行** | 0 | 无 | 10亿+ | 🥇 |
| `.gpx` | ⭐ | **1 行** | 0 | 无 | 5亿+ | 🥇 |
| `.rtf` | ⭐ | **~25 行** | 0 | 无 | 20亿+ | 🥇 |
| `.eml` | ⭐⭐ | **~260 行** | 2 | 无 | 30亿+ | 🥈 |
| `.epub` | ⭐⭐ | **~300 行** | 2 | 无 | 15亿+ | 🥈 |
| `.rar` `.7z` | ⭐⭐ | **~150 行** | 0-1 | libarchive(可选) | 30亿+ | 🥈 |
| `.ttf` `.otf` `.woff2` | ⭐⭐⭐ | **~330 行** | 2 | brotli(woff2) | 5亿+ | 🥉 |

---

## ⚡ 性能影响分析

### 预览加载性能

| 格式 | 典型文件大小 | 加载耗时 | 内存占用 | 对现有管线影响 |
|------|------------|---------|---------|---------------|
| `.toml` `.srt` `.vtt` `.gpx` | <100KB | <5ms | ~1MB | 零影响 |
| `.rtf` | <5MB | <20ms | ~10MB | 零影响 |
| `.eml` | <5MB | <30ms | ~10-30MB | 极低 |
| `.epub` | 1-50MB | 100-500ms | 30-100MB | 低（ZIP解压） |
| `.rar` `.7z` | 1MB-10GB | 100ms-8s | 10-200MB | 中（大文件列表） |
| `.ttf` `.otf` | <20MB | <50ms | 20-50MB | 低 |

### 缩略图生成

- 所有文本类格式（toml/srt/vtt/gpx/rtf/eml）的缩略图由 QuickLook 自动覆盖，**零额外工作**
- 字体文件 `.ttf/.otf` 的 QuickLook 缩略图质量一般，可考虑自定义缩略图生成器（~50行）
- epub 的 QuickLook 缩略图默认显示封面，已经足够好
- rar/7z 的 QuickLook 不支持，需要自定义缩略图 → 额外 ~30 行

### 内存压力

- 文本格式（toml/srt/vtt/gpx/rtf/eml）：全部 <30MB，可忽略
- epub：如有大量图片（漫画类 epub），可能达 100MB+。可通过图片懒加载控制
- rar/7z：大压缩包列表预览已有 timeout + 分页保护
- 字体：单个字体文件 <20MB，无风险

### App 启动/包体积

| 依赖 | 包体积影响 |
|------|-----------|
| 零外部依赖方案（toml/srt/vtt/gpx/rtf/eml/epub） | 零增长 |
| libarchive（rar/7z） | +~2MB 静态链接 |
| brotli（woff2） | +~200KB 静态链接 |

---

## 🎯 推荐实施顺序

### 第 0 步（15 分钟，4 行代码）

```
BuiltinPreviewExtensions.text += ["toml", "srt", "vtt", "gpx"]
BuiltinPreviewExtensions.text += ["rtf"]     // + loadRTFPreview ~15行
```

**立即可用，覆盖 25 亿+ 用户。**

### 第 1 步（半天，~300 行代码）

```
epub 预览支持
  - EpubPreviewLoader.swift
  - EpubPreviewView.swift
  - 管线集成
```

### 第 2 步（半天，~260 行代码）

```
eml 预览支持
  - EmlPreviewLoader.swift
  - EmlPreviewView.swift
  - 管线集成
```

### 第 3 步（1-2 天，~150-200 行代码）

```
rar/7z 预览支持
  - 方案评估（libarchive vs CLI）
  - ArchivePreviewLoader 扩展
```

### 第 4 步（1 天，~330 行代码）

```
字体预览（ttf/otf/woff2）
  - FontPreviewLoader + FontPreviewView
  - woff2 解压方案确定（Brotli）
```

---

## 📋 风险评估

| 风险 | 影响格式 | 缓解措施 |
|------|---------|---------|
| 恶意构造的 epub 触发 WKWebView XSS | epub/eml | 已有独立进程隔离沙箱 |
| 大压缩包列表耗时过长 | rar/7z | 复用现有 8s timeout + 分页 |
| woff2 需要 Brotli 解码库 | woff2 | 第一期仅支持 ttf/otf，woff2 延后 |
| mobi 二进制解析复杂 | mobi | 第一期跳过，建议 epub 优先 |
| 某些字体触发 CoreText 崩溃 | ttf/otf | 字体加载用独立 dispatch 队列隔离 |

---

## 总结

**Tier 1 全部 8 类格式的代码增量上限约 1,100 行 + 2-3 个新文件，其中超过一半（toml/srt/vtt/gpx/rtf）几乎零成本即可支持。**

最大的单点投入是 epub (~300行) 和字体预览 (~330行)，但它们各自覆盖 15 亿和 5 亿用户，ROI 极高。
