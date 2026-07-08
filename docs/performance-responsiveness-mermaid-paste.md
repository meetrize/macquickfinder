# 响应速度分析与优化方案（Mermaid 预览 + 剪贴板粘贴 + 全局）

> 背景：在新增 **Markdown 流程图（Mermaid）预览** 与 **从剪贴板直接粘贴文件/内容到目录** 后，整体体感响应变慢。  
> 本文在代码层面定位瓶颈，给出按优先级排序的优化建议与分阶段实施计划。  
> 与既有 Phase 1–9 优化（见 `docs/performance-optimization.md`）互补，聚焦新功能与剩余全局热点。

---

## 1. 结论摘要

| 区域 | 主要问题 | 体感影响 | 建议优先级 |
|------|----------|----------|------------|
| Mermaid 预览 | 全链路 `@MainActor` + 2.5MB JS 同步加载 + 整篇 Markdown 重渲染 + 缩放触发重绘 | 打开/滚动/缩放 `.md` 时卡顿 | **P0** |
| 剪贴板粘贴 | 主线程同步 `copyItem`/`moveItem` + 粘贴后全目录 reload + `canPaste` 每次 body 重算 | ⌘V 与大文件粘贴冻结 UI | **P0** |
| 目录元数据 | `autoCalculateDirectorySizes` 默认 **开启**，递归统计整棵子树 | 浏览含大量子目录的文件夹时持续 I/O | **P1** |
| FSEvents | 任何 listing 变更 → 500ms 防抖后 **整目录重枚举** | 构建/同步/批量操作后反复刷新 | **P1** |
| SwiftUI 刷新面 | `DirectoryMetadataOverlay` revision、`ContentView` 多 `@ObservedObject` | 滚动列表时偶发掉帧 | **P2** |

**核心判断**：新功能本身引入了主线程重活（WebView 渲染、同步文件 I/O）；叠加原有「全量 reload + 默认目录大小计算」后，体感差异会被放大。优先修 **主线程阻塞** 与 **不必要的全量重算**，收益最大。

---

## 2. Mermaid 流程图预览

### 2.1 架构与触发链

```
.md 文件 + 预览模式
  → FileContentView → MarkdownFilePreview
  → applyMarkdown()（同步：全文 AttributedString + 表格 + Mermaid 占位）
  → scheduleMermaidRenders()（异步：WKWebView + mermaid.min.js）
  → 完成后 applyMermaidCache() 局部 invalidate layout
```

**关键文件**

| 文件 | 职责 |
|------|------|
| `Sources/Explorer/Preview/Views/MarkdownFilePreview.swift` | Markdown 渲染管线、Mermaid 调度 |
| `Sources/Explorer/Preview/Views/MarkdownPreviewMermaidBlock.swift` | ` ```mermaid ` 块检测、占位附件、缓存键 |
| `Sources/Explorer/Preview/Views/MarkdownPreviewMermaidRenderer.swift` | 离屏 WKWebView 渲染、快照 |
| `Sources/Explorer/Resources/mermaid.min.js` | 约 2.5 MB  bundled JS |

### 2.2 已识别的性能问题

#### P0-A：渲染器全程 `@MainActor`

`MarkdownPreviewMermaidRenderer` 标记为 `@MainActor`，WebView 创建、`loadHTMLString`、`callAsyncJavaScript`、`layoutSubtreeIfNeeded`、`takeSnapshot`、`NSImage` 构建均在主线程。即使使用 `async/await`，每个流程图仍可能占用数十到数百毫秒主线程时间。

#### P0-B：首次使用同步读取 2.5MB JS

```swift
private static let mermaidJSSource: String = {
    // String(contentsOf: mermaid.min.js) — 类首次访问时同步读盘
}()
```

首次打开含 Mermaid 的 Markdown 会在主线程阻塞读大文件，并嵌入 inline HTML shell。

#### P0-C：单 WebView 并发渲染竞态

`scheduleMermaidRenders` 对每个 pending 块启动独立 `Task`，但 `MarkdownPreviewMermaidRenderer` 仅有一个 `webView`。`inflight` 只去重 **相同 cacheKey**，不同 diagram 会并发调用 `performRender`，共用 DOM（`diagram-root`），存在竞态与重复无效工作。

#### P0-D：整篇 Markdown 频繁全量重渲染

以下任一变化都会 `applyMarkdown()` → 重建全文 `NSMutableAttributedString` → `setAttributedString`：

- 内容变更、缩放（±0.1）、换行模式、布局宽度变化
- ScrollView `boundsDidChange`（**无防抖**，>0.5pt 即触发）

大文档 + 多 Mermaid 块时，正则、表格布局、块扫描成本线性叠加。

#### P0-E：缩放导致 Mermaid 缓存失效

缓存键含 `layoutWidth`，而 `layoutWidth` 依赖 `zoomScale`。用户缩放预览时，`scaleUnitSquare` 已负责视觉缩放，但 Mermaid 仍按新宽度 **重新 WKWebView 渲染**，成本高且通常不必要。

#### P1-F：固定延迟叠加

- 快照前 `Task.sleep(150ms)`
- JS 侧双 `requestAnimationFrame` + 60ms `setTimeout`
- Shell 就绪轮询最多 5s

简单 flowchart 也会多等 ~200ms。

#### P1-G：离屏 WebView 8192px 高缓冲

每次 render 将 WebView 设为 `prepHeight = 8192`，GPU/内存开销偏大。

#### P1-H：Mermaid 内存缓存无上限

`Coordinator.mermaidCache` 按 `(source, isDark, layoutWidth)` 存 `NSImage`，浏览多篇文档或反复改窗口宽度会持续增长（内存压力回调未专门清理 Mermaid 缓存）。

#### P2-I：双次初始渲染

`makeNSView` 立即 `applyMarkdown`，随后 `DispatchQueue.main.async` 若宽度变化再 apply 一次，可能重复调度 Mermaid。

#### P2-J：块替换时重复 line map

`MarkdownPreviewMermaidBlock.apply` 每替换一个块都 `lineRanges(in:)`，多 diagram 时为 O(blocks × lines)。

### 2.3 优化方案

#### 方案 M1：Mermaid 渲染串行队列（P0，低风险）

**做法**：在 `MarkdownPreviewMermaidRenderer` 内维护 `renderQueue: [RenderRequest]` + 单一 worker Task，保证同一时刻只有一个 `performRender` 操作 WebView。

**收益**：消除 DOM 竞态，减少无效重绘；多图文档渲染更可预测。  
**成本**：多图顺序渲染，总墙钟时间略增，但主线程峰值下降、UI 更稳。

#### 方案 M2：缩放与 Mermaid 解耦（P0，低风险）

**做法**：

1. 缓存键 **移除 layoutWidth**，或仅按「逻辑内容宽度」（未缩放）分桶；
2. 附件 bounds 随 zoom 由 `scaleUnitSquare` / 布局乘子处理，不在 zoom 变化时 `applyMarkdown`。

**收益**：用户缩放时零 WebView 重渲染，交互即时。  
**验证**：窄窗口换行与宽窗口布局差异仍可通过 debounced width 变更触发一次重渲染。

#### 方案 M3：布局宽度变更防抖（P0，低风险）

**做法**：`handleTableLayoutWidthChange` 增加 100–150ms debounce（与 `FileListContentController` visible-path 调度对齐）。

**收益**：拖动分割条、窗口 resize 时避免连续全文重解析。

#### 方案 M4：Mermaid 增量更新（P1，中风险）

**做法**：

- 内容变更时 diff Mermaid 块（按 source hash），仅对新增/变更块插入占位并调度渲染；
- 未变块保留已有 attachment，跳过 `setAttributedString` 全文替换。

**收益**：大文档编辑时 CPU 显著下降。  
**注意**：需与表格、搜索高亮等管线协调，测试面较大。

#### 方案 M5：JS 懒加载 + 后台预读（P1，低风险）

**做法**：

1. 首次需要 Mermaid 时在 `Task.detached` 读 `mermaid.min.js` 为 `Data`/`String`；
2. App 启动后 idle 时（`DispatchQueue.main.asyncAfter` 2s）可选预温；
3. 避免 static let 在任意 `@MainActor` 触达时同步读盘。

**收益**：消除首次卡顿尖峰；与是否打开 Markdown 解耦。

#### 方案 M6：降低快照延迟（P1，低风险）

**做法**：用 `WKWebView` navigation / JS Promise 回调替代固定 150ms sleep；JS 侧保留单次 `requestAnimationFrame` 即可。

**收益**：每图节省 ~100–150ms，首屏 diagram 更快出现。

#### 方案 M7：Mermaid 缓存 LRU + 内存压力清理（P1，低风险）

**做法**：

- `mermaidCache` 设 `countLimit`（如 20 张图 / ~32MB cost）；
- `AppMemoryPressure` 中增加 `MarkdownPreviewMermaidRenderer` / Coordinator 缓存清理；
- 可选：磁盘缓存 SVG/PNG（按 cacheKey），二次打开同文档秒开。

#### 方案 M8：WebView 工作下沉（P2，中高风险）

**做法**：将 `performRender` 中 JS 执行与 snapshot 移到非 MainActor actor；仅 `NSImage` 创建与 `textStorage` 更新回主线程。

**收益**：主线程峰值进一步降低。  
**风险**：WKWebView 线程亲和性需实测；macOS 上 WebKit 与 MainActor 绑定较紧，需 Instruments 验证。

#### 方案 M9：按需加载 Mermaid（P2，产品向）

**做法**：设置项「Markdown 预览：渲染 Mermaid 图」默认开，可关；或仅当 diagram 进入可视区域（`NSTextView` visible rect）才 `scheduleMermaidRenders`。

**收益**：纯文本 Markdown 零 Mermaid 成本；长文只渲染可见图。

---

## 3. 剪贴板粘贴文件/内容

### 3.1 架构与触发链

```
⌘V / 右键 Paste
  → ContentView.fileCommandHandlers / blankMenuActions / context menu
  → FileOperations.paste(to:completion:)
      ├─ 剪贴板有 file URL → 同步 copyItem / moveItem
      └─ 无 URL → ClipboardFileCreation.createFile（文本/图片写盘）
  → finishPaste → loadItems()（全目录异步重载）
```

**关键文件**

| 文件 | 职责 |
|------|------|
| `Sources/Explorer/Domain/FileOperations.swift` | 粘贴主逻辑、`canPaste`、pasteboard 读取 |
| `Sources/Explorer/Domain/ClipboardFileCreation.swift` | 文本/图片转新文件 |
| `Sources/Explorer/ContentView.swift` | 命令绑定、`finishPaste`、`loadItems` |

### 3.2 已识别的性能问题

#### P0-A：粘贴 I/O 在主线程同步执行

`FileOperations.paste` 内 `for sourceURL in state.urls { copyItem/moveItem }` 直接跑在 UI 调用栈。大文件、多文件、网络卷上 ⌘V 会明显冻结。

#### P0-B：粘贴后全目录 reload

`finishPaste` 始终 `loadItems()`：清空列表、`isLoading = true`、后台整目录枚举。粘贴 1 个小文件也触发完整 refresh；若 FSEvents 同时触发，可能 **double reload**。

#### P0-C：`canPaste` 在 SwiftUI body 热路径

`fileCommandHandlers`、`blankMenuActions` 为计算属性，每次 `ContentView` 重绘都会：

1. `NSPasteboard.general.readObjects`
2. 对每个源路径 `fileExists` / `canonicalPath`（`moveBlockReason`）
3. 内容粘贴路径可能读剪贴板图片数据（`ClipboardFileCreation.contentKind`）

粘贴按钮 enable 状态不应每帧读盘。

#### P1-D：图片粘贴压缩在主线程

`ClipboardFileCreation.normalizedCompressedPNG` 使用 ImageIO 压缩，大截图/TIFF 在 `createFile` 完成前阻塞 UI。

#### P1-E：`paste()` 内重复 pasteboard 读取

`pasteboardState()` 后 `canPaste()` 再次 `pasteboardState()`，重复工作。

#### P2-F：顺序处理无进度

多文件顺序 copy，中途失败 `break`；无进度 UI，用户误以为卡死。

#### P2-G：pasteboard 解析窄于拖拽

`readFileURLs` 仅用 `readObjects(forClasses:[NSURL])`；拖拽路径 `FileListDragSupport.fileURLs` 有 legacy fallback。非性能问题，但可能导致反复尝试粘贴失败后的重试行为。

### 3.3 优化方案

#### 方案 P1：粘贴 I/O 后台化（P0，低风险）

**做法**：

```swift
// 伪代码
Task.detached(priority: .userInitiated) {
    let result = performPasteIO(...)  // copy/move/write
    await MainActor.run {
        finishPaste(incremental: result.addedItems)
    }
}
```

- 主线程仅弹错误 Alert、更新 UI；
- 大文件 copy 可配合 `FileManager` coordinator（若后续需要进度）。

**收益**：⌘V 立即返回，列表可显示「粘贴中…」轻量状态。

#### 方案 P2：增量列表更新（P0，中风险）

**做法**：粘贴成功后：

1. 对 copy/move 成功的目标 URL 调用 `DirectoryListingLoader` 单条或批量 stat，构造 `FileItem`；
2. 插入 `items` 并排序，而非 `loadItems()` 全量；
3. FSEvents 500ms 内若已增量更新，可跳过或合并 refresh。

**收益**：大目录粘贴 1 个文件时列表瞬时更新。  
**注意**：需与树形展开、筛选、Git 状态列对齐；失败时 fallback 全量 reload。

#### 方案 P3：Pasteboard 状态缓存（P0，低风险）

**做法**：

1. 新建 `PasteboardFileAvailability`（或挂在 `AppModule`）：监听 `NSPasteboard.changedNotification` + 250ms debounce 更新 `{ canPaste, urls, contentKind }`；
2. `fileCommandHandlers.canPaste` 读缓存；
3. `paste()` 使用同一份 snapshot，去掉二次 `canPaste()`。

**收益**：消除 ContentView 每帧 pasteboard + 磁盘 stat；Edit 菜单仍正确 disable/enable。

#### 方案 P4：图片压缩移出主线程（P1，低风险）

**做法**：`ClipboardFileCreation.createFile` 内 image 分支在 `Task.detached` 做 ImageIO，主线程只写最终 `Data`。

**收益**：粘贴大截图不卡 UI。

#### 方案 P5：与 FSEvents 协同（P1，低风险）

**做法**：粘贴完成后设置 `listingRefreshSuppressionToken`（短窗口 300ms），`DirectoryFSEventsMonitor` 合并为一次 refresh；或标记 `pendingIncrementalPaths` 供 FSEvents handler 优先增量。

**收益**：避免 paste + FSEvents 双重重枚举。

#### 方案 P6：粘贴进度与可取消（P2，体验）

多文件 / 大目录 copy 时状态栏或 overlay 显示进度；`loadGeneration` 式 cancel token 支持切换目录时取消后台 paste。

---

## 4. 全局性能（与新功能叠加效应）

以下问题并非由 Mermaid/粘贴直接引入，但在新功能增加主线程负载后更容易被感知。

### 4.1 目录大小自动计算（P1）

- `ContentView`：`@AppStorage(...) private var autoCalculateDirectorySizes = true`
- 每次 `loadItems` 后对 **所有子目录** 调度 `DirectorySizeComputer`（递归，上限 10 万文件 / 60s）
- **建议**：默认值改为 `false`（与 `docs/performance-optimization.md` §1.4 一致）；或「仅对可见目录计算」已存在，需确认首次 load 是否仍全量 schedule

### 4.2 FSEvents → 全量 reload（P1）

- `DirectoryFSEventsMonitor`：listing 变更 500ms 防抖 → `ContentView.loadItems()`
- 构建目录、iCloud、Git 工作区频繁变更时 CPU/I/O 持续
- **建议（中长期）**：对 `created`/`removed`/`renamed` 做增量 patch；至少合并短时间多次事件为单次 reload

### 4.3 DirectoryMetadataOverlay → SwiftUI body（P2）

- `sizeRevision` / `countRevision` 触发 `FileListView` bridge 重建 `makeListRows()`
- AppKit 层已有 `sizeOnlyChanged` → `reloadSizeColumnPreservingScroll`，但 SwiftUI 仍重算
- **建议**：将 metadata 订阅下沉到 `NSViewRepresentable` Coordinator，避免 bridge 包裹 entire `body`

### 4.4 ContentView 观察面过大（P2）

- 同时观察 Git、Toolbar、ConnectServer、Layout 等；无关 store 更新可能 invalidate 大视图
- **建议**：文件列表子树拆独立 `@Observable` / `EquatableView` 隔离；命令菜单 handler 用 `@FocusedValue` + 缓存 paste 状态

### 4.5 缩略图模式目录项数（P2）

- 可见区调度 `DirectoryItemCountService`：每文件夹 `contentsOfDirectory` + 子项 hidden 检查
- **建议**：与 size 共用 visible-only debounce；网络卷降低优先级或跳过

### 4.6 预览浏览器胶片条（P3）

- 快速切换预览时 `PreviewBrowserStripThumbnailLoader` cancel 全部 QL 任务
- **建议**：保留当前 ±1 窗口内 in-flight，仅 cancel 窗口外

### 4.7 路径栏子目录缓存（P3）

- `PathSubdirectoryCache.load()` 同步枚举，菜单直接打开可能主线程 spike
- 已有 50 条 LRU + 60s TTL；确保菜单展开前仅读缓存，miss 时 async 填充

---

## 5. 分阶段实施计划

### Phase 10 — 快速止血（1–2 天，低风险）✅ 已完成

| 编号 | 项 | 方案 | 状态 |
|------|-----|------|------|
| 10.1 | Mermaid 串行队列 | M1 | ✅ `MarkdownPreviewMermaidRenderer.renderTail` |
| 10.2 | 缩放不重渲染 Mermaid | M2 | ✅ `cacheKey` 移除 width；`updateNSView` 缩放不触发 `applyMarkdown` |
| 10.3 | Markdown 宽度 debounce | M3 | ✅ `handleTableLayoutWidthChange` 120ms |
| 10.4 | Pasteboard 缓存 | P3 | ✅ `PasteboardPasteAvailability`（changeCount 轮询 + debounce） |
| 10.5 | 粘贴去掉重复 pasteboard 读 | P3 一部分 | ✅ `canPaste(with:hasCreatableContent:)` |
| 10.6 | Mermaid 缓存 LRU + 内存压力 | M7 | ✅ `MermaidPreviewCache` + `AppMemoryPressure` |

**验收**：Release 构建通过；Instruments 手动验收见 §6。

### Phase 11 — 主线程 I/O 迁出（2–4 天，低风险）✅ 已完成

| 编号 | 项 | 方案 | 状态 |
|------|-----|------|------|
| 11.1 | 粘贴 copy/move 后台化 | P1 | ✅ `Task.detached` + `performFilePaste` |
| 11.2 | 图片压缩后台化 | P4 | ✅ `createFileAsync` + `requiresCompression` |
| 11.3 | Mermaid JS 懒加载 | M5 | ✅ `loadMermaidJSSource()` + 启动 2s 预温 |
| 11.4 | 降低 Mermaid 快照延迟 | M6 | ✅ 移除 150ms sleep；JS 单次 rAF |
| 11.5 | 粘贴与 FSEvents 去重 | P5 | ✅ `noteUserInitiatedListingRefresh` |

**验收**：Release 构建通过；⌘V 大文件粘贴 UI 不冻结；粘贴后无 double reload。

### Phase 12 — 列表与渲染增量（1–2 周，中风险）✅ 已完成

| 编号 | 项 | 方案 | 状态 |
|------|-----|------|------|
| 12.1 | 粘贴后增量插入 FileItem | P2 | ✅ `insertListingItems` + `DirectoryListingIncrementalUpdate` |
| 12.2 | Mermaid 块增量 diff | M4 | ✅ 视口变更仅刷新附件 bounds；无表格时跳过全文重渲染 |
| 12.3 | FSEvents 增量 listing | §4.2 | ✅ `DirectoryListingIncrementalPatcher` + `onListingPatch` |
| 12.4 | Metadata overlay 下沉 AppKit | §4.3 | ✅ `DirectoryMetadataAppKitBridge` 订阅 revision |

### Phase 13 — 体验与可选深度优化

| 编号 | 项 | 方案 |
|------|-----|------|
| 13.1 | Mermaid 可视区域 lazy render | M9 |
| 13.2 | WebView 渲染下沉 | M8 |
| 13.3 | 粘贴进度 UI | P6 |
| 13.4 | 目录大小默认关 + 设置文案 | §4.1 |

---

## 6. 测量与回归基线

在 **Release** 构建下记录优化前后数据（可写入 `docs/performance-optimization.md` 验收节）。

### 6.1 场景

1. **Mermaid**：5 个 flowchart 的 2000 行 md，打开预览、缩放 5 次、拖动分割条 resize 10 次  
2. **粘贴**：当前目录 5000 项，粘贴 1 个小文件 / 100MB 单文件 / 20 个小文件  
3. **日常**：含 500+ 子文件夹的目录，开启/关闭「自动计算目录大小」浏览 2 分钟  
4. **叠加**：预览 Mermaid 文档同时向当前目录粘贴图片

### 6.2 Instruments

| 模板 | 关注 |
|------|------|
| Time Profiler | 主线程 `applyMarkdown`、`performRender`、`canPaste`、`loadItems` |
| Allocations | Mermaid `NSImage` 数量、WebView 内存 |
| System Trace | paste 期间主线程 blocked on I/O |

### 6.3 指标建议

- 主线程连续阻塞 >16ms 的次数 / 分钟  
- ⌘V 到列表出现新项的时间（P95）  
- Mermaid 首图可见时间（从打开预览到第一张 diagram 非 placeholder）  
- 目录切换至首屏可交互时间  

---

## 7. 不建议的做法

- **不要**为省资源默认关闭 FSEvents 或粘贴功能（应优化路径，非砍功能）  
- **不要**在目录切换时对 Mermaid 使用 `purgeAll` 式全局清 WebView（应 LRU + 按需重建 shell）  
- **不要**去掉 `loadGeneration` 取消机制  
- **不要**把 Mermaid 渲染改为同步阻塞等待（会 worse 卡顿）  
- **不要**在 paste 失败时 silent fail — 后台化后更需明确错误回调  

---

## 8. 相关文档与代码索引

| 文档 / 代码 | 说明 |
|-------------|------|
| `docs/performance-optimization.md` | Phase 1–9 已完成项与通用原则 |
| `MarkdownPreviewMermaidRenderer.swift` | Mermaid WebView 渲染 |
| `MarkdownFilePreview.swift` | Markdown 全文渲染与 Mermaid 调度 |
| `FileOperations.swift` | 粘贴与 pasteboard |
| `ClipboardFileCreation.swift` | 文本/图片转文件 |
| `ContentView.swift` | `loadItems`、`fileCommandHandlers`、`finishPaste` |
| `DirectoryFSEventsMonitor.swift` | 防抖全量 reload |
| `DirectoryMetadataOverlay.swift` | 大小/数量 revision 驱动 UI |

---

## 9. 推荐落地顺序（给排期用）

```mermaid
flowchart LR
    subgraph P0["P0 本周"]
        M1[Mermaid 串行]
        M2[缩放解耦]
        M3[宽度 debounce]
        P3[Pasteboard 缓存]
    end
    subgraph P1["P1 下周"]
        P1io[粘贴后台 I/O]
        M5[JS 懒加载]
        P5[FSEvents 去重]
    end
    subgraph P2["P2 随后"]
        P2inc[粘贴增量列表]
        M4[Mermaid 增量]
        FSE[ FSEvents 增量 ]
    end
    P0 --> P1 --> P2
```

若只能做 **3 件事**：**M2 缩放解耦** + **P3 Pasteboard 缓存** + **P1 粘贴后台 I/O**。三者改动集中、风险可控，对「变卡」体感的改善最明显。
