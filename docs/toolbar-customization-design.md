# 顶部主工具栏自定义 — 设计方案

> 目标：为 Explorer 顶部主工具栏增加 **Finder 风格** 的可自定义能力——右键进入自定义模式，在工具栏与底部图标面板之间拖拽增删、排序；支持添加「用指定应用打开当前选中文件」的自定义按钮。  
> 本文档基于当前 `ContentView` 工具栏实现编写，可直接拆分为开发 Plan。

---

## 一、背景与目标

### 1.1 现状

| 区域 | 现状 |
|------|------|
| 工具栏结构 | `ContentView.explorerToolbarLeadingItems` / `explorerToolbarTrailingItems` **硬编码** |
| 左侧 navigation | 侧栏切换（`toolbar.leftPanel`） |
| 左侧 actions 组 | 预览、Snippets、输出面板、新建文件夹、删除、显示隐藏文件、列表/缩略图 |
| 右侧 utilities 组 | 缩略图尺寸滑块（条件显示）、排序菜单、浏览设置菜单 |
| 右侧 search | 搜索框（`BarTextField`） |
| **固定不参与自定义** | 路径栏（前进/后退 + `PathBarView`）、搜索框 |
| 打开第三方应用 | `FileOperations.openWithApplication` 已存在，仅用于右键「打开方式」 |
| 上下文变量 | `SnippetExpander` 支持 `%f`、`%F`、`%p`、`%d` 等，可复用 |

当前硬编码位置：

```432:497:Sources/Explorer/ContentView.swift
    @ToolbarContentBuilder
    private var explorerToolbarLeadingItems: some ToolbarContent {
        ToolbarItem(id: "toolbar.leftPanel", placement: .navigation) {
            ExplorerToolbarIconButton(...)
        }
        ToolbarItem(id: "toolbar.actions", placement: .primaryAction) {
            HStack(spacing: ExplorerToolbarMetrics.iconSpacing) {
                // preview, snippets, output, newFolder, delete, hidden, list, thumbnail
            }
        }
    }
```

### 1.2 需求目标（对齐 Finder 交互）

1. **右键入口**：在主工具栏任意可操作区域右键，弹出「**自定义工具栏…**」菜单，进入自定义模式。
2. **互斥显示**：自定义面板中列出所有可用图标；**已在顶部工具栏显示的项，不在面板中显示**。
3. **双向拖拽**：
   - 从面板拖入工具栏任意插入位置 → 显示该按钮；
   - 从工具栏拖入面板 → 从工具栏移除（隐藏）。
4. **排序与保存**：自定义模式下，工具栏内图标可左右拖动调整顺序；点击「**完成**」持久化，「**取消**」恢复原状。
5. **自定义动作**：面板末尾 **＋** 按钮，添加「打开应用」快捷方式；默认将**当前选中文件**作为打开参数；添加后出现在面板中，可拖入工具栏。

### 1.3 非目标（首版）

- 修改路径栏、搜索框位置或样式
- 用户上传自定义 SVG 图标（首版用 Lucide 或目标应用图标）
- iCloud 跨设备同步
- 为不同扩展名配置不同应用（Phase 3）
- 系统 `NSToolbar` 原生 `allowsUserCustomization`（当前为 SwiftUI `.toolbar`，需自研拖拽层）

---

## 二、交互设计（Finder 风格）

### 2.1 正常模式

```
┌──────────────────────────────────────────────────────────────────────────┐
│ [侧栏] [预览][片段][终端][新建][删除][隐藏][列表][缩略图]  [排序][设置] [搜索…] │
│  ↑ navigation          ↑ primaryAction（可自定义区）      ↑ 固定搜索      │
└──────────────────────────────────────────────────────────────────────────┘
```

- **可右键区域**：`navigation` + `primaryAction` 中的图标按钮区（不含搜索框）。
- **右键菜单**（首版仅一项）：

| 菜单项 | 行为 |
|--------|------|
| 自定义工具栏… | 进入自定义模式（见 2.2） |

可选增强（Phase 2）：按住 **Option** 点击任意工具栏按钮，快捷进入自定义模式（与 Finder 一致）。

### 2.2 自定义模式（核心）

进入自定义后，**主窗口标题栏下方展开一块自定义面板**（Finder 为 sheet 式下拉，非独立设置页）。工具栏区进入「编辑态」：按钮带拖拽把手、插入指示线，点击不触发业务动作。

```
┌──────────────────────────────────────────────────────────────────────────┐
│ [侧栏] │ [预览] [片段] [VS Code] [删除] │ [排序] [设置] │     [搜索…]    │  ← 编辑态工具栏
│        ↑ 可左右拖拽排序；可拖出到下面面板                                      ↑ 灰显固定
├──────────────────────────────────────────────────────────────────────────┤
│  将项目拖到工具栏以添加；将项目拖出工具栏以移除。                              │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ [终端] [新建] [隐藏] [列表] [缩略图] [缩略图尺寸]  │  ＋            │  │  ← 可用面板
│  └────────────────────────────────────────────────────────────────────┘  │
│                    [恢复默认]              [取消]  [完成]                  │
└──────────────────────────────────────────────────────────────────────────┘
```

**与 Finder 对齐的规则：**

| 规则 | 说明 |
|------|------|
| 互斥集合 | `visibleItemIDs` ∩ `paletteItemIDs` = ∅ |
| 面板内容 | 所有**未在工具栏显示**的内置项 + 所有**未显示**的自定义项 |
| 拖入工具栏 | 从面板拖到工具栏某位置 → 插入到 `visibleOrder` 对应索引 |
| 拖出工具栏 | 从工具栏拖到面板 → 从 `visibleOrder` 移除，加入面板 |
| 工具栏内排序 | 仅在自定义模式下，同一工具栏条内左右拖拽改变 `visibleOrder` |
| 完成 | 将草稿 `draftLayout` 写入 `ToolbarCustomizationStore` 并退出模式 |
| 取消 | 丢弃 `draftLayout`，恢复进入模式前的 `savedLayout` |
| 固定项 | 搜索框始终显示且不可拖；路径栏不在 unified toolbar 自定义范围内 |

### 2.3 拖拽反馈

| 状态 | 视觉 |
|------|------|
| 拖拽中 | 半透明幽灵图标跟随指针；原位置留空槽 |
| 悬停插入点 | 工具栏两按钮之间显示 2pt 竖线（`accentColor`） |
| 非法落点 | 搜索框、路径栏区域显示禁止光标 |
| 面板接收 | 面板背景高亮 `accentColor.opacity(0.08)` |

### 2.4 添加自定义「打开应用」（＋ 按钮）

点击面板末尾 **＋**，弹出 Sheet：

```
┌─ 添加工具栏项 ──────────────────────────────────────┐
│ 名称         [ Visual Studio Code            ]      │
│ 应用         [ 🟦 Visual Studio Code      ] [选择…] │
│                                                     │
│ 打开方式                                            │
│   ● 用应用打开选中文件（默认）                       │
│   ○ 启动应用并传入参数（Phase 2）                    │
│                                                     │
│ 参数模板（Phase 2）  [ %f                     ]     │
│ 占位符：%f 单文件  %F 多文件  %p 路径  %d 当前目录   │
│                                                     │
│ 图标         ○ 使用应用图标  ○ 使用通用外链图标       │
│                                                     │
│                          [取消]  [添加]               │
└─────────────────────────────────────────────────────┘
```

**默认行为（首版）：**

- `deliveryMode = .openFiles`
- 点击工具栏上该按钮时，调用 `NSWorkspace.shared.open(urls, withApplicationAt:configuration:)`
- `urls` 取自**当前选中项**；无选中时按钮 `disabled`，tooltip：`需要先选中文件`
- 多选时传入全部选中 URL（与 `FileOperations.openWithApplication` 一致）

面板中自定义项显示应用图标；右键或长按（Phase 2）可「编辑」「删除」。

### 2.5 执行反馈（正常模式）

| 场景 | 行为 |
|------|------|
| 无选中 | 按钮禁用 |
| 应用被卸载 | `NSAlert`：找不到应用，请重新配置 |
| 成功 | 无弹窗 |
| 自定义模式下点击按钮 | 不执行，仅响应拖拽 |

---

## 三、可自定义项清单

### 3.1 内置项（`ToolbarBuiltinID`）

| ID | 图标 | 默认可见 | 说明 |
|----|------|----------|------|
| `leftPanel` | `LucideIcon.panelLeft` | 是 | 侧栏显隐 |
| `preview` | `fileImage` | 是 | 预览面板 |
| `snippets` | `braces` | 是 | 片段面板 |
| `outputPanel` | `terminal` | 是 | 输出面板 |
| `newFolder` | `folderPlus` | 是 | 新建文件夹 |
| `delete` | `trash2` | 是 | 删除选中项 |
| `toggleHiddenFiles` | `eye` / `eyeOff` | 是 | 显示隐藏文件 |
| `listView` | `list` | 是 | 列表视图 |
| `thumbnailView` | `layoutGrid` | 是 | 缩略图视图 |
| `thumbnailSizeSlider` | 滑块 | 是* | *仅缩略图模式有意义；运行时仍按 `fileListViewMode` 条件渲染 |
| `sortMenu` | `arrowUpDown` | 是 | 排序菜单 |
| `browseSettingsMenu` | `settings` | 是 | 浏览设置菜单 |

**默认出厂顺序**（与当前 `ContentView` 一致）：

```
leading:  leftPanel
actions:  preview → snippets → outputPanel → newFolder → delete → toggleHiddenFiles → listView → thumbnailView
trailing: thumbnailSizeSlider → sortMenu → browseSettingsMenu
```

### 3.2 自定义项（`ToolbarCustomAction`）

| 类型 | 说明 |
|------|------|
| `openApp` | 用指定 `.app` 打开选中文件 |
| `openShortcut` | 钉在工具栏上的文件 / 文件夹 / 应用快捷方式；点击即打开该路径（与 `openApp` 语义不同） |

Phase 2+：`runSnippet`、`separator`、`flexibleSpace`。

### 3.3 从 Finder 拖入路径快捷方式（MVP）

**仅自定义模式**下，工具栏区（leading / main / trailing）除内部 chip 拖拽外，还接受 `fileURL` 拖入：

| 拖入对象 | 判定 | 点击动作 |
|---------|------|----------|
| `.app` | `FileListApplicationBundle.isBundle` | `NSWorkspace.open` 启动应用 |
| 文件夹 | 目录且非 `.app` | 当前窗口导航到该路径 |
| 普通文件 | 其余 | 用系统默认应用打开 |

交互要点：

1. 悬停显示与内部拖拽共用的插入指示线；松手后创建 `CustomOpenShortcutAction` 并插入落点。
2. 同一绝对路径已在工具栏上 → 忽略；仅在调色板 → 挪到落点。
3. 工具栏上 shortcut 上限 `ToolbarLayoutConfig.maxVisibleShortcuts`（12）。
4. 可拖回调色板移除；右键「删除」从配置中彻底移除。
5. 路径不存在时 Alert，并提供「移除按钮」。
6. 与 `openApp` 并存：拖入的 `.app` 表示「启动该应用」，不是「用该应用打开选中项」。

数据：`ToolbarLayoutConfig.customOpenShortcuts`，可见项 id 为 `shortcut:<UUID>`，`schemaVersion = 2`（旧配置缺字段时解码为 `[]`）。

---

## 四、数据模型

### 4.1 核心类型

```swift
/// 工具栏槽位：leading（navigation）与 trailing（utilities）两组，中间 actions 合并为一组可排序区。
enum ToolbarZone: String, Codable {
    case leading    // 侧栏按钮
  case main         // 原 actions 组
  case trailing     // 排序、设置、缩略图滑块
}

enum ToolbarItemKind: String, Codable {
  case builtin
  case openApp
}

/// 稳定标识：内置项用 ToolbarBuiltinID.rawValue；自定义项用 UUID.uuidString
struct ToolbarItemRef: Codable, Hashable, Identifiable {
  var id: String
  var kind: ToolbarItemKind
  var builtinID: ToolbarBuiltinID?
  var customActionID: UUID?
}

struct ToolbarLayoutConfig: Codable, Equatable {
  var schemaVersion: Int = 1
  /// 当前在工具栏上显示的有序列表（跨 zone 扁平存储，含 zone 标记）
  var visibleItems: [ToolbarVisibleEntry]
  /// 自定义打开应用定义（含未拖入工具栏的）
  var customOpenApps: [CustomOpenAppAction]
}

struct ToolbarVisibleEntry: Codable, Identifiable, Equatable {
  var id: String           // ToolbarItemRef.id
  var zone: ToolbarZone
  var kind: ToolbarItemKind
}

struct CustomOpenAppAction: Codable, Identifiable, Equatable {
  var id: UUID
  var displayName: String
  var applicationPath: String      // /Applications/Foo.app
  var bundleIdentifier: String?
  var deliveryMode: OpenAppDeliveryMode
  var argumentsTemplate: String?   // Phase 2
  var useApplicationIcon: Bool
  var enabled: Bool
}

enum OpenAppDeliveryMode: String, Codable {
  case openFiles              // 默认：NSWorkspace.open(urls, withApplicationAt:)
  case launchWithArguments    // Phase 2
}
```

### 4.2 互斥与面板推导

```swift
extension ToolbarLayoutConfig {
  /// 面板中应显示的项 = 全部内置（未在 visibleItems 中）+ 全部 customOpenApps（未在 visibleItems 中）
  func paletteItems() -> [ToolbarItemRef] { ... }

  /// 工具栏编辑态草稿与已保存配置分离
}
```

进入自定义模式时：

```swift
struct ToolbarCustomizationSession {
  var savedLayout: ToolbarLayoutConfig      // 进入时快照
  var draftLayout: ToolbarLayoutConfig      // 编辑中的可变副本
  var isActive: Bool
}
```

### 4.3 持久化

| 键 | 值 |
|----|-----|
| `AppPreferences.Toolbar.layoutConfig` | `JSONEncoder` → `UserDefaults` Data |

参考 `CustomPreviewRuleStore` 模式：

```swift
final class ToolbarCustomizationStore: ObservableObject {
  static let shared = ToolbarCustomizationStore()
  @Published private(set) var layout: ToolbarLayoutConfig
  @Published var customizationSession: ToolbarCustomizationSession?

  func loadIfNeeded()
  func save(_ layout: ToolbarLayoutConfig)
  func resetToDefaults()
  func beginCustomization()
  func commitCustomization()
  func cancelCustomization()
}
```

---

## 五、执行引擎

### 5.1 上下文

复用 Snippets 上下文：

```swift
struct ToolbarActionContext {
  let cwd: String           // 当前 path
  let selectedItems: [FileItem]
}
```

`ContentView` 在点击自定义按钮时注入 `path` 与 `selectedItems`。

### 5.2 打开应用

```swift
enum OpenAppExecutor {
  @MainActor
  static func run(_ action: CustomOpenAppAction, context: ToolbarActionContext) throws {
    let appURL = URL(fileURLWithPath: action.applicationPath)
    guard FileManager.default.fileExists(atPath: appURL.path) else {
      throw ToolbarActionError.applicationMissing(action.displayName)
    }
    switch action.deliveryMode {
    case .openFiles:
      let urls = context.selectedItems.map(\.url)
      guard !urls.isEmpty else { throw ToolbarActionError.requiresSelection }
      NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: .init())
    case .launchWithArguments:
      // Phase 2: SnippetExpander.expand(argumentsTemplate, ...)
      break
    }
  }
}
```

与现有实现对齐：

```339:344:Sources/Explorer/Domain/FileOperations.swift
    static func openWithApplication(_ items: [FileItem], appURL: URL) {
        let urls = items.filter { !$0.isDirectory }.map(\.url)
        guard !urls.isEmpty else { return }
        ...
    }
```

首版自定义打开应用：**目录与文件均传入**（与 Finder「打开方式」一致）；若需仅文件，Phase 2 加 `SnippetScope`。

### 5.3 内置项分发

将 `ContentView` 内联 `action` 提取为：

```swift
@MainActor
enum ToolbarBuiltinDispatcher {
  static func perform(
    _ id: ToolbarBuiltinID,
    environment: ToolbarActionEnvironment
  )
}
```

`ToolbarActionEnvironment` 持有 `layout`、`showHiddenFiles`、`sortOrder`、`selectedItems` 等现有闭包/绑定。

---

## 六、UI 与架构

### 6.1 组件拆分

```
Sources/Explorer/Toolbar/
  ToolbarBuiltinID.swift
  ToolbarItemRef.swift
  ToolbarLayoutConfig.swift
  ToolbarCustomizationStore.swift
  ToolbarCustomizationSession.swift
  ToolbarCustomizationPanelView.swift     // 底部面板 + Done/Cancel
  ToolbarCustomizationDragSupport.swift   // 拖拽、插入指示、互斥逻辑
  CustomOpenAppEditorSheet.swift
  OpenAppExecutor.swift
  ToolbarBuiltinDispatcher.swift
  ExplorerDynamicToolbar.swift            // 替代硬编码 HStack
  ToolbarContextMenuInstaller.swift       // 右键「自定义工具栏…」
```

### 6.2 ContentView 改造

1. `explorerToolbarLeadingItems` / `explorerToolbarTrailingItems` 改为读取 `ToolbarCustomizationStore.layout.visibleItems` 动态渲染。
2. 自定义模式激活时，在 `ContentView` 根 `VStack` 顶部（工具栏下方）插入 `ToolbarCustomizationPanelView`。
3. `ToolbarContextMenuInstaller`：在 toolbar 容器监听 `rightMouseDown`，弹出 `NSMenu`。
4. 编辑态工具栏使用 `ExplorerDynamicToolbar(isEditing: true)`，按钮 `allowsHitTesting` 仅用于拖拽。

### 6.3 拖拽实现策略

SwiftUI 原生 `.toolbar` 对 Finder 级拖拽支持有限，推荐 **混合方案**：

| 层级 | 方案 |
|------|------|
| 自定义模式开关、面板、Done/Cancel | SwiftUI |
| 工具栏编辑态拖拽 | `NSViewRepresentable` + `NSDraggingDestination` / `NSDraggingSource` |
| 正常模式工具栏 | 保持现有 SwiftUI `ExplorerToolbarIconButton` |

可参考 `FileListTableController` 列拖拽与 `Reorderable` 列表模式；拖拽 payload 使用 `ToolbarItemRef.id` 字符串。

### 6.4 右键检测

`SwiftUI .contextMenu` 在 unified toolbar 空白区不稳定。使用 AppKit 覆盖层：

```swift
final class ToolbarContextMenuInstallerView: NSView {
  override func rightMouseDown(with event: NSEvent) {
    let menu = NSMenu()
    let item = NSMenuItem(
      title: L10n.Toolbar.customize,
      action: #selector(beginCustomization),
      keyEquivalent: ""
    )
    menu.addItem(item)
    NSMenu.popUpContextMenu(menu, with: event, for: self)
  }
}
```

通过 `NSViewRepresentable` 铺在全窗口 toolbar 区域（`zIndex` 低于按钮 hit area，或仅在空白区响应）。

### 6.5 视觉规范

- 图标尺寸：沿用 `ExplorerToolbarMetrics`（16pt 图标，18pt 点击区，8pt 间距）。
- 自定义应用按钮：优先 `NSWorkspace.shared.icon(forFile: appPath)` 缩放到 16pt；失败回退 `LucideIcon.externalLink`。
- 面板高度：约 120–140pt；圆角与窗口 titlebar 衔接使用 `Material.regular` 背景。

---

## 七、i18n

新增键写入 `Sources/Explorer/Resources/Localizable.xcstrings`（`en` + `zh-Hans`），并在 `L10n.Toolbar` 暴露：

| 键 | 中文 | English |
|----|------|---------|
| `toolbar.customize` | 自定义工具栏… | Customize Toolbar… |
| `toolbar.customize.hint` | 将项目拖到工具栏以添加；将项目拖出工具栏以移除。 | Drag items into the toolbar to add them. Drag items out to remove them. |
| `toolbar.customize.done` | 完成 | Done |
| `toolbar.customize.cancel` | 取消 | Cancel |
| `toolbar.customize.reset` | 恢复默认 | Restore Defaults |
| `toolbar.customize.add` | 添加工具栏项… | Add Toolbar Item… |
| `toolbar.openApp.title` | 添加工具栏项 | Add Toolbar Item |
| `toolbar.openApp.name` | 名称 | Name |
| `toolbar.openApp.chooseApp` | 选择… | Choose… |
| `toolbar.openApp.mode.openFiles` | 用应用打开选中文件 | Open selected items with application |
| `toolbar.error.noSelection` | 需要先选中文件 | Select one or more items first |
| `toolbar.error.appMissing` | 找不到应用「%@」 | Application “%@” could not be found |

---

## 八、分阶段实施计划

### Phase 1 — Finder 式 MVP（对齐本文需求 1–5）

| 步骤 | 内容 |
|------|------|
| 1 | `ToolbarBuiltinID`、`ToolbarLayoutConfig`、`ToolbarCustomizationStore`；默认布局与当前硬编码一致 |
| 2 | `ExplorerDynamicToolbar` 正常模式渲染；`ToolbarBuiltinDispatcher` |
| 3 | 右键菜单 + `beginCustomization` / `commit` / `cancel` |
| 4 | `ToolbarCustomizationPanelView`：互斥面板、＋按钮、`CustomOpenAppEditorSheet` |
| 5 | 编辑态拖拽（面板 ↔ 工具栏、工具栏内排序） |
| 6 | `OpenAppExecutor` + 自定义按钮图标 |
| 7 | 单元测试：Store 编解码、互斥推导、`OpenAppExecutor` |

**验收：**

- [ ] 工具栏右键 → 自定义工具栏 → 面板展开
- [ ] 工具栏已有项不在面板显示；拖出后出现在面板
- [ ] 从面板拖入工具栏任意位置；工具栏内可排序
- [ ] 完成保存、取消还原、恢复默认
- [ ] ＋ 添加 VS Code，选中文件点击后在 VS Code 打开
- [ ] 重启后布局保留

### Phase 2 — 路径快捷方式 MVP（已实现）

- 自定义模式接受 Finder / 文件列表 `fileURL` drop → `openShortcut`
- `OpenShortcutExecutor`：文件打开 / 文件夹导航 / 应用启动
- 重复路径、上限、缺失路径移除、调色板互斥

### Phase 2 后续 — 增强

- `launchWithArguments` + `argumentsTemplate`（复用 `SnippetExpander`）
- 自定义项编辑显示名 / `NSOpenPanel`「＋」添加文件
- 工具栏宽度不足时的溢出「…」菜单
- JSON 导入/导出
- Option+点击快捷进入自定义
- security-scoped bookmark；正常模式直接拖钉

### Phase 3 — 扩展

- `runSnippet` 工具栏项
- `SnippetScope` 作用域（仅文件、扩展名过滤等）
- 设置页辅助入口

---

## 九、风险与对策

| 风险 | 对策 |
|------|------|
| SwiftUI `.toolbar` 难以原生拖拽 | 编辑态用 AppKit 拖拽层；正常态保持 SwiftUI |
| 缩略图滑块拖入工具栏但当前为列表模式 | 保留项但运行时按 `fileListViewMode` 隐藏（与现逻辑一致） |
| 工具栏过宽 | Phase 2 溢出菜单；首版用户自行精简 |
| 部分应用不支持 `open(_:withApplicationAt:)` | 提示改用参数模式或系统「打开方式」 |
| 与系统 titlebar 手势冲突 | 自定义模式内禁用按钮业务点击，仅拖拽 |

---

## 十、测试要点

### 10.1 单元测试

- `ToolbarLayoutConfig.paletteItems()` 互斥正确性
- 默认布局 ↔ 编解码 round-trip
- `commitCustomization` / `cancelCustomization` 状态机
- `OpenAppExecutor`：无选中、应用不存在、多选 URL

### 10.2 手动测试

1. 隐藏「删除」→ 完成 → 重启仍隐藏
2. 拖「VS Code」到「新建」左侧 → 顺序正确
3. 拖「预览」到面板 → 工具栏消失、面板出现
4. 自定义模式中点击预览 → 不切换预览面板
5. 无选中时 VS Code 按钮禁用
6. 多选 3 个文件 → 均传入应用

---

## 十一、小结

| 维度 | 方案 |
|------|------|
| 交互模型 | **Finder 式**：工具栏 + 底部面板互斥；拖拽增删排序；完成/取消 |
| 入口 | 工具栏右键「自定义工具栏…」 |
| 自定义能力 | 内置项显隐/排序 + **打开第三方应用**（传选中）+ **路径快捷方式**（钉文件/夹/应用） |
| 数据 | `ToolbarLayoutConfig` JSON → `UserDefaults` |
| 实现 | 新建 `Explorer/Toolbar/*`；`ContentView` 动态渲染 + 编辑态 AppKit 拖拽 |
| 分期 | Phase 1 对齐需求 1–5 → Phase 2 参数/溢出 → Phase 3 Snippet/Scope |

本方案与 `CustomPreviewRuleStore`、`SnippetExpander`、`FileOperations` 架构一致，实现成本可控，且交互与 macOS Finder 用户习惯对齐。
