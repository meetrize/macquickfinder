# 子目录全景缩略图（Panorama Thumbnail）— 开发计划

> 依据：[panorama-thumbnail-design.md](./panorama-thumbnail-design.md)  
> 前置：[thumbnail-view-design.md](./thumbnail-view-design.md) Phase 1–2 已完成（标准缩略图网格 + QL 缓存）。  
> 目标：按 **PV-01 ~ PV-18** 渐进交付；MVP 为 **PV-01 ~ PV-15**（一级子目录 + 按需加载 + 基础交互）。

---

## 总览

| Phase | 主题 | Issue 数 | 预估 | 用户可见 |
|-------|------|----------|------|----------|
| **A** | 基础与数据模型 | 4 | 1.5–2 天 | 否 |
| **B** | 缩略图调度（性能核心） | 2 | 1.5–2 天 | 否 |
| **C** | UI 组件 | 5 | 2–3 天 | 是 |
| **D** | 集成与交互 | 4 | 1.5–2 天 | 是 |
| **E** | 稳定性与 i18n | 3 | 1–2 天 | 部分 |

**MVP 最小集：** PV-01 ~ PV-15（可跳过 PV-16 FSEvents，后续补）。

---

## 建议 PR 合并顺序

```
PV-01 → PV-02 → PV-03 → PV-04 ─┐
PV-08（可并行）                  ├→ PV-05 → PV-06 → PV-07,09,10 → PV-11
                                 └→ PV-12 → PV-13,14,15 → PV-16,17,18
```

---

## Phase A：基础与数据（无 UI）

### PV-01：子布局模式与持久化

**类型**：feat  
**依赖**：无  
**文件**：

- `Sources/FileList/FileListThumbnailLayoutMode.swift`（新建）
- `Sources/FileList/FileListStorageKeys.swift`（追加键）
- `Sources/Explorer/ExplorerWindowLayoutState.swift`（追加字段）

**任务**：

- [ ] 定义 `FileListThumbnailLayoutMode`：`grid` / `panorama`
- [ ] 持久化键 `explorer.fileList.thumbnailLayoutMode`
- [ ] `ExplorerWindowLayoutState.thumbnailLayoutMode` 读写 UserDefaults
- [ ] 默认值为 `grid`（不影响现有用户）

**验收**：

- [ ] 单元测试读写 round-trip
- [ ] 重启应用后子模式保持

---

### PV-02：Panorama 数据模型

**类型**：feat  
**依赖**：PV-01  
**文件**：

- `Sources/Explorer/Panorama/PanoramaMetrics.swift`（新建）
- `Sources/Explorer/Panorama/PanoramaModels.swift`（新建）

**任务**：

- [ ] `PanoramaMetrics` 常量（cap、prefetch、debounce、maxConcurrentSections）
- [ ] `PanoramaSectionID`、`PanoramaSectionLoadState`、`PanoramaSectionModel`
- [ ] `PanoramaRootModel`

**验收**：

- [ ] 模型 `Equatable` 测试通过
- [ ] cap / prefetch 常量与设计文档一致

---

### PV-03：PanoramaRootBuilder

**类型**：feat  
**依赖**：PV-02  
**文件**：

- `Sources/Explorer/Panorama/PanoramaRootBuilder.swift`（新建）
- `Tests/ExplorerTests/PanoramaRootBuilderTests.swift`（新建）

**任务**：

- [ ] 从 `[FileItem]` 分离 `currentDirectoryFiles` 与 `sections`（仅直接子文件夹）
- [ ] 复用 `FileListSortEngine` 排序 sections 与 current files
- [ ] 为每个 section 计算稳定 `accentHue`
- [ ] **零 I/O**：不 enumerate 子目录

**验收**：

- [ ] fixture：混合文件/文件夹 → 正确分区数
- [ ] 排序与列表模式一致
- [ ] 无子文件夹时 sections 为空

---

### PV-04：PanoramaSectionLoader

**类型**：feat  
**依赖**：PV-02  
**文件**：

- `Sources/Explorer/Panorama/PanoramaSectionLoader.swift`（新建）
- `Tests/ExplorerTests/PanoramaSectionLoaderTests.swift`（新建）

**任务**：

- [ ] 单目录 async enumerate（`DirectoryListingLoader.loadFileItems`）
- [ ] generation token 取消 stale 结果
- [ ] 后台排序 + cap 切片（`itemsPerSectionCap = 24`）
- [ ] 网络卷 lightweight metadata
- [ ] 返回 `(totalCount, displayRows, overflowCount)`

**验收**：

- [ ] 快速切换目录时旧 enumerate 不上屏
- [ ] 1000 文件目录 cap 后 displayRows.count == 24
- [ ] 失败态 `.failed` 可观测

---

## Phase B：缩略图调度（性能核心）

### PV-05：PanoramaThumbnailScheduler

**类型**：feat  
**依赖**：PV-02  
**文件**：

- `Sources/Explorer/Panorama/PanoramaThumbnailScheduler.swift`（新建）
- `Tests/ExplorerTests/PanoramaThumbnailSchedulerTests.swift`（新建）

**任务**：

- [ ] 参考 `PreviewBrowserStripThumbnailLoader` 实现多 section 版本
- [ ] `update(request:)` 合并可见 cell index ± `thumbnailPrefetchRadius`
- [ ] `loadGeneration++` → `cancelInFlightRequests()` + prune `imageByRowID`
- [ ] placeholder → memory cache → async `ThumbnailGenerator.load`
- [ ] 全局 in-flight batch ≤ 8
- [ ] `shutdown()` / `respondToMemoryPressure()`

**验收**：

- [ ] 模拟滚动后 `imageByRowID` 键数不超过可见窗口预算
- [ ] generation 不匹配时回调丢弃
- [ ] 与 `ThumbnailGenerator.shared` 共用缓存

---

### PV-06：PanoramaController

**类型**：feat  
**依赖**：PV-03, PV-04, PV-05  
**文件**：

- `Sources/Explorer/Panorama/PanoramaController.swift`（新建）
- `Tests/ExplorerTests/PanoramaControllerTests.swift`（新建）

**任务**：

- [ ] `@MainActor` 编排 root build、section load、scheduler update
- [ ] `updateVisibleSections(_:)` debounce 0.08s
- [ ] section evict：超过 `maxConcurrentSections` LRU 淘汰 → `.idle`
- [ ] `reset()` on path change；generation++
- [ ] 监听 `.meoFindMemoryPressure` → evict all + scheduler shutdown
- [ ] 暴露 `@Published rootModel`、`imageByRowID`（或透传 scheduler）

**验收**：

- [ ] path 切换无 stale 回调
- [ ] evict 后 section `displayRows` 释放
- [ ] Instruments：典型场景内存增量 ≤ +15MB

---

## Phase C：UI 组件

### PV-07：PanoramaSectionHeaderView

**类型**：feat  
**依赖**：PV-02  
**文件**：

- `Sources/Explorer/Panorama/PanoramaSectionHeaderView.swift`（新建）

**任务**：

- [ ] 4pt 色条 + 文件夹图标 + 名称 + 项数 + 进入 affordance
- [ ] loading / failed / empty 状态文案占位（i18n 键先用常量，PV-17 补全）
- [ ] 点击 → `onEnterDirectory`
- [ ] 深浅色模式适配

**验收**：

- [ ] 视觉与 `FileListThumbnailMetrics` token 协调
- [ ] VoiceOver label 含文件夹名与项数

---

### PV-08：ThumbnailStripCellView 抽离

**类型**：refactor  
**依赖**：无（可并行）  
**文件**：

- `Sources/Explorer/Panorama/ThumbnailStripCellView.swift`（新建）
- `Sources/Explorer/Preview/Browser/PreviewBrowserStripCell.swift`（改为复用）

**任务**：

- [ ] 从 `PreviewBrowserStripCell` 抽公共 cell 视觉（缩略图 + 选中态 + 文件名）
- [ ] 支持 `cellSize` 参数（全景模式用 `thumbnailCellSize`）
- [ ] 保持预览条现有行为不变

**验收**：

- [ ] Preview Browser Strip 回归通过
- [ ] 全景 cell 与 strip cell 视觉一致

---

### PV-09：PanoramaSectionStripView

**类型**：feat  
**依赖**：PV-07, PV-08  
**文件**：

- `Sources/Explorer/Panorama/PanoramaSectionStripView.swift`（新建）
- `Sources/Explorer/Panorama/PanoramaOverflowCellView.swift`（新建）

**任务**：

- [ ] `ScrollView(.horizontal)` + `LazyHStack`
- [ ] 渲染 `displayRows` + 末尾 `+N` overflow cell
- [ ] 绑定 `imageByRowID`、selection、双击/单击回调
- [ ] overflow 点击 → `onEnterDirectory`

**验收**：

- [ ] 24+ 文件时出现 `+N`
- [ ] 横向滚动流畅；⌘+滚轮不冲突（由父视图处理）

---

### PV-10：PanoramaVisibleRangeTracker

**类型**：feat  
**依赖**：无  
**文件**：

- `Sources/Explorer/Panorama/PanoramaVisibleRangeTracker.swift`（新建）

**任务**：

- [ ] `PreferenceKey` 上报各 section 的 frame 与可见比例
- [ ] 计算 `visibleSectionIDs` 与 `prefetchSectionIDs`（±1）
- [ ] debounce 与 controller 对接

**验收**：

- [ ] 滚动时 visible ID 集合正确
- [ ] 快速 flick 不产生重复 load 风暴（debounce 生效）

---

### PV-11：PanoramaView 主视图

**类型**：feat  
**依赖**： PV-06, PV-09, PV-10  
**文件**：

- `Sources/Explorer/Panorama/PanoramaView.swift`（新建）

**任务**：

- [ ] `ScrollView` + `LazyVStack` 组装 sections
- [ ] 可选「当前目录」块（`currentDirectoryFiles` 非空时）
- [ ] 接入 `PanoramaController`；onAppear/onChange path/items
- [ ] loading placeholder（可复用 `FileListLoadingPlaceholderView` 变体或 skeleton）
- [ ] ⌘+滚轮 → `onThumbnailCellSizeChange`

**验收**：

- [ ] 5 个子目录目录：首帧骨架 < 100ms（本地 SSD）
- [ ] 滚动分区时 lazy enumerate + 缩略图加载
- [ ] 空目录、仅文件、仅文件夹三种布局正确

---

## Phase D：集成与交互

### PV-12：FileListView 接入

**类型**：feat  
**依赖**：PV-11, PV-01  
**文件**：

- `Sources/Explorer/FileListView.swift`
- `Sources/Explorer/ContentView.swift`（传入 `thumbnailLayoutMode`）

**任务**：

- [ ] `viewMode == .thumbnail` 下按 `thumbnailLayoutMode` 分支
- [ ] 搜索非空 / `isLoading` 时强制 grid 或禁用 panorama
- [ ] 切换离开 panorama 时 `controller.shutdown()`

**验收**：

- [ ] grid ↔ panorama 切换无 crash
- [ ] 搜索时不会进入 panorama

---

### PV-13：工具栏子模式 Menu

**类型**：feat  
**依赖**：PV-01, PV-12  
**文件**：

- `Sources/Explorer/Toolbar/ExplorerToolbarItemViews.swift`
- `Sources/Explorer/Toolbar/ExplorerToolbarEnvironment.swift`

**任务**：

- [ ] 缩略图模式下显示 layout Menu（标准网格 / 子目录全景）
- [ ] 绑定 `ExplorerWindowLayoutState.thumbnailLayoutMode`
- [ ] 可选快捷键 `Cmd+Shift+2` 切换子模式

**验收**：

- [ ] 仅缩略图模式显示 Menu
- [ ] 选择持久化

---

### PV-14：Selection 同步

**类型**：feat  
**依赖**：PV-12  
**文件**：

- `Sources/Explorer/Panorama/PanoramaView.swift`
- `Sources/Explorer/Panorama/PanoramaSectionStripView.swift`

**任务**：

- [ ] 单击更新 `selection: Set<FileItem.ID>`
- [ ] ⌘ 单击 toggle；⇧ 范围选（首版可仅 ⌘ multi-select）
- [ ] 选中态视觉与标准缩略图一致（accent border）
- [ ] 选中变化 → 右侧预览面板同步

**验收**：

- [ ] 跨分区多选
- [ ] 预览面板显示最后选中项

---

### PV-15：导航交互

**类型**：feat  
**依赖**：PV-12  
**文件**：

- `Sources/Explorer/Panorama/PanoramaView.swift`
- `Sources/Explorer/Panorama/PanoramaSectionHeaderView.swift`

**任务**：

- [ ] 分区标题点击 → `onItemOpen(folderItem)`
- [ ] `+N` 点击 → 同上
- [ ] 双击文件夹 cell → 进入目录
- [ ] 双击文件 → `onItemOpen(file, preview)`

**验收**：

- [ ] 进入子目录后 path 更新、全景 rebuild
- [ ] 返回上级（path 变化）正常工作

---

## Phase E：稳定性与 i18n

### PV-16：FSEvents 增量刷新

**类型**：feat  
**依赖**：PV-06, PV-12  
**文件**：

- `Sources/Explorer/Panorama/PanoramaController.swift`
- `Sources/Explorer/ContentView.swift`（或现有 FSEvents 桥接）

**任务**：

- [ ] 监听当前目录及已加载子目录路径变更
- [ ] 仅 refresh 受影响 `sectionID` 或 `currentDirectoryFiles`
- [ ] coalesce 多次事件（debounce）

**验收**：

- [ ] 外部增删文件后对应分区更新
- [ ] 未加载分区不受影响

---

### PV-17：i18n

**类型**：feat  
**依赖**：PV-07, PV-09, PV-13  
**文件**：

- `Sources/Explorer/Resources/Localizable.xcstrings`
- `Sources/Explorer/L10n.swift`
- `Tests/ExplorerTests/L10nTests.swift`

**任务**：

- [ ] 子模式名、当前目录、项数、`+N`、空文件夹、加载失败等键
- [ ] `en` + `zh-Hans`，`state: translated`
- [ ] `L10n.Panorama.*` 类型安全访问
- [ ] `XCTAssertNotEqual(L10n.…, "键名")`

**验收**：

- [ ] 中英文切换无键名泄露

---

### PV-18：测试与性能清单

**类型**：test / docs  
**依赖**：全部  
**文件**：

- `Tests/ExplorerTests/Panorama*.swift`
- `docs/panorama-thumbnail-design.md`（验收指标章节）

**任务**：

- [ ] 补全 controller / loader / scheduler 单元测试
- [ ] 手动测试清单：50 子目录、1000 文件/区、网络卷、内存压力
- [ ] Instruments profile 记录（首帧、内存、QL 并发）

**验收**：

- [ ] `swift test` 通过
- [ ] 设计文档 §六指标达标

---

## 手动测试清单（MVP）

| # | 场景 | 预期 |
|---|------|------|
| 1 | 打开含 5 个子目录的目录，切到子目录全景 | 首帧仅标题，无卡顿 |
| 2 | 缓慢纵向滚动 | 视口内分区 lazy 加载缩略图 |
| 3 | 某子目录 100+ 文件 | 仅 24 格 + `+N` |
| 4 | 点击 `+N` / 标题 | 进入子目录 |
| 5 | ⌘ 点击多选跨分区 | selection 正确，预览同步 |
| 6 | grid ↔ panorama 切换 20 次 | 无泄漏，QL 归零 |
| 7 | 搜索激活 | 全景不可用 |
| 8 | 内存压力通知 | 缩略图回收，可继续滚动 reload |
| 9 | 网络卷子目录 | lightweight 列举，workspace 图标 |
| 10 | 中英文界面 | 无键名 |

---

## Phase 2 Backlog（不在 MVP）

| ID | 主题 |
|----|------|
| PV-19 | 递归深度 2+（扁平 path 分组） |
| PV-20 | 分区折叠 + 持久化 |
| PV-21 | 框选（AppKit 协调器） |
| PV-22 | 拖放移动/复制 |
| PV-23 | 扩展名过滤（仅图片等） |
| PV-24 | 分区内「胶片 / 网格」布局切换 |
