# 顶部工具栏自定义 — 交互、UI 与实现方案

> 目标：为 Explorer 顶部工具栏增加**可自定义**能力——用户可通过**右键**打开「工具栏自定义」窗口，调整内置按钮的显示/顺序，并添加**打开第三方应用**等自定义动作；执行时可将**当前选中文件**作为参数传给目标应用。  
> 本文档为自包含设计，参考现有 `CustomPreviewRuleStore`、`SnippetExpander`、`FileOperations.openWithApplication` 等实现模式。

---

## 一、背景与目标

### 1.1 现状

| 区域 | 现状 |
|------|------|
| 工具栏结构 | `ContentView` 中 `explorerToolbarLeadingItems` / `explorerToolbarTrailingItems` **硬编码**图标按钮 |
| 内置按钮（左侧 actions 组） | 预览、Snippets、输出面板、新建文件夹、删除、显示隐藏文件、列表/缩略图视图 |
| 内置控件（右侧 utilities 组） | 缩略图尺寸滑块（条件显示）、排序菜单、浏览设置菜单 |
| 固定区域 | 路径栏、前进/后退、搜索框——**不参与自定义** |
| 打开第三方应用 | `FileOperations.openWith` / `openWithApplication` 已存在，但仅在右键「打开方式」中使用，未暴露到工具栏 |
| 上下文变量 | `SnippetExpander` 已支持 `%f`、`%p`、`%P`、`%d` 等占位符，可复用 |

### 1.2 目标

1. **右键入口**：在工具栏可操作区域（图标按钮区）右键，弹出菜单项「自定义工具栏…」，打开独立配置窗口。
2. **内置项管理**：显示/隐藏、拖拽排序、恢复默认布局。
3. **自定义动作**：首版重点支持「**用指定应用打开选中项**」；可选扩展为「运行 Snippet」「执行 Shell 命令」等。
4. **选中文件传参**：将当前选中文件/目录路径传给第三方应用（文件作为 `NSWorkspace` 打开目标，或作为命令行参数）。
5. **持久化**：配置写入 `UserDefaults`（JSON blob），多窗口共享；支持导入/导出（Phase 2）。

### 1.3 非目标（首版）

- 跨设备 iCloud 同步
- 用户上传自定义 SVG 图标（首版使用应用图标或内置 Lucide 图标）
- 为每个文件扩展名单独配置不同应用（可 Phase 3 用 scope 扩展）
- 修改路径栏、搜索框的布局

---

## 二、建议的自定义功能清单

按优先级分层，便于分阶段交付。

### 2.1 P0 — 首版必做

| 功能 | 说明 |
|------|------|
| 显示/隐藏内置按钮 | 每个内置 `ToolbarBuiltinAction` 可 toggle |
| 拖拽排序 | 在自定义窗口内调整可见项顺序 |
| 恢复默认 | 一键重置为出厂布局 |
| 自定义：打开应用 | 选择 `.app`，点击工具栏按钮时用该应用打开选中文件 |
| 无选中时的禁用态 | 需要选中项的动作在工具栏上 `disabled`，tooltip 提示原因 |
| 右键「自定义工具栏…」 | 工具栏空白处或任意按钮上 secondary click |

### 2.2 P1 — 次优先

| 功能 | 说明 |
|------|------|
| 参数模板 | 除「把文件交给应用打开」外，支持 `argumentsTemplate`，如 `--line %n %f` |
| 作用域（Scope） | 复用 Snippet 的 scope 模型：仅文件、仅目录、单选、指定扩展名等 |
| 多选行为 | 多文件时批量 `open(urls, withApplicationAt:)` 或合并为参数列表 `%F` |
| 溢出菜单 `…` | 可见区放不下时，未显示的项收进「更多」菜单（与 macOS 工具栏溢出一致） |
| 导入/导出 JSON | 与 `CustomPreviewRuleStore` 同类体验 |

### 2.3 P2 — 可选增强

| 功能 | 说明 |
|------|------|
| 关联 Snippet | 工具栏按钮一键执行已有 Snippet（不必重复配置脚本） |
| 分隔符 / 分组 | 在列表中加 `separator` 项，视觉上分组 |
| 键盘快捷键 | 为自定义动作绑定局部快捷键（需与系统菜单协调） |
| 条件显示 | 如「仅缩略图模式下显示缩略图尺寸滑块」——内置项已有此逻辑，自定义项可配置 `visibilityRule` |
| 最近使用应用 | 添加自定义动作时，快速从「最近用此扩展名打开过的应用」挑选 |

---

## 三、交互设计

### 3.1 入口

```
┌─────────────────────────────────────────────────────────────────┐
│ [←→] /Users/.../project          [👁][📄][⌘]…[🔍 搜索]          │  ← 系统 unified toolbar
└─────────────────────────────────────────────────────────────────┘
         ↑ 路径栏（固定）                    ↑ 可自定义区域
```

**触发方式：**

| 操作 | 行为 |
|------|------|
| 在工具栏图标区 **右键**（secondary click） | 弹出 `NSMenu`：`自定义工具栏…` |
| 按住 **Option** 点击任意工具栏按钮 | 快捷打开自定义窗口（可选，Finder 风格） |
| 设置 → 通用 → 「自定义工具栏…」 | 辅助入口（Phase 1 可加链接） |

右键菜单首版仅一项即可，后续可扩展「隐藏此按钮」「重置工具栏」。

### 3.2 自定义窗口

独立 `NSWindow`（非 Sheet），尺寸约 **560 × 480**，与 `SettingsView` 视觉一致。

```
┌─ 自定义工具栏 ───────────────────────────────────────────── [×] ┐
│                                                                   │
│  将项目拖到工具栏预览区；勾选控制在主窗口是否显示。                  │
│                                                                   │
│  ┌─ 工具栏预览 ────────────────────────────────────────────────┐  │
│  │ [👁][📄][VS Code][🗑] … │ [排序▾][⚙][🔍────]              │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌─ 可用项目 ─────────────┐  ┌─ 当前工具栏（可拖拽排序）──────┐  │
│  │ ☐ 预览                  │  │ ≡ 预览                    [−] │  │
│  │ ☐ Snippets              │  │ ≡ Snippets                [−] │  │
│  │ ☐ 输出面板              │  │ ≡ Visual Studio Code  [✎][−] │  │
│  │ ☐ 新建文件夹            │  │ ≡ 删除                    [−] │  │
│  │ …                       │  │ ≡ 显示隐藏文件            [−] │  │
│  │ ─────────────────       │  │ …                             │  │
│  │ ＋ 添加打开应用…         │  │                               │  │
│  └─────────────────────────┘  └───────────────────────────────┘  │
│                                                                   │
│              [恢复默认]              [取消]  [完成]                │
└───────────────────────────────────────────────────────────────────┘
```

**交互要点：**

- **左侧「可用项目」**：内置动作列表 + 底部「添加打开应用…」；勾选或拖入右侧。
- **右侧「当前工具栏」**：仅含已启用项；`≡` 拖拽把手排序；`[−]` 移除（回到左侧）；自定义项有 `[✎]` 编辑。
- **顶部预览条**：实时反映排序结果；搜索框、路径栏等**灰显不可拖**，标示为固定项。
- **完成**：写回 `ToolbarCustomizationStore` 并刷新主窗口工具栏；**取消**丢弃未保存编辑。

### 3.3 添加/编辑「打开应用」Sheet

```
┌─ 打开应用 ────────────────────────────────────────┐
│ 名称         [ Visual Studio Code          ]       │
│ 应用         [ 🟦 Visual Studio Code    ] [选择…]  │
│                                                   │
│ 打开方式                                          │
│   ● 用应用打开选中文件（推荐）                     │
│   ○ 启动应用并传入参数                            │
│                                                   │
│ 参数模板（可选）  [ %f                          ]   │
│ 占位符：%f 单文件  %F 多文件  %p 路径  %d 当前目录 │
│                                                   │
│ 何时可用                                          │
│   [ 至少选中一个文件 ▾ ]                          │
│                                                   │
│ 图标预览    [ 应用图标 ]  ○ 使用应用图标           │
│                                                   │
│                        [取消]  [保存]              │
└───────────────────────────────────────────────────┘
```

**打开方式说明：**

| 模式 | 行为 | API |
|------|------|-----|
| **用应用打开选中文件** | 将选中项 URL 交给应用，等同「打开方式」 | `NSWorkspace.shared.open(urls, withApplicationAt:configuration:)` |
| **启动应用并传入参数** | 不通过文档模型，而是带参数启动；适合 CLI、部分编辑器 | `NSWorkspace.OpenConfiguration.arguments` 或 `Process` |

### 3.4 主窗口工具栏上的执行反馈

| 场景 | 行为 |
|------|------|
| 无选中且动作需要选中 | 按钮 `disabled`；tooltip：`需要先选中文件` |
| 选中类型不匹配 scope | `disabled`；tooltip：`不适用于当前选中项` |
| 单选限制但多选 | `disabled` 或 Phase 1 仅取第一项并 tooltip 提示 |
| 执行成功 | 无弹窗；可选短暂 status bar 提示 |
| 应用不存在 / 被卸载 | `NSAlert`：`找不到应用「xxx」，请在自定义工具栏中重新选择` |
| 扩展名无关联 | 仍尝试 `open(urls, withApplicationAt:)`；失败再提示 |

### 3.5 与现有能力的关系

- **不替代**右键「打开方式…」：那是每次临时选择；工具栏自定义是**固定快捷方式**。
- **可复用** `SnippetExpander` 与 `SnippetScopeMatcher`：减少重复实现。
- **与 Snippets 区分**：Snippets 偏脚本执行与输出面板；工具栏打开应用偏**一键启动外部 GUI/CLI**，无 Job 队列。

---

## 四、UI 视觉规范

### 4.1 工具栏上的自定义按钮

- **内置项**：继续使用现有 `ExplorerToolbarIconButton` + `LucideIcon`。
- **自定义「打开应用」项**：
  - 优先显示目标应用的 `NSWorkspace.shared.icon(forFile: appPath)`，缩放到 `ExplorerToolbarMetrics.iconSize`（16pt）。
  - 图标加载失败时回退 `LucideIcon.externalLink`。
  - Tooltip：`用 {应用名} 打开` / `用 {应用名} 打开（需先选中文件）`。

### 4.2 自定义窗口组件

| 组件 | 实现建议 |
|------|----------|
| 预览条 | `HStack` + 与主工具栏相同的 `ExplorerToolbarMetrics` |
| 可排序列表 | `List` + `.onMove` 或 `ReorderableList`（与 Snippets 列表风格一致） |
| 应用选择 | `NSOpenPanel`，`allowedContentTypes = [.application]`，`directoryURL = /Applications` |
| 表单 | `Form` + `.formStyle(.grouped)`，对齐 `PreviewSettingsTab` |

### 4.3 无障碍

- 每个工具栏按钮保留 `accessibilityLabel`（含自定义名称）。
- 自定义窗口列表项支持键盘上下移动与 Space 切换启用。

---

## 五、数据模型

### 5.1 工具栏项类型

```swift
/// 工具栏上一项的联合类型（持久化用）。
enum ToolbarItemKind: String, Codable {
  case builtin
  case openApp
  case separator      // Phase 2
  case runSnippet     // Phase 2
}

struct ToolbarItemConfig: Codable, Identifiable, Equatable {
  var id: UUID
  var kind: ToolbarItemKind
  var isVisible: Bool

  // kind == .builtin
  var builtinID: ToolbarBuiltinID?

  // kind == .openApp
  var customOpenApp: CustomOpenAppAction?

  // kind == .runSnippet
  var snippetID: UUID?
}

enum ToolbarBuiltinID: String, Codable, CaseIterable {
  case leftPanel
  case preview
  case snippets
  case outputPanel
  case newFolder
  case delete
  case toggleHiddenFiles
  case listView
  case thumbnailView
  case thumbnailSizeSlider
  case sortMenu
  case browseSettingsMenu
  // search / pathBar 不在此枚举中——不可自定义
}
```

### 5.2 自定义打开应用

```swift
enum OpenAppDeliveryMode: String, Codable {
  /// NSWorkspace.open(urls, withApplicationAt:)
  case openFiles
  /// configuration.arguments 或 Process；模板经 SnippetExpander 展开
  case launchWithArguments
}

struct CustomOpenAppAction: Codable, Equatable {
  var id: UUID
  var displayName: String
  /// 应用 bundle URL 路径，如 /Applications/Visual Studio Code.app
  var applicationPath: String
  var bundleIdentifier: String?
  var deliveryMode: OpenAppDeliveryMode
  /// launchWithArguments 时使用；openFiles 时可为空
  var argumentsTemplate: String?
  var scope: SnippetScope
  var enabled: Bool
}
```

### 5.3 布局配置

```swift
struct ToolbarLayoutConfig: Codable, Equatable {
  var schemaVersion: Int = 1
  /// 左侧 actions 组（preview … thumbnailView）
  var leadingItems: [ToolbarItemConfig]
  /// 右侧 utilities 组（thumbnailSizeSlider … browseSettingsMenu）
  var trailingItems: [ToolbarItemConfig]
  /// 是否启用溢出菜单；首版可 false，项过多时截断
  var useOverflowMenu: Bool = false
}
```

### 5.4 持久化

| 键 | 位置 |
|----|------|
| `toolbar.layoutConfig` | 新增 `AppPreferences.Toolbar.layoutConfig` |
| 存储格式 | `JSONEncoder` → `UserDefaults` Data，模式同 `CustomPreviewRuleStore` |

```swift
final class ToolbarCustomizationStore: ObservableObject {
  static let shared = ToolbarCustomizationStore()
  @Published private(set) var layout: ToolbarLayoutConfig

  func loadIfNeeded()
  func save()
  func resetToDefaults()
  func addOpenAppAction(_ action: CustomOpenAppAction, at index: Int?)
  func updateOpenAppAction(_ action: CustomOpenAppAction)
  func deleteItem(id: UUID)
  func moveItem(from: IndexSet, to: Int, section: ToolbarSection)
}
```

默认布局应与当前硬编码顺序一致，升级时对未知 `builtinID` 忽略，对缺失项追加到末尾。

---

## 六、执行引擎

### 6.1 上下文

复用 Snippets 的 `SnippetExecutionContext`：

```swift
struct SnippetExecutionContext {
  let cwd: String
  let selectedItems: [FileItem]
}
```

主窗口在渲染/点击工具栏时，将 `path` 与 `selectedItems` 注入。

### 6.2 OpenAppExecutor

```swift
enum ToolbarActionExecutor {
  static func perform(
    _ item: ToolbarItemConfig,
    context: SnippetExecutionContext
  ) throws {
    switch item.kind {
    case .builtin:
      // 由 ContentView 分发到已有 handler
      break
    case .openApp:
      try OpenAppExecutor.run(item.customOpenApp!, context: context)
    default:
      break
    }
  }
}
```

**`OpenAppExecutor` 核心逻辑：**

```swift
enum OpenAppExecutor {
  static func run(_ action: CustomOpenAppAction, context: SnippetExecutionContext) throws {
    guard action.enabled else { return }
    guard SnippetScopeMatcher.matches(action.scope, context: context) else {
      throw ToolbarActionError.scopeMismatch
    }

    let appURL = URL(fileURLWithPath: action.applicationPath)
    guard FileManager.default.fileExists(atPath: appURL.path) else {
      throw ToolbarActionError.applicationMissing(action.displayName)
    }

    switch action.deliveryMode {
    case .openFiles:
      let urls = resolvedFileURLs(context: context, scope: action.scope)
      guard !urls.isEmpty else { throw ToolbarActionError.requiresSelection }
      let config = NSWorkspace.OpenConfiguration()
      NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: config)

    case .launchWithArguments:
      let template = action.argumentsTemplate ?? "%f"
      let expanded = try SnippetExpander.expand(
        template,
        context: context,
        scriptType: .shell
      )
      let config = NSWorkspace.OpenConfiguration()
      config.arguments = splitArguments(expanded) // 或整段作为单一参数，见 6.3
      config.createsNewApplicationInstance = false
      NSWorkspace.shared.open([], withApplicationAt: appURL, configuration: config)
    }
  }
}
```

现有代码参考：

```323:344:Sources/Explorer/Domain/FileOperations.swift
    static func openWithApplication(_ items: [FileItem], appURL: URL) {
        let urls = items.filter { !$0.isDirectory }.map(\.url)
        guard !urls.isEmpty else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: configuration)
    }
```

### 6.3 参数传递策略

| 应用类型 | 推荐模式 | 示例 |
|----------|----------|------|
| VS Code、Sublime、Typora 等 | `openFiles` | 直接打开文件 URL |
| 终端中打开路径 | `launchWithArguments` + `%d` | `argumentsTemplate: "%d"` 配合 iTerm/Terminal（需验证 bundle） |
| 带开关的 CLI 包装 | `launchWithArguments` | `--line 10 %f` |
| `.app` 内嵌 CLI | `Process` | `/Applications/Foo.app/Contents/MacOS/foo %f`（Phase 2） |

**参数拆分：**

- 默认：`argumentsTemplate` 经 `SnippetExpander` 展开后，按 shell 规则拆分为 `configuration.arguments` 数组。
- 若应用需要「整段字符串作为一个参数」，编辑器中提供「将展开结果作为单一参数」开关。

**目录选中：**

- `openFiles` 模式：目录 URL 同样传给 `NSWorkspace`（与 Finder 一致）。
- 若 scope 为 `filesOnly` 且选中目录，按钮禁用。

### 6.4 内置按钮分发

将 `ContentView` 中各按钮的 `action` 提取为 `ToolbarBuiltinDispatcher`：

```swift
enum ToolbarBuiltinDispatcher {
  @MainActor
  static func perform(
    _ id: ToolbarBuiltinID,
    environment: ToolbarActionEnvironment
  )
}

struct ToolbarActionEnvironment {
  var layout: ExplorerWindowLayoutState
  var showHiddenFiles: Binding<Bool>
  var loadItems: () -> Void
  // …
}
```

渲染时根据 `ToolbarCustomizationStore.layout.leadingItems` 过滤并排序，而非写死 `HStack`。

---

## 七、实现架构

### 7.1 文件结构（建议）

```
Sources/Explorer/Toolbar/
  ToolbarBuiltinID.swift
  ToolbarItemConfig.swift
  ToolbarLayoutConfig.swift
  ToolbarCustomizationStore.swift
  ToolbarCustomizationWindow.swift      // NSWindowController
  ToolbarCustomizationView.swift        // SwiftUI 主界面
  CustomOpenAppEditorSheet.swift
  ToolbarActionExecutor.swift
  OpenAppExecutor.swift
  ToolbarBuiltinDispatcher.swift
  ToolbarOverflowMenu.swift             // Phase 2
  ExplorerToolbarHost.swift             // 从 ContentView 抽离的动态工具栏
```

### 7.2 ContentView 改造要点

1. 用 `ExplorerToolbarHost` 替换 `explorerToolbarLeadingItems` / `explorerToolbarTrailingItems` 中的硬编码 `HStack`。
2. `ToolbarCustomizationStore.shared` 作为 `@ObservedObject`，`layout` 变化时 `toolbar` 自动刷新。
3. 在 toolbar 区域叠加透明 `NSView` 或使用 `ExplorerToolbarLucideMenuNSView` 同类方式监听 **rightMouseDown**，弹出「自定义工具栏…」。
4. 注册 `Notification.Name.openToolbarCustomizationRequested` 供设置页跳转。

### 7.3 右键检测（AppKit）

工具栏 unified titlebar 上 SwiftUI `.contextMenu` 对个别按钮有效，但对空白区域不稳定。建议：

```swift
// ExplorerToolbarContextMenuInstaller: NSViewRepresentable
// 在 toolbar 容器上添加 rightMouseDown → NSMenu
override func rightMouseDown(with event: NSEvent) {
  let menu = NSMenu()
  menu.addItem(withTitle: L10n.Toolbar.customize, action: #selector(openCustomization), keyEquivalent: "")
  NSMenu.popUpContextMenu(menu, with: event, for: self)
}
```

### 7.4 与 L10n / String Catalog

新增键位建议：

- `toolbar.customize` → 「自定义工具栏…」
- `toolbar.customize.title` → 「自定义工具栏」
- `toolbar.customize.preview` → 「工具栏预览」
- `toolbar.customize.addOpenApp` → 「添加打开应用…」
- `toolbar.openApp.*` → 编辑器表单字段
- `toolbar.error.*` → 执行错误提示

---

## 八、分阶段实施计划

### Phase 1 — 基础自定义 + 打开应用（MVP）

| 步骤 | 内容 |
|------|------|
| 1 | 定义 `ToolbarBuiltinID`、`ToolbarLayoutConfig`、`ToolbarCustomizationStore` |
| 2 | 默认布局迁移：从当前 ContentView 顺序生成 `defaultLayout` |
| 3 | `ToolbarCustomizationView` + Window；显示/隐藏、排序、恢复默认 |
| 4 | `CustomOpenAppEditorSheet`；应用选择器；`openFiles` 模式 |
| 5 | `OpenAppExecutor` + 工具栏自定义按钮（应用图标） |
| 6 | 工具栏右键菜单；`ContentView` 接入动态布局 |
| 7 | 单元测试：`OpenAppExecutor` scope / 展开；Store 编解码 |

**验收标准：**

- 可隐藏「删除」按钮并把 VS Code 加到工具栏；选中 `.swift` 文件点击后在该应用中打开。
- 重启应用后布局保留。

### Phase 2 — 参数模板与导入导出

- `launchWithArguments` 模式与参数编辑器
- `argumentsTemplate` 占位符帮助面板（复用 Snippet 文档）
- JSON 导入/导出
- 溢出菜单

### Phase 3 — 高级

- `runSnippet` 工具栏项
- `visibilityRule`（如仅缩略图模式显示滑块）
- 扩展名 → 应用推荐
- Option+点击快捷进入自定义

---

## 九、预设示例（出厂可选模板）

导入或「从模板添加」可降低配置成本：

| 名称 | 应用 | 模式 | Scope |
|------|------|------|-------|
| VS Code | `Visual Studio Code.app` | openFiles | filesOnly |
| Cursor | `Cursor.app` | openFiles | filesOnly |
| 终端打开此处 | `Terminal.app` | launchWithArguments `%d` | anytime |
| Hex Fiend | `Hex Fiend.app` | openFiles | fileExtensions: bin, hex, … |

模板以 bundled `toolbar-presets.json` 提供，不写入用户配置直到确认添加。

---

## 十、风险与对策

| 风险 | 对策 |
|------|------|
| 部分应用不支持 `open(_:withApplicationAt:)` | 失败时提示改用「启动并传入参数」或系统「打开方式」 |
| `arguments` 行为因应用而异 | 文档说明 + 编辑器内「测试运行」按钮（Phase 2） |
| 工具栏宽度不足 | Phase 2 溢出菜单；Phase 1 允许用户自行精简 |
| 沙盒 / 安全书签 | 应用自身已具备文件访问能力；打开用户选中的文件与现有 `openWith` 同级 |
| 与系统 toolbar 拖拽冲突 | 禁用系统工具栏用户自定义（`toolbarStyle(.unifiedCompact)` 已用）；仅通过应用内窗口配置 |

---

## 十一、测试要点

### 11.1 单元测试

- `ToolbarCustomizationStore`：默认布局、保存/加载、reset
- `OpenAppExecutor`：scope 不匹配、无选中、多选 URL 列表
- `SnippetExpander` 与 `argumentsTemplate` 组合展开

### 11.2 手动测试

1. 添加 VS Code，单选 `.md` 打开。
2. 多选 3 个文件，确认均传入应用。
3. 仅选目录，scope 为 `filesOnly` 时按钮禁用。
4. 删除 `/Applications` 内应用后点击，提示重新配置。
5. 隐藏所有 leading 项，工具栏不崩溃、预览区仍可用。
6. 右键空白处可打开自定义窗口。

---

## 十二、小结

| 维度 | 方案要点 |
|------|----------|
| 入口 | 工具栏右键 → 「自定义工具栏…」 |
| 核心自定义 | 内置项显隐/排序 + **打开第三方应用** |
| 传参 | 优先 `NSWorkspace.open(urls, withApplicationAt:)`；高级用 `argumentsTemplate` + `SnippetExpander` |
| 数据 | `ToolbarLayoutConfig` JSON 持久化，`ToolbarCustomizationStore` 单例 |
| 实现 | 抽离 `Explorer/Toolbar/*`，`ContentView` 改为读 store 动态渲染 |
| 分期 | Phase 1 MVP → Phase 2 参数/导入 → Phase 3 Snippet/智能推荐 |

本方案与现有 Snippets、自定义预览规则在架构上保持一致，复用上下文变量与 scope 匹配，实现成本可控，且能直接满足「选中文件一键用指定应用打开」的高频需求。
