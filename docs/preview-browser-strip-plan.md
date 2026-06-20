# 独立窗口浏览条（Preview Browser Strip）— 开发计划

> 依据：[preview-browser-strip-design.md](./preview-browser-strip-design.md)  
> 前置： [preview-detached-window-phase1-plan.md](./preview-detached-window-phase1-plan.md) PD-01 ~ PD-12 已完成。  
> 目标：P5 MVP 导航（PD-15 ~ PD-17）→ P6 胶片条 V1（PD-18 ~ PD-21）→ P7 增强（PD-22 ~ PD-24）。

---

## 总览

| Phase | 主题 | Issue 数 | 预估 | 用户可见 |
|-------|------|----------|------|----------|
| **P5** | MVP：方向键 + 导航条 | 3 | 1.5–2 天 | 是 |
| **P6** | 胶片条 V1 + 动画 | 4 | 2–3 天 | 是 |
| **P7** | 过滤、预取、持久化 | 3 | 1–2 天 | 部分 |
| P8 | Contact Sheet 等（可选） | 2 | 2 天 | 可选 |

本文档展开 **P5–P7**（PD-15 ~ PD-24）。

---

## P5：MVP 导航（无缩略图条）

> 原则：仅 1 个可预览文件时不显示 UI；`swift build` + 手动测 20 张图片目录 ← →。

### PD-15：PreviewBrowserContext 与 Eligibility

**类型**：feat  
**依赖**：PD-12（detached 已可用）  
**文件**：

- `Sources/Explorer/Preview/Browser/PreviewBrowserContext.swift`（新建）
- `Sources/Explorer/Preview/Browser/PreviewBrowserEligibility.swift`（新建）
- `Sources/Explorer/Preview/Browser/PreviewBrowserStripMetrics.swift`（新建，仅常量）

**任务**：

- [x] 定义 `PreviewBrowserContext`：`orderedItems`、`currentIndex`、`canBrowse`
- [x] 实现 `selectPrevious()` / `selectNext()` / `select(index:)` 边界安全
- [x] `PreviewBrowserEligibility.canPreviewInDetachedWindow(_:)`：排除目录、父目录项；复用 `PreviewTypeClassifier` / 内置扩展集合
- [x] `PreviewBrowserContext.makeSnapshot(items:sortOrder:showHiddenFiles:currentFileID:)` 工厂
- [x] 单元测试：排序一致性、过滤、边界 index

**验收**：

- 与 `FileListSortEngine` 同输入同输出顺序
- 单文件目录 `canBrowse == false`

---

### PD-16：PreviewSession 浏览切换 + Detach 附加 Context

**类型**：feat  
**依赖**：PD-15  
**文件**：

- `Sources/Explorer/Preview/PreviewSession.swift`
- `Sources/Explorer/Preview/PreviewSession+Loading.swift`
- `Sources/Explorer/Preview/PreviewDetachCoordinator.swift`
- `Sources/Explorer/AppModule.swift`（`FilePreviewSessionHost` / detach 传参）

**任务**：

- [x] `PreviewSession` 增加 `browseContext: PreviewBrowserContext?`
- [x] 增加 `browseTarget: FileItem` 计算属性；`FileContentView` 加载目标改为 `browseTarget`
- [x] 实现 `switchBrowseTarget(to:)`：`cancelLoad` → `resetControls` → 更新 index → `beginLoadTask`
- [x] `detach` 时传入 `items`、`sortOrder`、`showHiddenFiles`，构建并 `attachBrowserContext`
- [x] `PreviewWindowValue` / Store 无需变更

**验收**：

- detach 后 programmatic `switchBrowseTarget` 可加载新文件
- 切换取消旧 task（快速切换 10 次无崩溃）
- 弹出瞬间无二次 load（仍仅 migrate session）

---

### PD-17：PreviewBrowserNavBar + 键盘导航

**类型**：feat  
**依赖**：PD-16  
**文件**：

- `Sources/Explorer/Preview/Browser/PreviewBrowserNavBar.swift`（新建）
- `Sources/Explorer/Preview/Browser/PreviewBrowserController.swift`（新建）
- `Sources/Explorer/Preview/DetachedPreviewWindowView.swift`

**任务**：

- [x] `PreviewBrowserNavBar`：`◀` / `▶`、文件名、`current/total`；`canBrowse == false` 时不渲染
- [x] 嵌入 `DetachedPreviewWindowContent` 底部
- [x] `PreviewBrowserController.handleKeyNavigation`：`←` / `→`
- [x] 窗口 `.focusable()` + key handler（或 `LocalKeyboardMonitor`）
- [x] 菜单可选：「预览 → 上一个/下一个」（disabled 当不可浏览）

**验收**：

- 20 张图片目录：键盘与按钮切换正常
- 首/末项 ← → 无操作
- 顶栏标题随当前文件更新
- PDF/视频切换后工具栏状态 reset

---

## P6：胶片条 V1（Cover Flow Strip）

### PD-18：PreviewBrowserStripView 骨架（虚拟化）

**类型**：feat  
**依赖**：PD-17  
**文件**：

- `Sources/Explorer/Preview/Browser/PreviewBrowserStripView.swift`（新建）
- `Sources/Explorer/Preview/Browser/PreviewBrowserStripCell.swift`（新建）

**任务**：

- [x] 横向 `ScrollView` + `LazyHStack` + `ScrollViewReader`
- [x] 固定条带高度 `PreviewBrowserStripMetrics.stripHeight`（88pt）
- [x] Cell：占位图标 + 异步缩略图槽位
- [x] 「展开胶片条」toggle（默认 MVP 收起，PD-17 NavBar 已有入口）
- [x] 仅 `canBrowse` 时显示

**验收**：

- 500 文件目录滚动不卡顿（无全量 QL）
- 结构编译通过

---

### PD-19：缩略图接入 ThumbnailGenerator

**类型**：feat  
**依赖**：PD-18  
**文件**：

- `PreviewBrowserStripCell.swift`
- `PreviewBrowserController.swift`

**任务**：

- [x] 将 `FileItem` 转为 `FileListRow`（或复用现有 bridge）
- [x] 对 `currentIndex ± 3` 调用 `ThumbnailGenerator.loadThumbnail`（cellSize 72）
- [x] 滚动时更新 prefetch 窗口；取消离开窗口的请求（generation token）
- [x] cache miss 时 `instantPlaceholder`

**验收**：

- 日志/断点：打开 strip 时 QL 请求数 ≤ 7 + 滚动增量
- 二次滚动命中 memory/disk cache

---

### PD-20：居中、scale、opacity 与点击切换

**类型**：feat  
**依赖**：PD-19  
**文件**：

- `PreviewBrowserStripView.swift`
- `PreviewBrowserStripCell.swift`

**任务**：

- [x] 根据 cell 与中心距离计算 `scale` / `opacity`（设计文档 §2.3 表）
- [x] `currentIndex` 变化时 `scrollTo` 居中
- [x] 点击 cell → `session.switchBrowseTarget`
- [x] 当前项 optional accent 边框

**验收**：

- 视觉：当前项最大最实，两侧递减
- 点击与 ← → 行为一致

---

### PD-21：过渡动画 + 内容 crossfade

**类型**：feat  
**依赖**：PD-20  
**文件**：

- `PreviewBrowserStripView.swift`
- `PreviewBrowserController.swift`
- `DetachedPreviewWindowView.swift` / `FileContentView`

**任务**：

- [x] strip：`animation(.spring(...), value: currentIndex)` on scale/opacity
- [x] 内容区：切换时 0.15s opacity crossfade（不 block load）
- [x] `PreviewBrowserController` 120ms debounce 合并键盘连按
- [x] 菜单「展开/收起胶片条」`⌘⌥B`（原计划 ⌘B 与左侧面板冲突）

**验收**：

- 快速 ← → 仅最后一次 load
- 动画无明显 jank（60fps 主观）

---

## P7：增强

### PD-22：同类型过滤 + 设置项

**类型**：feat  
**依赖**：PD-21  
**文件**：

- `PreviewBrowserEligibility.swift`
- `ExplorerAppSettings` / Settings（可选 Toggle）

**任务**：

- [x] `@AppStorage` `previewBrowser.sameTypeOnly` 默认 false
- [x] 为 true 时快照仅保留与当前文件同 extension 的项
- [x] 切换后 index 重新定位当前文件

**验收**：

- 混合目录下开启过滤，条带仅图片或仅 PDF

---

### PD-23：相邻内容预取（图片/PDF）

**类型**：perf  
**依赖**：PD-21  
**文件**：

- `PreviewBrowserController.swift`
- `PreviewSession+Loading.swift`（可选 lightweight prefetch API）

**任务**：

- [x] 当前 index 稳定 300ms 后，后台预读 `index±1` 文件 Data（仅 image/pdf，≤8MB）
- [x] 切换时若 prefetch 命中则跳过 disk read
- [x] 视频/Office **不**预取
- [x] 内存上限：最多保留 2 份 prefetch buffer

**验收**：

- 大图目录 ← → 主观更快；内存可控

---

### PD-24：测试、文档与手动清单

**类型**：test / docs  
**依赖**：PD-21  
**文件**：

- `Tests/ExplorerTests/PreviewBrowserContextTests.swift`（新建）
- `Tests/ExplorerTests/PreviewBrowserEligibilityTests.swift`（新建）
- `docs/preview-detached-window-design.md`（§五 增加 P5–P7 链接）
- `docs/preview-toolbar-rollout.md`（可选条目）

**任务**：

- [x] 单元测试覆盖 PD-15 验收点
- [x] 更新设计文档交叉引用
- [ ] 手动清单（见下）执行并勾选

**验收**：

- `swift test` 通过
- 手动清单完成

---

## P8（可选）

### PD-25：Contact Sheet 模式

- 独立窗口内切换 strip / 网格
- 网格点击回到单图 + 居中 strip

### PD-26：同步主窗口选中

- Toggle + `ContentView` selection callback
- scrollIntoView 文件列表行

---

## 推荐 PR 顺序

```
PD-15 → PD-16 → PD-17     (P5 一个 PR：浏览模型 + MVP UI)
PD-18 → PD-19 → PD-20     (P6 一个 PR：strip 功能完整)
PD-21                     (P6 polish PR，或合入上一 PR)
PD-22 → PD-23 → PD-24     (P7 一个 PR)
```

| PR | 包含 Issue | 说明 |
|----|------------|------|
| PR-5 | PD-15 ~ PD-17 | 可先 ship：无缩略图但可 ← → 浏览 |
| PR-6 | PD-18 ~ PD-21 | 胶片条完整体验 |
| PR-7 | PD-22 ~ PD-24 | 增强 + 测试 |

---

## 手动回归清单

### P5 完成后

- [ ] detach 单文件：无 NavBar
- [ ] detach 20 张图片：← → 切换，标题与内容更新
- [ ] PDF 条内切换：页码从 1 开始，缩放 reset
- [ ] 视频切换：播放器重建，无双音
- [ ] 首项 ← / 末项 → 无效
- [ ] dock / 关闭 detached 不受影响

### P6 完成后

- [ ] 展开 strip：当前项居中、scale/opacity 正确
- [ ] 点击 strip 项切换
- [ ] 500+ 文件：滚动流畅，QL 非全量
- [ ] 快速 ← →：debounce 有效
- [ ] `⌘B` 展开/收起
- [ ] 收起 strip 后 ← → 仍可用

### P7 完成后

- [ ] 同类型过滤开关
- [ ] 大图 adjacent prefetch 体感（可选 Instruments）

---

## 与 PD-01 ~ PD-14 关系

| 已有能力 | 本计划依赖 |
|----------|------------|
| `PreviewSession` + `beginLoadTask` | PD-16 切换加载 |
| `DetachedPreviewWindowView` | PD-17 ~ PD-21 UI 嵌入 |
| `PreviewDetachCoordinator.detach` | PD-16 传入目录快照 |
| `ThumbnailGenerator` + cache | PD-19 条带缩略图 |
| `FileListSortEngine` | PD-15 排序快照 |

无需修改 detach 迁移语义；浏览条仅在 **detached 窗口** 内生效，侧栏预览不变。
