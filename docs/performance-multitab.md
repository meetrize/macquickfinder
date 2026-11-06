# 多标签界面响应速度：分析与优化

> 目标：多标签打开后，点击、切标签、滚动列表仍应迅速可操作。

## 技术背景

- **壳**：AppKit `NSWindow` 原生标签（每个标签是独立 window，同属一个 `tabGroup`）
- **内容**：每标签一棵完整 `ContentView`（SwiftUI）+ `FileList`（`NSTableView` / 缩略图）+ 可选预览 / 双栏 / Git / 输出面板
- **共享单例**：`DirectoryMetadataOverlay`、`DirectoryFSEventsMonitor`、`ThumbnailGenerator`、`PreviewDetachCoordinator`、`FileListFocusRegistry` 等

因此标签数 N 上升时，若不加约束，主线程成本近似 **O(N × 列表刷新)**，体感会从「偶发卡顿」变成「几乎无法操作」。

## 应优先思考的维度

| 维度 | 问题 | 方向 |
|------|------|------|
| 非活动标签是否仍干活 | 后台标签仍 `updateNSView` / 元数据列刷新 / 通知处理 | **选中标签才刷新**；后台只积压 snapshot |
| 共享 Observable 刷新面 | `@ObservedObject` 挂在 `ContentView` 上 → 一处 revision 重绘所有标签整树 | 下沉到叶子 / 改用 `onReceive` 单字段 |
| 元数据广播 | `DirectoryMetadataAppKitBridge` 曾 `forEachTable` 打到全部控制器 | 改为 `forEachSelectedTabTable` |
| 进程级会话 | FSEvents / Git 监视 | 已有 key-window claim；保持「仅前台接管」 |
| 预览常驻 | 每标签内联大图/PDF | 切走释放解码内容，切回再加载 |
| 主线程 I/O | listing 增量刷新、目录大小 | 后台标签跳过；前台已 `Task.detached` |
| 测量 | 多标签 + 切标签 + 点击 | Release 安装后 sample / 体感；Instruments Time Profiler |

## 本轮已落地

1. **`FileListFocusRegistry`**：`isSelectedTabWindow` / `forEachSelectedTabTable(Thumbnail)`  
2. **`DirectoryMetadataAppKitBridge`**：元数据列只刷新选中标签（双栏同窗仍都会更新）  
3. **`FileListTable/ThumbnailController.update`**：非选中标签延后 listing 应用，`didBecomeKey` 时 `flushSuspendedListingIfNeeded`  
4. **`ContentView`**：去掉对 `PreviewDetachCoordinator` 的整树观察；listing/Git/归档等通知加 `isActiveExplorerTab` 门闩  
5. **预览**：切走 `suspendInlineLoadedContent`，切回 `reloadSuspendedInlineSessions`  
6. **`FilePreviewView` / `FilePreviewSessionHost`**：仅跟踪 `placement`，避免其它 revision 重绘预览  
7. **收藏侧栏**：后台标签跳过 `syncFromParent` / `refreshRowHighlighting`；高亮只刷可见行（不再 `makeIfNecessary: true` 全建 cell）  
8. **右侧重面板**：失焦且无未保存预览编辑时 `deferHeavyRightPanels = true`，切回 key 后再挂载，避免 N 套预览树常驻  
9. **标签栏样式死循环（2026-11）**：`ExplorerTabBarActiveAppearance` 曾订阅 `NSWindow.didUpdateNotification`；写 tint/`attributedTitle` 会再触发 update → 主线程空闲也在 DFS 整棵标题栏树。多标签 + 选中/预览体感「半秒～一秒」且越用越慢。已改为仅 key/resize/occlusion + revision 合并调度，样式未变则跳过写入；`findTabBar` 缓存 + `NSClassFromString`  
10. **预览观察面**：`FilePreviewView` / `FilePreviewSessionHost` 不再 `@ObservedObject` 全局 `DirectoryMetadataOverlay`；文件夹预览只在本路径 size/count 变化时刷新  
11. **选中弹出右栏**：auto 模式首次因选中显栏时先占位一帧，让列表高亮先上屏再挂预览树  
12. **粘贴板**：`PasteboardPasteAvailability.refreshNow` 无变化时不再 `objectWillChange`（避免 N 份 `FileListView` 同步重绘）  

## 实测（Release → `/Applications/MeoFind.app`）

| 场景 | 结果 |
|------|------|
| 开约 8–9 标签后连切 25 次 | 总耗时约 1.3s（含 50ms sleep），额外开销约 4ms/次 |
| 切标签期间 `sample` | `FavoritesSidebar` / `refreshRowHighlighting` / `DirectoryMetadata` / `makeListRows` 命中为 0 |
| 多标签常驻 RSS | 约 130MB 量级，切标签不再明显暴涨 |
| 列表方向键导航 | 单次开销约数毫秒级 |
| 多标签空闲 `sample`（修前） | 主线程大量 `ExplorerTabBarActiveAppearance.apply` + `findSubview`（didUpdate 死循环） |
| 多标签空闲 `sample`（修后期望） | 不应再出现连续 `applyToVisibleExplorerWindows` / 深层 `findSubview` 尖峰 |

## 验收建议

1. Release 安装 `/Applications/MeoFind.app`  
2. 开 6–10 个标签（不同目录更好）  
3. 连续切标签、点击侧栏、滚动列表、开预览  
4. 期望：切标签后首帧可点；滚动无明显掉帧；后台标签不拖垮前台  
5. 可选：`sample <pid> 3 1` 中不应再出现「每个元数据 revision × 全部标签 table reload」或「全标签侧栏 refreshRowHighlighting」尖峰  

## 标签栏选中样式（macOS 26+）

Tahoe liquid glass 下系统 `NSTabBar` 选中/未选中常几乎无差别。`ExplorerTabBarActiveAppearance` 会：

- 给当前标签加强调色玻璃 tint + 半粗标题  
- 未选中标签保持淡底与次要标题色  
- **仅**在 key / resignKey / resize / occlusion 与 `bumpTabBarRevision` 时合并重绘  
- **禁止**订阅 `didUpdate`（写样式会触发 update，形成主线程死循环）  

## 后续可选

- `DirectoryMetadataOverlay` 按窗口/会话隔离（彻底消除跨标签 size 串扰）  
- `FileListPreferencesStore` 的 `@ObservedObject` 进一步下沉，避免偏好变更时 N 次 SwiftUI body  
- 选中切换时复用 `PreviewSession`（减少 `.id(file)` 整树拆建）  
