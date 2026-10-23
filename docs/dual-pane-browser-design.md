# 双栏浏览模式 — 设计方案

> 目标：在优先控制内存与性能的前提下，为 MeoFind 主浏览区增加左右双栏模式；工具栏一键切换；每栏独立路径 / 历史 / 选中 / 列表；侧栏与右侧预览等窗口级共享并跟随活动栏。  
> 本文档可直接拆分为开发 Plan。

---

## 一、背景与目标

### 1.1 现状

| 区域 | 现状 |
|------|------|
| 主浏览列 | `ContentView.explorerBrowserColumn`：单路径栏 + 单 `FileListView` |
| 浏览状态 | `path` / `items` / `selection` / `pathNavigation` / `loadGeneration` 均堆在 `ContentView` |
| 列表控制器 | `FileListTableController.shared` / `FileListThumbnailController.shared`（weak singleton） |
| 目录会话 | `DirectoryFSEventsMonitor.shared` + `ownsSharedDirectorySession`（key 窗单路） |
| 工具栏 | 可自定义 builtin（`ToolbarBuiltinID`），尚无双栏开关 |

### 1.2 需求目标

1. 顶部工具栏增加 **双栏切换** 图标；点击进入 / 退出双栏。
2. 双栏下左右各具备与单栏等价的路径栏、文件列表、列表/缩略图模式。
3. 侧栏、右侧预览 / 片段 / Git、输出面板仍一份，跟随 **活动栏（active pane）**。
4. 性能：禁止简单复制两份 `ContentView`；共享缩略图缓存；非活动栏降优先级；退出双栏释放副栏。

### 1.3 非目标（首版 / Phase 1）

- 不做双份侧栏、不做独立「双栏窗口类型」
- 不做完整 Norton / Total Commander 快捷键体系
- 全文搜索（Content Search）双引擎（仅活动栏）
- 每栏独立 viewMode / 排序（首版窗口共享；Phase 2 可选）

---

## 二、交互设计

### 2.1 布局

```
┌ Sidebar ┬ PathA + 列表A │ PathB + 列表B ┬ Right Panel ┐
│         │               │               │ Preview…   │
│         ├───────────────┴───────────────┤            │
│         │         Output Panel          │            │
```

- 双栏只占主浏览列（原 `explorerBrowserColumn`）。
- 中间竖向分隔条可拖；比例持久化；双击 → 50/50。
- 活动栏：路径栏底色 / 细左边框轻微高亮；点击栏内空白或列表即激活。
- `Tab` 在两栏间切换焦点（路径栏文本编辑中不抢焦点）。

### 2.2 工具栏

| 项 | 说明 |
|----|------|
| Builtin ID | `dualPane` |
| 位置 | 默认靠近 `listView` / `thumbnailView` |
| 行为 | 切换 `isDualPaneEnabled`；按下态 = 已开启 |
| 进入 | 副栏路径 = 上次记住的副栏路径（无效则用主栏当前路径） |
| 退出 | 保留 **活动栏** 的路径/选中为单栏状态；清空副栏 `items`、取消 in-flight load、拆除 FileList 控制器 |

### 2.3 每栏独立 vs 窗口共享

| 能力 | 归属 |
|------|------|
| 路径、前进后退历史、选中、列表、loading、快搜 | **每栏** |
| 列表/缩略图、排序、隐藏文件、图标预览开关 | **窗口共享**（首版） |
| 侧栏点击导航 | → 活动栏 |
| 预览 / 片段 / Git / 输出 cwd | → 活动栏 path + selection |
| 工具栏新建/删除/打开应用 | → 活动栏 |
| 全文搜索 | 首版仅活动栏 |
| Reveal / 外链打开 | → 活动栏 |

### 2.4 Phase 2 增强交互

1. 栏标题条右键：打开对方路径 / 在对方打开选中项父目录 / 交换两栏路径。
2. 拖拽跨栏：落到对方空白 = 复制或移动（跟系统 Option；drop 目标为对方 `currentDirectoryPath`）。
3. 快捷键：`Tab` 切栏；`⌘⌥→/←` 聚焦；可选「对开查看」。
4. 同路径提示（可选，默认关）。

---

## 三、数据模型与架构

```
ContentView (窗口壳)
  └── ExplorerPaneStore
        ├── PaneState primary
        ├── PaneState secondary (双栏时存活)
        └── activePaneID
  └── FileListFocusRegistry (活动栏 table / thumbnail)
  └── ThumbnailCache.shared (共享)
  └── DirectoryFSEvents (多 path 并集)
```

### 3.1 `ExplorerPaneState`

每栏持有：`id`、`path`、`items`、`selection`、`pathNavigation`、`loadGeneration`、`isLoading`、`quickSearch*`、`fileListFocusToken`、`directoryMetadataOverlay`、`pendingExternalSelection` 等。

导航：`activePane.navigateToDirectory`；`loadItems` 归属 pane（或 `ExplorerPaneController`），避免 `ContentView` 堆两套逻辑。

### 3.2 `FileListFocusRegistry`（Phase 0 阻塞项）

替换 `FileListTableController.shared` / `FileListThumbnailController.shared` 的「全局动作」语义：

- `activeTable` / `activeThumbnail`：由当前 focused 的 pane 注册
- 非活动栏控制器仍存活，但不接收全局重命名 / 快搜快捷键
- 元数据刷新可广播到 **所有** 已注册控制器（两栏同可见时都更新）

### 3.3 持久化（`AppPreferences.Layout`）

| 键 | 含义 |
|----|------|
| `dualPane.enabled` | 是否开启双栏 |
| `dualPane.splitRatio` | 左栏宽度比例 0…1（默认 0.5） |
| `dualPane.secondaryPath` | 上次副栏路径 |

按窗口/标签语义：本应用「标签 ≈ NSWindow」；布局 state 以最后写入为准（与现有 `ExplorerWindowLayoutState` 一致）。副栏路径不跨标签共享运行时列表。

### 3.4 FSEvents / 元数据

- 监视集合 = 两栏路径并集（同路径 → 单 watcher）。
- 事件按 path 派发到对应 pane。
- 元数据：活动栏 visible-first；非活动栏仅在可见且非 memory-critical 时调度；critical 时只保活动栏。

### 3.5 内存生命周期

| 事件 | 行为 |
|------|------|
| 开启双栏 | 创建副栏 state；异步 load；不预热缩略图直至可见 |
| 切换活动栏 | 更新 FocusRegistry；预览跟新 selection |
| 退出双栏 | 取消副栏 Task；`items = []`；卸 FileList NSView |
| memory critical | 停非活动栏 QL / 元数据；暂停非活动栏 icon preview |

---

## 四、实现触点

| 模块 | 文件 |
|------|------|
| 方案 | `docs/dual-pane-browser-design.md` |
| 壳层 | `ContentView.swift` |
| Pane | `ExplorerPaneState.swift`、`ExplorerBrowserColumnView.swift`、`ExplorerPaneStore.swift` |
| 布局偏好 | `ExplorerWindowLayoutState.swift`、`AppPreferences.swift` |
| 工具栏 | `ToolbarModels.swift`、`ExplorerToolbarItemViews.swift`、`ExplorerToolbarEnvironment.swift` |
| FileList | `FileListFocusRegistry.swift`；弱化 singleton |
| FSEvents | `DirectoryFSEventsMonitor` 多 path / 派发 |
| i18n | `Localizable.xcstrings` + `L10n` + `Scripts/compile_localizations.sh` |
| 命令面板 / 快捷键 | `CommandPaletteRegistry`、`AppShortcutRegistry` |

---

## 五、分期

### Phase 0 — 方案文档 + FocusRegistry

- 本文档
- `FileListFocusRegistry` 替换 shared 调用点（单栏行为不变）

### Phase 1 — 可切换双栏浏览（MVP）

- `ExplorerPaneState` + 双栏 UI + 工具栏开关 + split 持久化
- 每栏独立 path/history/selection/list；活动栏驱动侧栏与预览
- Tab 切栏；退出释放副栏
- 双路径 FSEvents / 元数据优先级

### Phase 2 — 跨栏操作与效率

- 跨栏拖拽复制/移动；「在另一栏打开」「交换路径」
- 命令面板：Toggle Dual Pane / Focus Other Pane
- 快捷键完善

### Phase 3 — 打磨

- 同路径提示、分隔条双击均分、辅助功能、Instruments 基线

---

## 六、测试要点

- FocusRegistry：后创建的非活动栏不抢走 `beginRename` / 快搜
- 两栏导航隔离：改 A 路径不影响 B
- 开关双栏：退出后副栏 items 为空、无残留 load
- 同路径：仅一个 FSEvents watcher
- L10n：双栏相关键非键名字符串

---

## 七、风险与缓解

| 风险 | 缓解 |
|------|------|
| `ContentView` 过大 | 先抽 BrowserColumn，再开双栏 |
| shared 控制器竞态 | Phase 0 必须先合 |
| 双缩略图内存 | 共享 LRU；不另开 QL 池 |
| Reveal 抢路径 | 固定进活动栏 |
