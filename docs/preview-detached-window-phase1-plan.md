# 预览独立窗口 — Phase 1–3 开发计划

> 依据：[preview-detached-window-design.md](./preview-detached-window-design.md)  
> 目标：完成 Session 重构（P1）→ 弹出/收回 MVP（P2）→ 菜单与边界（P3）。

---

## 总览

| Phase | 主题 | Issue 数 | 预估 | 用户可见 |
|-------|------|----------|------|----------|
| **P1** | PreviewSession 抽取 | 5 | 2–3 天 | 否（重构） |
| **P2** | 独立窗口 MVP | 4 | 2–3 天 | 是 |
| **P3** | 菜单、快捷键、边界 | 3 | 1 天 | 是 |
| P4 | 文件夹弹出、多窗口 | 2 | 2 天 | 可选 |

本文档展开 **P1–P3**。

---

## P1：PreviewSession 抽取（无用户可见变更）

> 原则：每步完成后 `swift build` 通过；侧栏预览行为与重构前一致。

### PD-01：Preview 模块骨架与类型定义

**类型**：refactor  
**依赖**：无  
**文件**：

- `Sources/Explorer/Preview/PreviewSessionID.swift`（新建）
- `Sources/Explorer/Preview/PreviewLoadPhase.swift`（新建）
- `Sources/Explorer/Preview/PreviewWindowValue.swift`（新建）
- `Sources/Explorer/Preview/PreviewPlacement.swift`（新建）

**任务**：

- [x] 定义 `PreviewSessionID`、`PreviewWindowValue`、`PreviewLoadPhase`
- [x] 定义 `PreviewPlacement` enum（`inline` / `detached(sessionID:fileID:)`）
- [x] 定义 `ExplorerWindowScene.preview = "preview"` 常量

**验收**：

- Explorer 模块编译通过
- 类型可 Codable / Hashable（供 WindowGroup 使用）

---

### PD-02：PreviewSession 状态容器

**类型**：refactor  
**依赖**：PD-01  
**文件**：

- `Sources/Explorer/Preview/PreviewSession.swift`（新建）

**任务**：

- [x] 创建 `@MainActor final class PreviewSession: ObservableObject`
- [x] 从 `FilePreviewView` 迁移全部工具栏 `@State` 为 `@Published`（见设计文档 §3.2 列表）
- [x] 实现 `resetControls()`（等价 `resetPreviewControls()`）
- [x] 持有 `file: FileItem`、`folderInlineChild: FileItem?`、`hostWindowID: UUID`

**验收**：

- Session 可独立实例化
- 默认值与现有 `FilePreviewView` 一致

---

### PD-03：加载逻辑迁入 PreviewSession

**类型**：refactor  
**依赖**：PD-02  
**文件**：

- `Sources/Explorer/Preview/PreviewSession.swift`
- `Sources/Explorer/AppModule.swift`（`FileContentView`）

**任务**：

- [x] 将 `FileContentView` 的 `@State` 加载结果（`image`、`pdfDocument`、`mediaPlayer`、`textContent` 等）迁入 `PreviewSession`
- [x] 将 `loadContent()` / `loadCustomPreview()` / `loadTextContentIfNeeded()` 迁入 `PreviewSession.loadIfNeeded()`
- [x] `loadIfNeeded()` 使用 `Task` + 可取消；对外暴露 `loadPhase`
- [x] `FileContentView` 改为 `@ObservedObject var session: PreviewSession`，删除重复 `@State`

**验收**：

- 侧栏预览各类型（图片/PDF/文本/媒体/Office/压缩包）行为不变
- 切换文件时旧 task 取消、新文件正常加载
- 无 duplicate load（手动切换 10 个文件无泄漏感）

---

### PD-04：PreviewPanelChrome 与 FilePreviewView 接线

**类型**：refactor  
**依赖**：PD-03  
**文件**：

- `Sources/Explorer/Preview/PreviewPanelChrome.swift`（新建）
- `Sources/Explorer/AppModule.swift`（`FilePreviewView`）

**任务**：

- [x] 抽取标题栏 HStack 为 `PreviewPanelChrome(mode: .sidebar, ...)`（当前由 `FilePreviewSessionHost` 承载，逻辑等价）
- [x] `previewToolbarItems(for:)` 改为接受 `PreviewSession`（`PreviewSession+Toolbar.swift`）
- [x] `FilePreviewView` 持有 `@StateObject private var session: PreviewSession`，在 `selectedItem?.id` 变化时复用或重建 session
- [x] Session 生命周期：`onChange(of: selectedItem?.id)` → 旧 session `cancelLoad()` → 新 session

**验收**：

- 标题栏按钮（缩放/旋转/PDF 翻页等）功能不变
- 折叠、关闭、文件夹内联返回正常

---

### PD-05：PreviewSessionStore

**类型**：refactor  
**依赖**：PD-04  
**文件**：

- `Sources/Explorer/Preview/PreviewSessionStore.swift`（新建）

**任务**：

- [x] `@MainActor` 单例或 per-app store：`register` / `session(for:)` / `remove`
- [x] Session 标记 `location: .inline | .detached(windowNumber: Int?)`
- [x] 主窗口 ID 生成：`ContentView` 入口 `@State private var hostWindowID = UUID()`

**验收**：

- Store 单元可测（register/remove）
- 无 session 泄漏（remove 后 weak 引用释放）

---

## P2：独立窗口 MVP

### PD-06：WindowGroup 与 DetachedPreviewWindowView

**类型**：feat  
**依赖**：P1 完成  
**文件**：

- `Sources/Explorer/AppModule.swift`（`ExplorerApp`）
- `Sources/Explorer/Preview/DetachedPreviewWindowView.swift`（新建）

**任务**：

- [x] 注册 `WindowGroup(id: ExplorerWindowScene.preview, for: PreviewWindowValue.self)`
- [x] `DetachedPreviewWindowView`：从 store 取 session，渲染 detached 顶栏 + `FileContentView(session:)`
- [x] 窗口标题 = 文件名；`.defaultSize(width: 640, height: 480)`

**验收**：

- 可通过 Preview / 临时按钮 `openWindow` 打开空白壳（开发用）
- 窗口样式与主窗口一致

---

### PD-07：PreviewDetachCoordinator — 弹出

**类型**：feat  
**依赖**：PD-06  
**文件**：

- `Sources/Explorer/Preview/PreviewDetachCoordinator.swift`（新建）
- `Sources/Explorer/Preview/PreviewPlacementState.swift`（新建）
- `Sources/Explorer/Preview/PreviewPanelChrome.swift`

**任务**：

- [x] `PreviewDetachCoordinator.detach(session:openWindow:)`
- [x] 侧栏增加「弹出」按钮（`macwindow.badge.plus`）
- [x] 按钮 disabled：文件夹预览、已在 detached
- [x] 已 detached 同文件：聚焦已有窗口

**验收**：

- 弹出后独立窗口内容与弹出前一致（PDF 页码、图片缩放）
- Instruments / log：弹出瞬间无第二次 `loadContent`
- 弹出过程无 loading 闪烁

---

### PD-08：收回侧栏 + 关闭独立窗口

**类型**：feat  
**依赖**：PD-07  
**文件**：

- `PreviewDetachCoordinator.swift`
- `PreviewPanelChrome.swift`
- `DetachedPreviewWindowView.swift`

**任务**：

- [x] `dockBack(sessionID:)`：session.location = .inline；关闭 detached NSWindow；placement = .inline
- [x] 选中文件不一致时弹出 `NSAlert` 确认
- [x] 独立窗口「关闭窗口」→ `onDetachedWindowWillClose`
- [x] 关闭后若侧栏仍选中该文件 → 新建 inline session 并加载

**验收**：

- 收回后工具栏状态保留
- 关闭独立窗口后内存释放（大 PDF 可观察内存下降）

---

### PD-09：PreviewPlaceholderView

**类型**：feat  
**依赖**：PD-07  
**文件**：

- `Sources/Explorer/Preview/PreviewPlaceholderView.swift`（新建）
- `Sources/Explorer/AppModule.swift`（`FilePreviewView`）

**任务**：

- [x] 当 `placement.detached` 且 `selectedItem.id == detached.fileID` 时渲染占位条
- [x] 文案：「{文件名} 已在独立窗口中预览」
- [x] 按钮：「聚焦窗口」「收回侧栏」
- [x] 占位条不调用 `loadIfNeeded`

**验收**：

- 弹出后选中同文件 → 侧栏显示占位条，无内容区 loading
- 选中其他文件 → 侧栏正常 inline 预览新文件

---

## P3：菜单、快捷键、边界

### PD-10：菜单与快捷键

**类型**：feat  
**依赖**：P2 完成  
**文件**：

- `Sources/Explorer/AppModule.swift`（`ExplorerApp.commands`）

**任务**：

- [x] 「在独立窗口中打开预览」`⌘⌥P`
- [x] 「收回预览到侧栏」（仅 detached enabled）
- [x] 通过 `@FocusedValue` 桥接菜单动作

**验收**：

- 快捷键与标题栏按钮行为一致
- 无 detached 时「收回」菜单 disabled

---

### PD-11：主窗口关闭联动

**类型**：feat  
**依赖**：PD-07  
**文件**：

- `PreviewDetachCoordinator.swift`
- `ContentView` / `ExplorerWindowLayoutState`

**任务**：

- [x] 监听主窗口 `willClose`
- [x] `onHostWindowWillClose(hostWindowID:)` → 清理 store

**验收**：

- 关闭主窗口后无 orphaned 预览窗口
- 无 crash / zombie session

---

### PD-12：测试与文档

**类型**：test / docs  
**依赖**：PD-10  
**文件**：

- `Tests/ExplorerTests/PreviewPlacementTests.swift`（新建）
- `Tests/ExplorerTests/PreviewSessionStoreTests.swift`（新建）

**任务**：

- [x] 单元测试：`PreviewPlacement` 状态转换
- [x] 单元测试：store register/remove
- [ ] 更新 preview-toolbar-rollout.md §6 增加 detached 条目
- [ ] 手动测试清单走一遍

**验收**：

- `swift test` 通过
- 手动清单全部勾选

---

## P4（可选）：增强

### PD-13：文件夹预览弹出

- `PreviewSession` 扩展 `folderContext`（cwd、showHidden、callbacks）
- `DetachedPreviewWindowView` 内嵌 `FolderPreviewView`
- 独立窗口内导航仅影响 session，不驱动主窗口 path（或可选「同步跳转」）

### PD-14：多 detached 窗口

- 移除「同文件聚焦」限制
- Store 改为 `[PreviewSessionID]` per host window
- 占位条仅针对「当前选中 == 某 detached 文件」

---

## 推荐 PR 顺序

```
PD-01 → PD-02 → PD-03 → PD-04 → PD-05   (P1 一个或两个 PR)
PD-06 → PD-07 → PD-08 → PD-09           (P2 一个 PR)
PD-10 → PD-11 → PD-12                   (P3 一个 PR)
```

| PR | 包含 Issue | 说明 |
|----|------------|------|
| PR-1 | PD-01 ~ PD-03 | Session + 加载迁移，风险最高，需充分手动测 |
| PR-2 | PD-04 ~ PD-05 | UI 接线 + store，侧栏行为对齐 |
| PR-3 | PD-06 ~ PD-09 | 用户可见 MVP |
| PR-4 | PD-10 ~ PD-12 |  polish + 测试 |

---

## 手动回归清单（P2 完成后）

- [ ] 图片：缩放、旋转、取色、保存 → 弹出 → 状态保留 → 收回
- [ ] PDF：翻页、缩放 → 弹出 → 收回
- [ ] 视频：播放中弹出 → 继续播放 → 关闭窗口 → 播放停止
- [ ] 文本/Markdown：换行、复制 → 弹出
- [ ] 弹出后选中其他文件 → 侧栏新预览 + 独立窗口不变
- [ ] 占位条「聚焦窗口」有效
- [ ] 文件夹选中 → 弹出按钮 disabled
- [ ] 关闭主窗口 → detached 窗口消失
- [ ] `⌘⌥P` 弹出
