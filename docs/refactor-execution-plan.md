# Explorer 重构执行计划

> 对应 `docs/code-review-report.md` Phase A–E。  
> 最后更新：2026-06-23

## 状态图例

| 标记 | 含义 |
|------|------|
| ✅ | 已完成 |
| 🔄 | 部分完成 / 进行中 |
| ⏸ | 暂缓（需设计评审或依赖前置项） |

---

## Phase A — 低风险 ✅

- ✅ `ShellQuoting`、图标缓存、泛型 ColumnProvider、SnippetDisplayCommand

## Phase B — FileList 双轨 ✅

- ✅ `FileListContentController`、`FileListInteractionCoordinator`、`FileListRenameCoordinator`
- ✅ `FileListDirectoryMetadataRefresh`、`FileListListingSignature`、`padding 可见行更新`
- 🔄 Table/Thumbnail 仍保留模式专属扩展（Interaction / Rename / DragDrop / Host-View）

## Phase C — Explorer 瘦身 ✅

### AppModule 拆分 ✅

| 文件 | 内容 | 行数（约） |
|------|------|-----------|
| `AppModule.swift` | `@main`、命令、Lucide 工具栏图标 | ~430 |
| `ContentView.swift` | 主窗口编排、`loadItems` | ~1,108 |
| `PathBarView.swift` | 地址栏 + 工具栏输入焦点 | ~1,902 |
| `FileListView.swift` | 列表壳 + 元数据桥接 | ~662 |
| `SidebarView.swift` | 侧栏 + 卷挂载 | ~563 |
| `Preview/PreviewViews.swift` | 侧栏预览壳（`FilePreviewView`） | ~142 |
| `Preview/Views/*` | 各类型预览视图（HTML/Text/Image/PDF/Archive/Media 等） | ~2,300 |
| `Domain/*` | `FileItem`、`TrashLoader`、`FileOperations` 等 | — |

### 基础设施 ✅

- ✅ `DirectoryListingLoader`、`DirectoryMetadataScheduler`、`DirectoryMetadataService<Entry>`
- ✅ `ProcessOutputStreamer`、`OutputPanelPresenter`、`SnippetExecutionService`
- ✅ Archive 统一 `ArchivePreviewLoader.listArchiveEntries`

## Phase D — Preview 子系统 ✅

- ✅ `PreviewCapability`、`PreviewChromeView`、`PreviewSessionStateReset`、`PreviewSessionViewModifiers`
- ✅ `PreviewSession` 嵌套状态（`PreviewSessionNestedState` + `session.image.*` 绑定迁移）
- ✅ `PreviewContentLoader` / `PreviewLoadRoute` / `PreviewLoadPayload` 加载管道拆分
- ✅ `DirectoryMetadataServiceTests`、`PreviewCapabilityTests`、`PreviewLoadDispatchTests`

## Phase E — 收尾、测试与薄抽象 🔄 进行中

> 来源：代码审查报告「未完成项」复核（2026-06-23）。  
> **E1–E3 首批评审已完成（2026-06-23）**；E4–E7 待后续 PR。

### E1 — 文档与状态同步

| # | 任务 | 状态 |
|---|------|------|
| E1.1 | 本计划补充 Phase E；Phase D 标为已完成 | ✅ |
| E1.2 | `code-review-report.md` 第七节 Phase D 勾选与结论同步 | ✅ |

### E2 — 测试基建（P3）

| # | 任务 | 状态 |
|---|------|------|
| E2.1 | 新增 `FileListTests` target（`Package.swift`） | ✅ |
| E2.2 | `FileListListingSignatureTests` | ✅ |
| E2.3 | `FileListInteractionCoordinatorTests`（纯函数：快速搜索字符、框选行） | ✅ |
| E2.4 | `DirectoryListingLoaderTests`（枚举选项、临时目录映射） | ✅ |
| E2.5 | `FileListRow+FileItem` 映射边界测试 | ⏸ |
| E2.6 | `SnippetExecutor` / `ShellRunner` mock Process 测试 | ⏸ |
| E2.7 | `WindowSnapCoordinator` / `FavoritesSidebarHost` 几何与数据层测试 | ⏸ |
| E2.8 | `ThumbnailGenerator` 纯逻辑测试 | ⏸ |

### E3 — 小范围去重与薄抽象（低风险）

| # | 任务 | 状态 |
|---|------|------|
| E3.1 | `ThumbnailImageCost` — 合并 `estimatedCost(of:)` 重复 | ✅ |
| E3.2 | 删除 `ThumbnailCache.entry(for:)` 同步磁盘路径（死代码） | ✅ |
| E3.3 | `SnippetStore.visibleSnippets(...)` — 统一面板与右键菜单可见性 | ✅ |
| E3.4 | `ShellProcessRunner` — `ArchivePreviewLoader` 超时 shell 统一 | ✅ |
| E3.5 | `DestructiveActionConfirmer` — Snippet 危险命令 NSAlert 统一 | ✅ |
| E3.6 | `typealias FileListContentInteraction = FileListTableInteraction` | ✅ |
| E3.7 | `estimatedCost` / `rowsInVerticalRange` 等于已在 Phase B 处理项 — 仅文档标注 | ✅ |

### E4 — FileList 双轨残余（中风险，分批 PR）

| # | 任务 | 状态 |
|---|------|------|
| E4.1 | `FileListRenamePresenter` — 表格 cell vs 缩略图 cell 可插拔 UI | ✅ |
| E4.2 | DragDrop 扩展合并或共享 `FileListDragDropSupport` 深化 | ✅ |
| E4.3 | `FileListTableController` 继续拆 `+ColumnLayout` / `+CellConfiguration` | ✅ |
| E4.4 | `FileListThumbnailCellView` 拆 `+Layout` / `+Rename` | ⏸ |
| E4.5 | `FileListRowMutation` / Builder — 消除 `withX` 17 字段复制 | ⏸ |
| E4.6 | `FileListColumnLayout.lastDataColumnMaxX` 统一列尾 X | ⏸ |
| E4.7 | `FileListHighlighting` 搜索高亮循环合并 | ⏸ |
| E4.8 | `FileListContentView` 基类 — 深化 `FileListDraggingDestinationSupport` | ⏸ |

### E5 — Explorer 薄抽象与中风险重构

| # | 任务 | 状态 |
|---|------|------|
| E5.1 | `DirectoryMetadataOverlay` 合并 size/count 两个 Overlay | ✅ |
| E5.2 | `FolderPreviewView.itemCountText` 单一数据源（overlay 优先，去掉 loadResult 回退或反之） | ✅ |
| E5.3 | 目录大小双重门控（参数 + `DirectorySizePreferences`）文档化或收敛 | ⏸ |
| E5.4 | `PanelResizeHandle` — `VerticalResizeDivider` + `OutputPanelResizeHandle` 统一 | ⏸ |
| E5.5 | `AppPreferences` / `UserDefaultsBacked` 偏好注册表 | ✅ |
| E5.6 | `ExplorerCore` 第三 target 评估与试点（`ShellQuoting` + `ProcessRunner`） | ⏸ |
| E5.7 | Browser 预取共享抽象（content / strip thumbnail / debounce） | ⏸ |
| E5.8 | `SnippetMinimalButtonView` / `SnippetListItemView` UI 合并 | ⏸ |

### E6 — 性能热点（P2）

| # | 任务 | 状态 |
|---|------|------|
| E6.1 | 缩略图主线程同步磁盘读 | ✅ `prepareThumbnailItem` 已仅内存 + 异步 `loadEntry` |
| E6.2 | 移除 `ThumbnailCache.entry` 同步磁盘 API | ✅ |
| E6.3 | 框选 O(n) `layoutAttributesForItem` | ✅ `FileListThumbnailCollectionLayoutSupport` |
| E6.4 | `setDropHighlight` 全可见项遍历 | ✅ 仅更新 previous/new item |
| E6.5 | 列表变更全量 `reloadData` 增量优化 | ✅ 排序/搜索用 `reloadItems`，listing/cellSize 仍 `reloadData` |
| E6.6 | `ThumbnailDiskCache.store` 改 async（已 async，无 sync 写） | ✅ |
| E6.7 | `workspaceIconCache` 达上限全清 → LRU 逐出 | ✅ 已有 `FileListWorkspaceIconCache` LRU |
| E6.8 | `QLConcurrencyGate.waitUntilIdle` 轮询改条件变量 | ✅ `NSCondition` |
| E6.9 | `FileListSortEngine` 树模式 Dictionary 缓存 | ⏸ |

### E7 — 大文件拆分（单独 PR）

| # | 任务 | 状态 |
|---|------|------|
| E7.1 | `PreviewViews.swift`（~2,465 行）按预览类型拆文件 | ✅ |
| E7.2 | `FavoritesSidebarHost` 数据层抽离 + 测试 | ✅ |

---

## 横切 ⏸

- ⏸ `FileListTableInteraction` 全面重命名为 `FileListContentInteraction`（当前仅 typealias）
- 🔄 `UserDefaults` 键迁入 `AppPreferences`（E5.5 注册表 + 主要读写点已迁移；`ExplorerAppSettings` 保留兼容转发）
- ⏸ `FavoritesSidebarHost` 数据层抽离（见 E7.2）

---

## 当前执行顺序（Phase E）

1. ~~**E1** 文档同步~~ ✅  
2. ~~**E2.1–E2.4** `FileListTests` + 核心纯函数/加载器测试~~ ✅  
3. ~~**E3.1–E3.6** 去重与薄抽象~~ ✅  
4. ~~**E7.1 PreviewViews 拆分**~~ ✅  
5. ~~**E4.1 FileListRenamePresenter**~~ ✅  
6. ~~**E5.1 DirectoryMetadataOverlay 合并**~~ ✅  
7. ~~**E7.2 FavoritesSidebarHost 数据层抽离**~~ ✅  
8. ~~**E5.2 FolderPreviewView 子项数量单一数据源**~~ ✅  
9. ~~**E4.2 DragDrop 合并**~~ ✅  
10. ~~**E6 缩略图性能热点**~~ ✅  
11. ~~**E4.3 FileListTableController 拆分**~~ ✅  
12. ~~**E5.5 AppPreferences 注册表**~~ ✅  
13. **E6.9 / E4.4** 按 ROI 分批后续 PR

---

## 下一步建议（E5.5 完成后）

1. `FileListSortEngine` 树模式 Dictionary 缓存（E6.9）  
2. `FileListThumbnailCellView` 拆分（E4.4）  
3. 目录大小双重门控文档化（E5.3）  
