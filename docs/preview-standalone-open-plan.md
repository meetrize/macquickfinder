# 可预览文件独立窗口打开 — 开发计划

> 依据：[preview-standalone-open-design.md](./preview-standalone-open-design.md)  
> 前置：独立预览窗（PD-01 ~ PD-12）、浏览条（PD-15 ~ PD-24）已落地。  
> 目标：P1 外部入口泛化 → P2 应用内快捷入口 → P3 设置与默认打开程序 → P4 体验打磨。

---

## 总览

| Phase | 主题 | Issue 数 | 预估 | 用户可见 |
|-------|------|----------|------|----------|
| **P1** | 外部入口泛化 + Standalone API | 6 | 2–3 天 | 是 |
| **P2** | 应用内 ⌥ 双击、右键、快捷键 | 4 | 1.5–2 天 | 是 |
| **P3** | 设置项 + 分组默认打开程序 | 5 | 2–3 天 | 是 |
| **P4** | 窗口持久化、压缩包设置、多图策略 | 3 | 1–2 天 | 部分 |

本文档展开 **P1–P4**（PSO-01 ~ PSO-18）。

---

## P1：外部入口泛化 + Standalone API

> 原则：完成后 Finder 双击 PDF/文本/媒体等直达独立预览窗；`swift build` + `swift test` 通过；图片行为不回退。

### PSO-01：预览文件分类器

**类型**：refactor  
**依赖**：无  
**文件**：

- `Sources/Explorer/Preview/ExternalPreviewFileClassifier.swift`（新建）
- `Sources/Explorer/Preview/ImageFileDimensionsReader.swift`（迁移 `ExternalImageFileClassifier`）
- `Tests/ExplorerTests/ExternalPreviewFileClassifierTests.swift`（新建，自 `ExternalImagePreviewTests` 扩展）

**任务**：

- [x] 实现 `isExternalPreviewCandidate(_ url: URL) -> Bool`：`!isDirectory` + `PreviewCapability.canLoadPreview`（需 `FileItem` 或轻量 URL→扩展名路径）
- [x] 实现 `previewableURLs(from: [URL]) -> [URL]`，保持输入顺序
- [x] 保留 `ExternalImageFileClassifier` 为 typealias 或薄包装，避免大范围调用点断裂
- [x] 单元测试：pdf/txt/mp4/zip/自定义规则扩展名/文件夹/无扩展名

**验收**：

- 与 `PreviewBrowserEligibility.canPreviewInDetachedWindow` 判定一致
- 现有 `ExternalImageFileClassifierTests` 用例全部通过

---

### PSO-02：Standalone 打开选项与协调器 API

**类型**：feat  
**依赖**：PSO-01  
**文件**：

- `Sources/Explorer/Preview/PreviewStandaloneOpenOptions.swift`（新建）
- `Sources/Explorer/Preview/PreviewStandaloneOpenPreferences.swift`（新建）
- `Sources/Explorer/Preview/PreviewDetachCoordinator.swift`
- `Sources/Explorer/Preview/PreviewWindowValue.swift`
- `Tests/ExplorerTests/PreviewStandaloneOpenPreferencesTests.swift`（新建）

**任务**：

- [x] 定义 `PreviewStandaloneOpenOptions`：`allowsDockBack`、`fitImageToScreen`、`initialWindowSize`、`contentKind`（或派生自 `PreviewLoadRoute`）
- [x] `PreviewStandaloneOpenPreferences.options(for: FileItem) -> PreviewStandaloneOpenOptions`：按设计文档 §3.5 表格映射各类型
- [x] 将 `openStandaloneImagePreview` 重构为 `openStandalonePreview(..., options:)`；图片路径传入 `fitImageToScreen: true` 等
- [x] 非图片类型：`adaptImageToWindowOnResize` 仅图片为 true；PDF/文本等不设图片专用标志
- [x] `PreviewWindowValue` 增加 `initialWindowSize: CGSize?`（Codable，供 `WindowGroup.defaultSize` 或 content 侧读取）
- [x] `openStandaloneImagePreview` 标记 `@available(*, deprecated, renamed:)` 或内联委托

**验收**：

- 单元测试覆盖 png/pdf/txt/mp4/zip 的 options 差异
- 现有 detached / browser strip 测试无回归

---

### PSO-03：ExternalPreviewOpenCenter

**类型**：feat  
**依赖**：PSO-02  
**文件**：

- `Sources/Explorer/ExternalPreviewOpenCenter.swift`（新建）
- `Sources/Explorer/ExternalImagePreviewOpenCenter.swift`（改为 typealias 或删除并替换引用）
- `Sources/Explorer/ExternalFolderOpenBridge.swift`
- `Sources/Explorer/ExplorerBrowserWindowSuppressor.swift`
- `Sources/Explorer/AppModule.swift`（`ExplorerAppDelegate`）

**任务**：

- [x] 实现 `ExternalPreviewOpenCenter`，接口与现 `ExternalImagePreviewOpenCenter` 一致（`tryOpen`、`setOpenPreviewWindowHandler`、`shouldSuppressExplorerWindows`）
- [x] `tryOpen`：调用 `ExternalPreviewFileClassifier.previewableURLs`；**单 session**：仅第一个 URL 创建窗，其余通过 `PreviewBrowserContext` 纳入胶片条
- [x] 多图片 URL：改为单窗（Breaking：见 §3.2）；在 PR 说明中注明
- [x] 更新 `application(open:)` / `openFiles` / `openFile` 三处调用
- [x] 更新 `ExternalFolderOpenBridge` handler 注册
- [x] 全局替换 `ExternalImagePreviewOpenCenter` → `ExternalPreviewOpenCenter`

**验收**：

- Finder 双击 PDF → 仅独立预览窗，无主窗口
- Finder 双击文件夹 → 仍开浏览窗口
- Finder 双击未知类型 → 仍 `ExternalFolderOpenCenter`
- 同目录多 PDF 拖入 → 单窗 + 胶片条可切换

---

### PSO-04：独立窗默认尺寸接线

**类型**：feat  
**依赖**：PSO-02, PSO-03  
**文件**：

- `Sources/Explorer/Preview/DetachedPreviewWindowView.swift`
- `Sources/Explorer/AppModule.swift`（`WindowGroup` preview 场景）
- `Sources/Explorer/Preview/PreviewWindowValue.swift`

**任务**：

- [x] `DetachedPreviewWindowView` 读取 `PreviewWindowValue.initialWindowSize`；无值时保持 320×240 min
- [x] 图片 `fitImageToScreen` 逻辑不变（`DetachedPreviewWindowEdgeSnapMonitor` 等）
- [x] 非图片：应用 options 中的 `initialWindowSize` 作为 `defaultSize` 或首次 `setFrame`

**验收**：

- 外部打开 txt 窗宽约 720；mp4 约 16:9
- 图片仍适应屏幕

---

### PSO-05：聚焦已有 Standalone 会话

**类型**：feat  
**依赖**：PSO-03  
**文件**：

- `Sources/Explorer/Preview/PreviewSessionStore.swift`
- `Sources/Explorer/Preview/PreviewDetachCoordinator.swift`

**任务**：

- [x] `PreviewSessionStore.session(forFileID:allowDetached:)` 或按 `file.url.path` 查找已注册 standalone session
- [x] 外部重复打开同文件 → `focusDetachedWindow` 而非新建
- [ ] 快速连续 `tryOpen` debounce（可选 300ms，与图片现有行为对齐）

**验收**：

- 已打开 `report.pdf` 独立窗时，Finder 再次双击 → 聚焦原窗
- 不泄漏重复 session

---

### PSO-06：P1 测试与文档

**类型**：test / docs  
**依赖**：PSO-01 ~ PSO-05  
**文件**：

- `Tests/ExplorerTests/ExternalPreviewOpenCenterTests.swift`（新建，可 Mock openWindow handler）
- `docs/preview-standalone-open-design.md`（勾选决策落地项）
- `docs/help-cheat-sheet-plan.md`（若有外部打开说明，补一笔）

**任务**：

- [x] 单元 + 集成测试覆盖 PSO-01 ~ PSO-05 验收项
- [ ] 手动清单：pdf / md / mp4 / docx / zip / psd / 自定义规则扩展名
- [ ] `swift test` 全绿

**验收**：

- CI 通过
- 手动清单全部勾选

---

## P2：应用内快捷入口

> 原则：默认不改变普通双击；⌥ 双击与右键提供独立预览路径。

### PSO-07：应用内 ⌥ 双击

**类型**：feat  
**依赖**：P1（PSO-02）  
**文件**：

- `Sources/FileList/FileListTableController+Interaction.swift`
- `Sources/FileList/FileListTableController.swift`
- `Sources/Explorer/ContentView.swift`
- `Sources/Explorer/FileListView.swift`

**任务**：

- [x] `handleDoubleClick` / `onOpenRow` 路径读取 `event.modifierFlags.contains(.option)`
- [x] ⌥ 双击：`PreviewCapability.canLoadPreview` → `openStandalonePreviewFromBrowser(file:)`（新方法，带 `allowsDockBack: true`）
- [x] 缩略图网格双击同步支持（`FileListThumbnailController` 或等价交互层）
- [x] 压缩包：⌥ 双击走预览；普通双击仍解压（`ArchiveOperations`）

**验收**：

- ⌥ 双击 pdf → 独立窗
- 普通双击 pdf → 系统默认应用（P3 前硬编码；P3 后读设置）
- 普通双击 zip → 解压（不变）

---

### PSO-08：ContentView 打开分流

**类型**：feat  
**依赖**：PSO-07  
**文件**：

- `Sources/Explorer/ContentView.swift`
- `Sources/Explorer/Domain/ExplorerStandalonePreviewOpener.swift`（新建，封装 session 创建 + openWindow）

**任务**：

- [x] 抽取 `openStandalonePreviewFromBrowser(file:allowsDockBack:)`：加载父目录 items、`openStandalonePreview`、`openWindow`
- [x] `openItem` 在 P3 前保持 `FileOperations.open`；为 P3 预留 `PreviewDoubleClickAction` 分支结构
- [x] Enter 键与双击共用 `openItem` / 新分流函数

**验收**：

- 代码无重复：外部入口与应用内入口共用 `PreviewDetachCoordinator.openStandalonePreview`

---

### PSO-09：右键菜单与 ⌘↩

**类型**：feat  
**依赖**：PSO-08  
**文件**：

- `Sources/Explorer/FileListRowContextMenuBuilder.swift`
- `Sources/Explorer/FileContextActions.swift`
- `Sources/Explorer/L10n.swift`
- `Sources/Explorer/Resources/Localizable.xcstrings`
- `Tests/ExplorerTests/L10nTests.swift`
- `Sources/FileList/FileListTableController+Interaction.swift`（⌘↩）

**任务**：

- [x] 新增 `FileContextActions.openInDetachedPreview` 或复用 detach 命令
- [x] 菜单项：`L10n.Action.openInDetachedPreview`，仅 `canLoadPreview` 显示；标注 ⌘⌥P
- [x] 侧栏已有同文件 inline 预览时走 `detach`；否则 standalone
- [x] **⌘↩**：`keyCode` 检测 + Command，调用独立预览打开
- [x] i18n：`en` + `zh-Hans`；`L10nTests` 断言

**验收**：

- 右键菜单中英文正常，无键名泄露
- ⌘↩ 与 ⌥ 双击行为一致

---

### PSO-10：Tooltip 与 P2 测试

**类型**：feat / test  
**依赖**：PSO-07 ~ PSO-09  
**文件**：

- `Sources/FileList/` 行 tooltip 相关视图
- `Tests/ExplorerTests/` 按需

**任务**：

- [x] 文件夹内联子项 tooltip 更新（i18n）
- [ ] 手动测试：列表 / 缩略图 / Enter / ⌘↩ / 右键
- [ ] 帮助词条 `standalone_preview_open`（可选，记入 `HelpCheatSheetContent`）

**验收**：

- P2 手动清单通过

---

## P3：设置项 + 分组默认打开程序

> 原则：默认保守；分组注册不勾选则不修改 Launch Services。

### PSO-11：偏好键与枚举

**类型**：feat  
**依赖**：P2  
**文件**：

- `Sources/Explorer/Preferences/AppPreferences.swift`
- `Sources/Explorer/Preview/PreviewDoubleClickAction.swift`（新建）
- `Sources/Explorer/Preview/PreviewExternalOpenAction.swift`（新建）

**任务**：

- [x] `AppPreferences.Preview.doubleClickAction`：`defaultApp` | `standalonePreview` | `sidebarPreview`
- [x] `AppPreferences.Preview.externalOpenAction`：`standaloneOnly` | `browserAndSelect`
- [x] `AppPreferences.Preview.defaultHandlerGroups`：`Set<PreviewHandlerGroup>`（image/pdf/text/media/office）
- [x] RawRepresentable + 默认值常量

**验收**：

- 缺省键时行为与 P2 一致（双击 = 默认应用）

---

### PSO-12：设置 UI

**类型**：feat  
**依赖**：PSO-11  
**文件**：

- `Sources/Explorer/CustomPreviewSettings.swift`
- `Sources/Explorer/L10n.swift`
- `Sources/Explorer/Resources/Localizable.xcstrings`
- `Tests/ExplorerTests/L10nTests.swift`

**任务**：

- [x] 「双击与外部打开」Section（设计文档 §3.7）
- [x] Picker + Toggle 组；footer 说明外部打开含义
- [x] 图片默认 handler UI 与现有 `DefaultImageViewerSettingsSection` 整合或交叉链接

**验收**：

- 中英文切换无键名
- 修改双击选项后，普通双击 / Enter 立即生效

---

### PSO-13：ContentView 读取双击设置

**类型**：feat  
**依赖**：PSO-11, PSO-12  
**文件**：

- `Sources/Explorer/ContentView.swift`
- `Sources/Explorer/FileListView.swift`

**任务**：

- [x] `openItem` 分支：`standalonePreview` → `openStandalonePreviewFromBrowser`；`sidebarPreview` → 选中 + `layout.showPreview = true`；`defaultApp` → `FileOperations.open`
- [x] ⌥ 双击始终 standalone（忽略设置）
- [x] `externalOpenAction == browserAndSelect` 时 `ExternalPreviewOpenCenter.tryOpen` 返回 false

**验收**：

- 设置「独立预览窗」后普通双击 pdf 开独立窗
- 设置「浏览窗口并选中」后外部 pdf 不开独立窗

---

### PSO-14：DefaultPreviewHandlerManager

**类型**：feat  
**依赖**：PSO-11  
**文件**：

- `Sources/Explorer/DefaultPreviewHandlerManager.swift`（新建）
- `Sources/Explorer/DefaultPreviewHandlerSettingsModel.swift`（新建）
- `Sources/Explorer/Settings/SettingsView.swift`
- `Explorer/Info.plist`（`CFBundleDocumentTypes` 扩展）
- 参考：`DefaultImageViewerManager.swift`

**任务**：

- [x] 定义 `PreviewHandlerGroup`：image（委托现有）、pdf、textAndCode, media, office
- [x] 各组 `managedContentTypes: [UTType]` 与 `BuiltinPreviewExtensions` 对齐
- [x] `setAsDefault(for: PreviewHandlerGroup)` / `restoreSystemDefault(for:)`
- [x] 设置 UI Toggle 与 `@AppStorage` 同步
- [x] Info.plist 增加对应 `CFBundleDocumentTypes`（`LSHandlerRank: Alternate`）
- [x] `applicationWillFinishLaunching` 注册 LS

**验收**：

- 勾选 PDF 并设为默认后，Finder 双击 pdf 进本应用独立窗
- 取消勾选并恢复后，系统默认应用还原

---

### PSO-15：P3 测试

**类型**：test  
**依赖**：PSO-11 ~ PSO-14  

**任务**：

- [x] `DefaultPreviewHandlerManager` 单元测试（Mock LS 或仅测 UTType 集合）
- [x] `PreviewDoubleClickAction` 分支测试
- [ ] 手动：设置各组合 + 重启 app 后默认 handler 仍正确

**验收**：

- `swift test` 通过

---

## P4：体验打磨（可选）

### PSO-16：独立窗 frame 按类型持久化

**类型**：feat  
**依赖**：P1  
**文件**：

- `Sources/Explorer/Preview/PreviewDetachedWindowFrameStore.swift`（新建）
- `DetachedPreviewWindowView.swift`

**任务**：

- [x] key = `preview.detachedFrame.<contentKind>` 存 UserDefaults
- [x] 关闭窗时写入；打开时读取；无则用手表 §3.5 默认

---

### PSO-17：压缩包双击设置（可选）

**类型**：feat  
**依赖**：PSO-11  
**文件**：

- `AppPreferences.Preview.archiveDoubleClickAction`
- `ContentView.openItem`

**任务**：

- [x] 枚举：`extract` | `preview`；默认 `extract`
- [x] 设置 UI 一项；仅影响应用内普通双击

---

### PSO-18：图片多选策略（可选）

**类型**：feat  
**依赖**：PSO-03  
**文件**：

- `AppPreferences.Preview.externalMultiImageOpen`
- `ExternalPreviewOpenCenter`

**任务**：

- [x] 枚举：`singleWindowWithStrip`（默认）| `oneWindowPerFile`
- [x] 仅影响外部多图片 URL

---

## 推荐 PR 顺序

```
PSO-01 → PSO-02 → PSO-03 → PSO-04 → PSO-05 → PSO-06   (P1：1–2 个 PR)
PSO-07 → PSO-08 → PSO-09 → PSO-10                       (P2：1 个 PR)
PSO-11 → PSO-12 → PSO-13 → PSO-14 → PSO-15              (P3：1–2 个 PR)
PSO-16 → PSO-17 → PSO-18                                (P4：按需)
```

| PR | 包含 Issue | 说明 |
|----|------------|------|
| PR-1 | PSO-01 ~ PSO-03 | 核心路径；外部打开多类型 |
| PR-2 | PSO-04 ~ PSO-06 | 窗口尺寸 + 去重 + 测试 |
| PR-3 | PSO-07 ~ PSO-10 | 应用内交互 |
| PR-4 | PSO-11 ~ PSO-14 | 设置与 Launch Services |
| PR-5 | PSO-15 | P3 测试补齐 |
| PR-6 | PSO-16 ~ PSO-18 | 可选增强 |

---

## 手动测试清单

### P1 外部打开

- [ ] Finder 双击 `sample.pdf` → 独立窗，无浏览窗口
- [ ] Finder 双击 `readme.md` / `main.swift` → 独立窗，代码高亮正常
- [ ] Finder 双击 `clip.mp4` → 独立窗，可播放
- [ ] Finder 双击 `deck.pptx` → Quick Look 预览
- [ ] Finder 双击 `archive.zip` → 压缩包目录预览，不解压
- [ ] Finder 双击 `photo.png` → 适应屏幕（回归）
- [ ] Finder 双击文件夹 → 浏览窗口
- [ ] 同目录多选 3 张 png 拖入 Dock → 单窗 + 胶片条 3 项
- [ ] 已打开独立窗时再双击同文件 → 聚焦

### P2 应用内

- [ ] 普通双击 pdf → 系统默认应用
- [ ] ⌥ 双击 pdf → 独立窗
- [ ] 普通双击 zip → 解压
- [ ] ⌥ 双击 zip → 压缩包预览
- [ ] 右键「在独立预览窗口中打开」
- [ ] ⌘↩ 打开独立窗
- [ ] Enter 与普通双击一致

### P3 设置

- [ ] 双击行为改为「独立预览窗」后普通双击 txt 开独立窗
- [ ] 外部打开改为「浏览窗口并选中」后 Finder 双击 pdf 不开独立窗
- [ ] 勾选 PDF 为默认打开程序 → 系统偏好中关联正确
- [ ] 恢复系统默认后关联解除

---

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| Launch Services 注册影响用户其他关联 | 分组勾选 + 明确恢复按钮；文案说明 |
| 非图片默认窗口尺寸不合适 | P4 frame 持久化；首版用设计文档推荐值 |
| 图片多选改单窗引起习惯变化 | PR 说明 + PSO-18 可选恢复 |
| `canLoadPreview` 与外部 URL 无 FileItem | `FileItem.resolveSelection` + 轻量构造；失败则 fallback |
| 压缩包内外行为不一致 | 设计文档 §2.3 已说明；设置项 PSO-17 可选统一 |

---

## 完成定义（Definition of Done）

- [ ] P1–P3 所有 **验收** 与 **手动清单** 项勾选
- [ ] 新增 UI 文案均在 `Localizable.xcstrings` + `L10n.swift`
- [ ] `swift build` / `swift test` CI 绿
- [ ] 无新增 detached 会话泄漏（Instruments 或 store count 断言）
- [ ] 设计文档 [preview-standalone-open-design.md](./preview-standalone-open-design.md) 与实现一致
