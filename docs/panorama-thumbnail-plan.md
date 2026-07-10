# 子目录全景缩略图（Panorama Thumbnail）— 开发计划

> 依据：[panorama-thumbnail-design.md](./panorama-thumbnail-design.md)（**树形递归全景**，已替代原胶片条方案）  
> 前置：[thumbnail-view-design.md](./thumbnail-view-design.md) Phase 1–2 已完成。  
> 目标：**PN-01 ~ PN-20** 渐进交付；MVP 为 **PN-01 ~ PN-17**。

---

## 总览

| Phase | 主题 | Issue 数 | 预估 | 用户可见 |
|-------|------|----------|------|----------|
| **A** | 基础设施与树数据层 | 5 | 2.5–3 天 | 否 |
| **B** | Display 模型与 Bootstrap | 3 | 2–2.5 天 | 否 |
| **C** | 缩略图调度 | 2 | 1.5–2 天 | 否 |
| **D** | UI 组件 | 5 | 3–4 天 | 是 |
| **E** | 集成与交互 | 4 | 2–2.5 天 | 是 |
| **F** | 稳定性、i18n、验收 | 3 | 1.5–2 天 | 部分 |

**MVP 最小集：** PN-01 ~ PN-17（PN-18 FSEvents 可后续补）。

**总预估：** 约 14–18 人天。

---

## 建议 PR 合并顺序

```
PN-01 → PN-02 → PN-03 → PN-04 ─┐
PN-10（GridCell，可并行）         ├→ PN-05 → PN-06 → PN-07
                                 ├→ PN-08 → PN-09
                                 └→ PN-11,12,13 → PN-14 → PN-15,16,17 → PN-18,19,20
```

---

## Phase A：基础设施与树数据层

### PN-01：子布局模式与持久化

**类型**：feat  
**依赖**：无  
**文件**：

- `Sources/FileList/FileListThumbnailLayoutMode.swift`（新建）
- `Sources/FileList/FileListStorageKeys.swift`
- `Sources/Explorer/ExplorerWindowLayoutState.swift`

**任务**：

- [x] `FileListThumbnailLayoutMode`：`grid` / `panorama`
- [x] 持久化 `explorer.fileList.thumbnailLayoutMode`，默认 `grid`
- [x] `PanoramaExpandDepthPolicy` + 键 `explorer.panorama.expandDepthPolicy`，默认 `automatic`

**验收**：

- [x] 单元测试 round-trip
- [x] 重启后设置保持

---

### PN-02：Panorama 常量与树模型

**类型**：feat  
**依赖**：PN-01  
**文件**：

- `Sources/Explorer/Panorama/PanoramaMetrics.swift`（新建）
- `Sources/Explorer/Panorama/PanoramaTreeModels.swift`（新建）

**任务**：

- [x] `PanoramaMetrics`（indent、cap=48、batch、maxCachedListings=32 等）
- [x] `PanoramaDirectoryNode`、`PanoramaListingState`、`PanoramaGridItem`、`PanoramaDisplayBlock`、`FolderHeaderModel`

**验收**：

- [x] 模型 Equatable / Identifiable 测试

---

### PN-03：PanoramaTreeDataSource

**类型**：feat  
**依赖**：PN-02  
**文件**：

- `Sources/Explorer/Panorama/PanoramaTreeDataSource.swift`（新建）
- `Tests/ExplorerTests/PanoramaTreeDataSourceTests.swift`（新建）

**任务**：

- [x] 维护 `nodesByPath`、`listing` 状态、`generation` token
- [x] `loadListing(for:)` async：`DirectoryListingLoader.loadFileItems` + 排序
- [x] `evictListing(for:)` → `.unloaded`；LRU 超过 32 目录
- [x] 网络卷 lightweight metadata
- [x] 参考 `FileListView.loadChildren` 错误映射（无权限、不存在）

**验收**：

- [x] 快速切换 path 时 stale 结果丢弃
- [x] LRU evict 后 listing 释放

---

### PN-04：collapsed / expanded 状态

**类型**：feat  
**依赖**：PN-02  
**文件**：

- `Sources/Explorer/Panorama/PanoramaTreeCollapseState.swift`（新建）
- `Tests/ExplorerTests/PanoramaTreeCollapseStateTests.swift`（新建）

**任务**：

- [x] `collapsedDirectoryIDs: Set<String>`
- [x] `collapse(_:)` / `expand(_:)` / `expandAll(under:)` / `collapseAll(under:)`
- [x] 进入全景：`clear()`（全部展开）
- [x] 可选：`collapse` 时是否自动 collapse 子孙 ID（推荐：仅标记节点自身，由 DisplayBuilder 截断子树）

**验收**：

- [x] collapse 后 DisplayBuilder 不再输出该子树 blocks
- [x] expandAll / collapseAll 正确

---

### PN-05：PanoramaTreeDisplayBuilder

**类型**：feat  
**依赖**： PN-02, PN-03, PN-04  
**文件**：

- `Sources/Explorer/Panorama/PanoramaTreeDisplayBuilder.swift`（新建）
- `Tests/ExplorerTests/PanoramaTreeDisplayBuilderTests.swift`（新建）

**任务**：

- [x] 纯函数：`build(rootPath:items:collapsedIDs:)` → 扁平 `[PanoramaDisplayBlock]` 或递归结构
- [x] 展开目录 → `folderHeader` + 递归 child blocks + `itemGrid`
- [x] 收起目录 → 仅出现在父 `itemGrid` 的 `.folderCollapsed`
- [x] 空目录 → 无 header，仅父 grid 中 folder cell
- [x] 网格排序：收起文件夹先于文件；`FileListSortEngine`
- [x] 应用 `itemsPerGridCap` + `overflow`

**验收**：

- [x] fixture：三层嵌套 + 部分 collapse → block 结构正确
- [x] 100 文件 → grid items = 47 + overflow(53)

---

## Phase B：Display 模型与 Bootstrap

### PN-06：PanoramaTreeBootstrapper

**类型**：feat  
**依赖**：PN-03, PN-05  
**文件**：

- `Sources/Explorer/Panorama/PanoramaTreeBootstrapper.swift`（新建）
- `Tests/ExplorerTests/PanoramaTreeBootstrapperTests.swift`（新建）

**任务**：

- [x] BFS 队列：`enqueue(path, priority)`；batch=4
- [x] `schedule(rootPath:depthPolicy:visiblePaths:)`
- [x] `automatic`：depth ≤ 2 high priority，其余 low
- [x] 滚动时 boost visible ±1 目录
- [x] 与 generation 协作 cancel

**验收**：

- [x] 500 子目录：不阻塞主线程，队列渐进完成
- [x] visible 目录优先于 offscreen

---

### PN-07：PanoramaTreeController

**类型**：feat  
**依赖**：PN-03, PN-04, PN-05, PN-06  
**文件**：

- `Sources/Explorer/Panorama/PanoramaTreeController.swift`（新建）
- `Tests/ExplorerTests/PanoramaTreeControllerTests.swift`（新建）

**任务**：

- [x] `@MainActor` 编排：dataSource + collapseState + displayBuilder + bootstrapper
- [x] `@Published displayBlocks` 或等价 `rootSection`
- [x] `onVisibleDirectoriesChanged(_:)` debounce 0.08s
- [x] `reset()` on path / mode change
- [x] `.meoFindMemoryPressure` → evict listings + scheduler shutdown
- [x] 暴露 `toggleCollapse`、`expandAll`、`collapseAll`

**验收**：

- [x] path 切换完整 reset
- [x] listing 更新 → display rebuild 正确

---

## Phase C：缩略图调度

### PN-08：PanoramaThumbnailScheduler

**类型**：feat  
**依赖**：PN-02  
**文件**：

- `Sources/Explorer/Panorama/PanoramaThumbnailScheduler.swift`（新建）
- `Tests/ExplorerTests/PanoramaThumbnailSchedulerTests.swift`（新建）

**任务**：

- [x] 多 grid 可见 cell 合并调度
- [x] `update(visibleRowIDs:orderedIDs:cellSize:)` ± radius
- [x] prune、`cancelInFlightRequests`、batch ≤ 8
- [x] `shutdown()` / `respondToMemoryPressure()`

**验收**：

- [x] 滚动后 image map 不超预算
- [x] 共用 `ThumbnailGenerator.shared`

---

### PN-09：PanoramaVisibleCellTracker

**类型**：feat  
**依赖**：无  
**文件**：

- `Sources/Explorer/Panorama/PanoramaVisibleCellTracker.swift`（新建）

**任务**：

- [x] `PreferenceKey` 上报 grid cell frame
- [x] 汇总 `visibleRowIDs`、可见目录 path 集合
- [x] debounce 对接 controller + scheduler

**验收**：

- [x] 快速滚动不触发 load 风暴

---

## Phase D：UI 组件

### PN-10：PanoramaGridCellView

**类型**：feat  
**依赖**：无（可并行）  
**文件**：

- `Sources/Explorer/Panorama/PanoramaGridCellView.swift`（新建）

**任务**：

- [x] 对齐 `FileListThumbnailCellView` 视觉（placeholder、QL 图、文件名 overlay、大小角标）
- [x] 选中态、hover（若 `rowHoverHighlight` 启用）
- [x] 收起态文件夹：叠加 `[▶]` 展开 affordance
- [x] 参数：`cellSize`、`image`、`row`、`isSelected`

**验收**：

- [x] 与标准缩略图格子视觉一致

---

### PN-11：PanoramaFolderHeaderView

**类型**：feat  
**依赖**：PN-02  
**文件**：

- `Sources/Explorer/Panorama/PanoramaFolderHeaderView.swift`（新建）

**任务**：

- [x] 缩进、`[▼]` 折叠钮、图标、名称、项数、loading/error
- [x] 点击折叠钮 → `onCollapse`
- [x] 点击名称 → `onEnterDirectory`

**验收**：

- [x] depth=0,1,3 缩进正确
- [x] VoiceOver 可读

---

### PN-12：PanoramaItemGridView + OverflowCell

**类型**：feat  
**依赖**：PN-02, PN-10  
**文件**：

- `Sources/Explorer/Panorama/PanoramaItemGridView.swift`（新建）
- `Sources/Explorer/Panorama/PanoramaOverflowCellView.swift`（新建）

**任务**：

- [x] `LazyVGrid` 动态列数（按 depth 减 availableWidth）
- [x] 渲染 file / folderCollapsed / overflow
- [x] 单击、⌘ 单击、双击回调
- [x] overflow → 进入目录

**验收**：

- [x] 窄 depth 深层 grid 列数减少合理
- [x] 48+ 出现 +N

---

### PN-13：PanoramaFolderSectionView（递归）

**类型**：feat  
**依赖**：PN-11, PN-12  
**文件**：

- `Sources/Explorer/Panorama/PanoramaFolderSectionView.swift`（新建）

**任务**：

- [x] 组合 header + 递归 child sections + item grid
- [x] 稳定 `id`（directory path）避免 collapse 动画丢 state
- [x] 对接 `imageByRowID` from scheduler

**验收**：

- [x] 三层嵌套渲染正确
- [x] collapse 子树后 UI 节点数下降

---

### PN-14：PanoramaTreeView 主视图

**类型**：feat  
**依赖**：PN-07, PN-08, PN-09, PN-13  
**文件**：

- `Sources/Explorer/Panorama/PanoramaTreeView.swift`（新建）

**任务**：

- [x] `ScrollView` + 根 `PanoramaFolderSectionView`
- [x] 绑定 `PanoramaTreeController`
- [x] loading skeleton（未 load 目录 header 显示 skeleton）
- [x] ⌘+滚轮 → `onThumbnailCellSizeChange`
- [x] onAppear/onChange path/items/mode

**验收**：

- [x] 首帧 < 100ms 骨架（50 子目录 fixture）
- [x] 滚动触发 bootstrap + thumbnails

---

## Phase E：集成与交互

### PN-15：FileListView 接入

**类型**：feat  
**依赖**：PN-14, PN-01  
**文件**：

- `Sources/Explorer/FileListView.swift`
- `Sources/Explorer/ContentView.swift`

**任务**：

- [x] `thumbnailLayoutMode == .panorama` → `PanoramaTreeView`
- [x] 搜索非空 / loading → 强制 grid 或禁用
- [x] 离开 panorama → `controller.shutdown()`

**验收**：

- [x] grid ↔ panorama 无 crash

---

### PN-16：工具栏与批量展开/收起

**类型**：feat  
**依赖**：PN-01, PN-15  
**文件**：

- `Sources/Explorer/Toolbar/ExplorerToolbarItemViews.swift`
- `Sources/Explorer/Toolbar/ExplorerToolbarEnvironment.swift`

**任务**：

- [x] 缩略图 layout Menu（标准网格 / 子目录全景）
- [x] 全景模式下「全部展开」「全部收起」按钮
- [x] 展开深度 Picker（自动 / 2 / 5 / 全部）
- [ ] 可选快捷键 `Cmd+Shift+2`

**验收**：

- [x] 设置持久化；全部收起后仅根层 grid 可见

---

### PN-17：Selection 与导航

**类型**：feat  
**依赖**：PN-15  
**文件**：

- `Sources/Explorer/Panorama/PanoramaTreeView.swift`
- `Sources/Explorer/Panorama/PanoramaItemGridView.swift`

**任务**：

- [x] 单击 / ⌘ 单击 → `selection` binding
- [x] 双击文件 → 打开；双击文件夹格 → 进入目录
- [ ] collapse/expand 后同一 item selection 尽量保持（按 row.id）
- [ ] 预览面板同步

**验收**：

- [ ] 跨层级、跨 grid 多选
- [ ] 收起含选中项的目录 → selection 仍指向该 folder item

---

## Phase F：稳定性、i18n、验收

### PN-18：FSEvents 增量刷新

**类型**：feat  
**依赖**：PN-07, PN-15  
**文件**：

- `Sources/Explorer/Panorama/PanoramaTreeController.swift`

**任务**：

- [ ] 监听已 load 目录 path 变更
- [ ] 单目录 re-listing + display rebuild
- [ ] debounce coalesce

**验收**：

- [ ] 外部新增文件后对应 grid 更新

---

### PN-19：i18n

**类型**：feat  
**依赖**：PN-11, PN-12, PN-16  
**文件**：

- `Sources/Explorer/Resources/Localizable.xcstrings`
- `Sources/Explorer/L10n.swift`
- `Tests/ExplorerTests/L10nTests.swift`

**任务**：

- [ ] 设计文档 §十一全部键
- [ ] `L10n.Panorama.*`
- [ ] `XCTAssertNotEqual` 覆盖

**验收**：

- [ ] 中英文无键名

---

### PN-20：测试与性能验收

**类型**：test  
**依赖**：全部  
**文件**：

- `Tests/ExplorerTests/Panorama*.swift`

**任务**：

- [ ] 补全单元测试
- [ ] 手动 + Instruments 清单（见下）
- [ ] 记录 profile 基准到 PR 描述

**验收**：

- [ ] `swift test` 通过
- [ ] 设计文档 §八指标达标

---

## 手动测试清单（MVP）

| # | 场景 | 预期 |
|---|------|------|
| 1 | 进入全景，三层嵌套目录 | 逻辑全展开；depth≤2 先 load，更深层渐进 |
| 2 | 点击 [▼] 收起 Photos | 子树消失；父 grid 出现 Photos 文件夹格 |
| 3 | 点击 [▶] 或双击收起格 | 子树恢复 |
| 4 | 全部收起 | 仅根层 grid（文件夹+文件） |
| 5 | 全部展开 | 恢复完整树 UI |
| 6 | 某层 200 文件 | 48 格 + `+N` |
| 7 | 500+ 子目录项目 | 不 freeze；BFS 渐进 |
| 8 | ⌘ 多选跨层级 | selection + 预览正确 |
| 9 | grid ↔ panorama ×20 | 无 QL 泄漏 |
| 10 | 内存压力 | listing evict + 缩略图回收 |
| 11 | 网络卷 | lightweight + workspace 图标 |
| 12 | 搜索激活 | 全景不可用 |
| 13 | 空文件夹 | 无标题行，仅父 grid 一格 |
| 14 | 中英文 | 无键名 |

---

## Phase 2 Backlog

| ID | 主题 |
|----|------|
| PN-21 | 框选 |
| PN-22 | 拖放 |
| PN-23 | 按 rootPath 持久化 collapsed 集合 |
| PN-24 | 扩展名过滤（仅图片等） |
| PN-25 | 抽取 `FileTreeListingService` 与列表模式共用 |
| PN-26 | 单目录总大小 overlay |

---

## 与原 PV 任务对照（已废弃）

| 原 PV | 状态 | 树形方案对应 |
|-------|------|--------------|
| PV-03 PanoramaRootBuilder | 废弃 | → PN-05 DisplayBuilder |
| PV-04 SectionLoader | 废弃 | → PN-03 DataSource + PN-06 Bootstrapper |
| PV-08 ThumbnailStripCell | 废弃 | → PN-10 GridCellView |
| PV-09 SectionStripView | 废弃 | → PN-12 ItemGridView |
| PV-10 VisibleRangeTracker | 重构 | → PN-09 VisibleCellTracker |
