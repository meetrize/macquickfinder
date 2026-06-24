# MeoFind 国际化（i18n）设计方案

> 目标：为 MeoFind（SPM 可执行目标 `Explorer`）实现 **简体中文 / 英文** 双语界面。  
> 首期覆盖侧边栏、废纸篓、右键菜单、系统菜单与设置窗口；后续逐步覆盖主工具栏、预览、Snippets 等。  
> 本文档基于 **2026-06-24** 代码库现状编写，作为实施参考。

---

## 一、现状分析

### 1.1 项目结构

| 维度 | 结论 |
|------|------|
| 平台 | Swift / macOS 13+，SwiftUI + AppKit 混合 |
| 构建 | Swift Package Manager（SPM），无 `.xcodeproj` |
| 产物 | `Package.swift` 定义可执行目标 `Explorer`；`build_and_run.sh` 打包为 `MeoFind.app` |
| 模块 | `Explorer`（主应用）依赖 `FileList`（文件列表库） |
| 预览子系统 | `Sources/Explorer/Preview/`（约 69 个 Swift 文件，文案密集） |

### 1.2 当前字符串组织方式

**结论：零 i18n 基础设施，几乎全部硬编码，且中英混用。**

| 模式 | 示例 | 分布 |
|------|------|------|
| SwiftUI 字面量 | `Button("切换左侧面板")` | `AppModule.swift`、`ContentView.swift`、设置视图 |
| AppKit 字面量 | `NSMenuItem(title: "打开", ...)` | 右键菜单 builder、`NSAlert` |
| 枚举 `displayName` | `BlankDoubleClickAction`、`FileListColumnID`、`CustomPreviewMode` | 局部集中，不可随系统语言切换 |
| `LocalizedError` | Snippet、预览、默认查看器等错误 | 中文硬编码 |
| Tooltip / 无障碍 | `instantHoverTooltip("新建文件夹")` | 分散于各 View（约 45+ 处 tooltip） |

**语言混用现状：**

| 区域 | 倾向 |
|------|------|
| 菜单、对话框、工具提示、设置 | 以中文为主 |
| 侧边栏分区标题 | 英文：`Favorites`、`Devices`；中文：`位置` |
| 默认收藏夹名称 | 英文：`Home`、`Desktop`、`Documents`、`Downloads`（持久化进 `UserDefaults`） |
| 列头 `headerTitle` | 英文：`Name`、`Type`、`Size`、`Date Modified` |
| 列头菜单 `menuTitle` | 中文：`名称`、`类型`、`大小`、`修改日期` |
| 废纸篓 | 中文：`"废纸篓"`（`TrashLoader.displayName`，兼作路径栏匹配） |
| 主搜索框 | 英文：`Search files`、`Focus Search` |
| 预览空状态 / 部分错误页 | 英文：`Select a file to preview`、`Error loading preview` |
| 产品功能名 | 保留英文：`Snippets`、`Job`、`Shell`、`QuickLook`、`Finder`、`MeoFind` |

**未发现：** `NSLocalizedString`、`String(localized:)`、`Localizable.strings`、`.xcstrings`、`.lproj` 目录、`defaultLocalization`。

### 1.3 用户可见字符串规模（估算）

| 区域 | 文件数（估） | 字符串量级 |
|------|-------------|-----------|
| 设置（通用 / Snippets / 预览） | 3 | ~70–90 |
| 系统菜单 / Commands | 2 | ~25 |
| 侧边栏 / 收藏夹 / 废纸篓 | 4 | ~15 固定 + 数据迁移 |
| 主工具栏 / 路径栏 / 搜索 | 3 | ~35 |
| 文件列表（列头、空白菜单、缩略图） | 7 | ~30 |
| 文件行右键菜单 | 3 | ~25 |
| Snippets 面板 / 编辑器 / 输出 | 10+ | ~80–100 |
| 预览工具栏 / 浏览器 / 图片编辑 | 30+ | ~120–150 |
| 权限 Sheet / NSAlert / 文件操作 | 5+ | ~50 |
| LocalizedError / 内联错误 | 8+ | ~20–25 |
| **合计** | **~60–80 文件** | **~350–500 条** |

### 1.4 关键热点文件

| 文件 | 说明 |
|------|------|
| `Sources/Explorer/AppModule.swift` | 应用入口、`FileCommands`、`ExplorerApp.commands`、收藏夹默认值 |
| `Sources/Explorer/ContentView.swift` | 主工具栏、新建文件夹/文件对话框、搜索框 |
| `Sources/Explorer/SidebarView.swift` | 侧边栏分区、废纸篓、设备空状态 |
| `Sources/Explorer/Domain/FavoritesStore.swift` | 默认收藏夹英文名持久化 |
| `Sources/Explorer/Domain/TrashLoader.swift` | 废纸篓显示名与路径栏逻辑 |
| `Sources/Explorer/Settings/SettingsView.swift` | 设置窗口（通用 / Snippets Tab） |
| `Sources/Explorer/CustomPreviewSettings.swift` | 预览 Tab 及规则编辑器（~50+ 条文案） |
| `Sources/Explorer/FileListRowContextMenuBuilder.swift` | 文件行右键菜单 |
| `Sources/FileList/FileListBlankMenuController.swift` | 空白处右键菜单 |
| `Sources/FileList/FileListColumn.swift` | 列头英/中双轨定义 |
| `Sources/Explorer/FavoritesSidebarHost.swift` | 收藏夹侧边栏显示与右键 |
| `Sources/Explorer/Preview/` | 预览子系统（最大文案热点之一） |

---

## 二、目标与范围

### 2.1 语言支持

| 语言 | 标识 | 优先级 |
|------|------|--------|
| 简体中文 | `zh-Hans` | P0 |
| 英文 | `en` | P0 |

**首期策略**：跟随 **系统语言**（macOS 首选语言）自动切换，不在设置里单独做「语言选择」——实现成本低，符合 macOS 惯例。若后续需要应用内强制语言，可在 Phase 3 增加。

### 2.2 首期必做界面（Phase 1）

| # | 区域 | 现状 | 关键文件 |
|---|------|------|----------|
| 1 | 左侧系统文件夹 | `Home`/`Desktop`/`Documents`/`Downloads` 英文写死并持久化 | `Domain/FavoritesStore.swift` |
| 2 | 废纸篓 | 固定 `"废纸篓"`，且用于路径栏逻辑匹配 | `Domain/TrashLoader.swift`、`SidebarView.swift` |
| 3 | 右键菜单 | 文件行/空白处/收藏夹等全中文硬编码 | `FileListRowContextMenuBuilder.swift`、`FileListBlankMenuController.swift` 等 |
| 4 | 系统菜单 | `FileCommands` + `ExplorerApp.commands` | `AppModule.swift` |
| 5 | 设置窗口 | 通用 / Snippets / 预览 三个 Tab | `Settings/SettingsView.swift`、`CustomPreviewSettings.swift` |

### 2.3 第二批（Phase 2）

| 区域 | 关键文件 |
|------|----------|
| 主工具栏、路径栏 tooltip、搜索框 | `ContentView.swift`、`PathBarView.swift` |
| 列头统一、表头右键 | `FileListColumn.swift`、`FileListTableController+ColumnLayout.swift` |
| 权限引导 Sheet | `FullDiskAccessPermission.swift`、`FinderAutomationPermission.swift` |
| 文件操作 Alert | `Domain/FileOperations.swift` |
| 预览设置 Tab 以外的预览 UI | `Preview/` 目录 |

### 2.4 第三批（Phase 3）

- Snippets 面板、编辑器、输出面板、内置 Snippet 名称
- 预览工具栏全量（PDF / Office / 文本 / 图片 / 媒体 / 压缩包）
- `LocalizedError` 全文、tooltip / accessibility 渐进覆盖
- 可选：设置内「界面语言」选项

---

## 三、技术选型

### 3.1 推荐方案：String Catalog + `L10n` 封装

```
Sources/
  Explorer/
    Resources/
      Localizable.xcstrings      ← Explorer 主应用文案
      en.lproj/InfoPlist.strings
      zh-Hans.lproj/InfoPlist.strings
    L10n.swift                   ← 类型安全的键访问层
  FileList/
    Resources/
      Localizable.xcstrings      ← 文件列表模块文案（可复用）
    L10n.swift
```

**理由：**

- 项目已要求 Swift 5.9 / macOS 13+，完全支持 String Catalog
- SwiftUI `Text("key", bundle: .module)` 与 AppKit `String(localized:bundle: .module)` 可统一
- SPM 原生支持 `resources: [.process("Resources")]`
- Xcode 可视化编辑翻译，比手写 `.strings` 更易维护

### 3.2 `Package.swift` 改造

```swift
let package = Package(
    name: "Explorer",
    defaultLocalization: "en",   // 开发语言建议用 en（国际化惯例）
    platforms: [.macOS(.v13)],
    // ...
    targets: [
        .target(
            name: "FileList",
            dependencies: [],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "Explorer",
            dependencies: ["FileList"],
            resources: [.process("Resources")]
        ),
        // ...
    ]
)
```

> **开发语言选 `en` 还是 `zh-Hans`？**  
> 建议 **`en` 为开发语言**：键名即英文源文案，与 Apple HIG 一致；`zh-Hans` 作为翻译填入 catalog。若团队更习惯中文开发，也可选 `zh-Hans`，但长期维护上 `en` 更标准。

### 3.3 `L10n` 访问层（示例）

```swift
// Sources/Explorer/L10n.swift
import Foundation

enum L10n {
    enum Sidebar {
        static let favorites = String(localized: "sidebar.favorites", bundle: .module)
        static let devices = String(localized: "sidebar.devices", bundle: .module)
        static let locations = String(localized: "sidebar.locations", bundle: .module)
        static let trash = String(localized: "sidebar.trash", bundle: .module)
        static let noDevices = String(localized: "sidebar.no_devices", bundle: .module)
    }

    enum SystemFolder {
        static let home = String(localized: "folder.home", bundle: .module)
        static let desktop = String(localized: "folder.desktop", bundle: .module)
        static let documents = String(localized: "folder.documents", bundle: .module)
        static let downloads = String(localized: "folder.downloads", bundle: .module)
    }

    enum Action {
        static let open = String(localized: "action.open", bundle: .module)
        static let cut = String(localized: "action.cut", bundle: .module)
        // ...
    }

    enum Settings {
        enum Tab {
            static let general = String(localized: "settings.tab.general", bundle: .module)
            static let snippets = String(localized: "settings.tab.snippets", bundle: .module)
            static let preview = String(localized: "settings.tab.preview", bundle: .module)
        }
    }
}
```

**键名规范**：`区域.语义`，如 `menu.context.paste`、`settings.general.blank_double_click`、`preview.toolbar.zoom_in`。

**产品名处理**：`Snippets`、`Job`、`Shell`、`QuickLook`、`Finder`、`MeoFind` 等键的 **中英文翻译均保留英文**，避免品牌名被误译。

### 3.4 SwiftUI / AppKit 用法对照

| 场景 | 写法 |
|------|------|
| SwiftUI 静态文本 | `Text("action.open", bundle: .module)` 或 `Text(L10n.Action.open)` |
| SwiftUI Picker / Toggle | `Toggle("settings.pin_recent", bundle: .module, isOn: ...)` |
| AppKit NSMenuItem | `NSMenuItem(title: L10n.Action.open, ...)` |
| NSAlert | `alert.messageText = L10n.Alert.emptyTrashTitle` |
| 带插值 | `String(localized: "settings.job_limit \(count)", bundle: .module)` |
| 枚举 displayName | 改为计算属性，内部调用 `L10n` |

### 3.5 枚举 `displayName` 集中改造点

| 文件 | 枚举 | 条数 |
|------|------|------|
| `AppModule.swift` | `BlankDoubleClickAction` | 2 |
| `SnippetModels.swift` | `SnippetScriptType`、`SnippetScopeKind`、`SnippetsDisplayMode`、`SnippetImportStrategy` | ~15 |
| `CustomPreviewRuleStore.swift` | `CustomPreviewMode` + `detail` | 14 |
| `FileListViewMode.swift` | `FileListViewMode` | 2 |
| `FileListColumn.swift` | `headerTitle` + `menuTitle` | 8（双轨，需合并） |

---

## 四、各区域专项设计

### 4.1 左侧系统文件夹（Desktop → 桌面）

**现状问题：**

`FavoritesStore.defaultItems()` 用英文名称创建默认收藏夹，`FavoriteItem.name` 序列化进 `UserDefaults`。语言切换后，已持久化的英文名不会自动更新。

**推荐方案：引入 `kind` 字段，显示名运行时本地化**

```swift
enum FavoriteKind: String, Codable {
    case home, desktop, documents, downloads, custom
}

struct FavoriteItem: Codable, Identifiable {
    let path: String
    let kind: FavoriteKind      // 新增
    let customName: String?     // 仅 kind == .custom 时使用
    let icon: String

    var displayName: String {
        switch kind {
        case .home:      return L10n.SystemFolder.home
        case .desktop:   return L10n.SystemFolder.desktop
        case .documents: return L10n.SystemFolder.documents
        case .downloads: return L10n.SystemFolder.downloads
        case .custom:    return customName ?? (path as NSString).lastPathComponent
        }
    }
}
```

**数据迁移**（`FavoritesStore.load()` 时一次性执行）：

| 旧 `name` | 新 `kind` |
|-----------|-----------|
| `Home` | `.home` |
| `Desktop` | `.desktop` |
| `Documents` | `.documents` |
| `Downloads` | `.downloads` |
| 其他 | `.custom`，`customName = 原 name` |

**备选（更简单但不精确）**：不引入 `kind`，显示时用 `FileManager.default.displayName(atPath:)` 取系统本地化文件夹名。缺点是 `Home`（`~`）等无标准显示名，仍需应用内键。

**侧边栏分区标题**一并本地化：

| 现值 | 键 | zh-Hans | en |
|------|-----|---------|-----|
| `Favorites` | `sidebar.favorites` | 个人收藏 | Favorites |
| `Devices` | `sidebar.devices` | 设备 | Devices |
| `位置` | `sidebar.locations` | 位置 | Locations |
| `No devices` | `sidebar.no_devices` | 无设备 | No devices |

设备卷名已由 `SidebarVolumeLoader` 使用系统 `volumeLocalizedName`，**无需应用翻译**。

**系统文件夹翻译对照：**

| 键 | zh-Hans | en |
|----|---------|-----|
| `folder.home` | 个人 | Home |
| `folder.desktop` | 桌面 | Desktop |
| `folder.documents` | 文稿 | Documents |
| `folder.downloads` | 下载 | Downloads |

**收藏夹右键：**

| 键 | zh-Hans | en |
|----|---------|-----|
| `action.remove_favorite` | 取消收藏 | Remove from Favorites |

---

### 4.2 废纸篓

**现状问题：**

`TrashLoader.displayName = "废纸篓"` 同时用于：

- 侧边栏 / 面包屑显示
- 路径栏输入匹配（`newValue == TrashLoader.displayName`）

语言切换或英文环境下，路径栏匹配会失效。

**推荐方案：逻辑标识与显示名分离**

```swift
enum TrashLoader {
    /// 稳定逻辑标识，永不本地化
    static let pathToken = "__TRASH__"

    /// 仅用于 UI 显示
    static var displayName: String { L10n.Sidebar.trash }

    private static var knownDisplayNames: Set<String> {
        // 编译期已知各语言翻译，或从 bundle 枚举
        [pathToken, "废纸篓", "Trash"]
    }

    static func isTrashInput(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        return trimmed == pathToken
            || trimmed == displayName
            || knownDisplayNames.contains(trimmed)
    }
}
```

路径栏 `commitPath()` 改为调用 `isTrashInput()`，不再直接比较 `displayName`。

**翻译：**

| 键 | zh-Hans | en |
|----|---------|-----|
| `sidebar.trash` | 废纸篓 | Trash |
| `action.empty_trash` | 清倒废纸篓 | Empty Trash |
| `action.put_back` | 放回原处 | Put Back |
| `action.delete_immediately` | 立刻删除 | Delete Immediately |
| `alert.empty_trash.title` | 清倒废纸篓？ | Empty Trash? |

---

### 4.3 右键菜单

分三层统一改造。

#### A. 文件行右键 — `FileListRowContextMenuBuilder.swift`

| 键 | zh-Hans | en |
|----|---------|-----|
| `action.open` | 打开 | Open |
| `action.open_in_new_window` | 在新窗口中打开 | Open in New Window |
| `action.paste` | 粘贴 | Paste |
| `action.cut` | 剪切 | Cut |
| `action.copy` | 复制 | Copy |
| `action.copy_filename` | 复制文件名 | Copy Filename |
| `action.copy_paths` | 复制完整路径 | Copy Full Path |
| `action.delete` | 删除 | Delete |
| `action.rename` | 重命名 | Rename |
| `action.open_with` | 打开方式 | Open With |
| `action.open_with_none` | （无可用应用） | (No Available Applications) |
| `action.open_with_other` | 其他… | Other… |
| `action.open_with_default` | （默认） | (Default) |
| `action.add_favorite` | 收藏 | Add to Favorites |
| `action.open_terminal_here` | 在此处打开终端 | Open Terminal Here |
| `action.show_info` | 属性 | Get Info |
| `menu.services` | 服务 | Services |

改造方式：所有 `menuItem(title: "打开")` → `menuItem(title: L10n.Action.open)`。

#### B. 空白处右键 — `FileListBlankMenuController.swift`

| 键 | zh-Hans | en |
|----|---------|-----|
| `action.go_back` | 返回 | Back |
| `action.go_up` | 向上 | Up |
| `action.new_folder` | 新建文件夹 | New Folder |
| `action.new_file` | 新建文件 | New File |
| `action.open_terminal_here` | 在此处打开终端 | Open Terminal Here |
| `action.empty_trash` | 清倒废纸篓 | Empty Trash |

#### C. 表头右键 — `FileListTableController+ColumnLayout.swift`

| 键 | zh-Hans | en |
|----|---------|-----|
| `column.move_left` | 左移 | Move Left |
| `column.move_right` | 右移 | Move Right |

**列头特别处理：**

`FileListColumnID` 目前有 `headerTitle`（英）和 `menuTitle`（中）双轨。改造后合并为单一本地化源：

```swift
public var localizedTitle: String {
    switch self {
    case .name: return String(localized: "column.name", bundle: .module)
  // ...
    }
}
```

`knownHeaderTitles` **保留**，用于读取旧版 `UserDefaults` 列偏好时的兼容匹配。

| 键 | zh-Hans | en |
|----|---------|-----|
| `column.name` | 名称 | Name |
| `column.type` | 类型 | Type |
| `column.size` | 大小 | Size |
| `column.date_modified` | 修改日期 | Date Modified |

---

### 4.4 系统菜单（菜单栏）

#### A. 文件菜单 — `FileCommands`

| 键 | zh-Hans | en |
|----|---------|-----|
| `action.cut` | 剪切 | Cut |
| `action.copy` | 复制 | Copy |
| `action.paste` | 粘贴 | Paste |
| `action.delete` | 删除 | Delete |

#### B. 视图/窗口命令 — `ExplorerApp.commands`

| 现值 | 键 | en |
|------|-----|-----|
| 切换左侧面板 | `menu.toggle_left_panel` | Toggle Left Panel |
| 切换右侧面板 | `menu.toggle_right_panel` | Toggle Right Panel |
| 关闭/显示预览 | `menu.toggle_preview` | Hide/Show Preview |
| 关闭/显示 Snippets | `menu.toggle_snippets` | Hide/Show Snippets |
| 关闭/显示输出面板 | `menu.toggle_output` | Hide/Show Output Panel |
| 导入 Snippets… | `menu.import_snippets` | Import Snippets… |
| 导出全部 Snippets… | `menu.export_snippets` | Export All Snippets… |
| 在独立窗口中打开预览 | `menu.open_preview_detached` | Open Preview in Separate Window |
| 收回预览到侧栏 | `menu.reattach_preview` | Move Preview Back to Sidebar |
| 上一个/下一个预览 | `menu.previous_preview` / `menu.next_preview` | Previous/Next Preview |

SwiftUI `Commands` 中：

```swift
Button(L10n.Menu.toggleLeftPanel) { ... }
```

对于「关闭/显示」成对文案，使用两个独立键（`menu.hide_preview` / `menu.show_preview`），避免运行时拼接。

#### C. 标准菜单

`Settings { SettingsView() }`、`.newItem`、`.saveItem` 等由 SwiftUI 自动本地化（依赖系统），**一般无需处理**。自定义 `CommandGroup` 才需要改。

#### D. 文本编辑 — `TextEditingSupport.swift`

| 键 | zh-Hans | en |
|----|---------|-----|
| `action.select_all` | 全选 | Select All |

（剪切/复制/粘贴与文件菜单共用 `action.*` 键。）

---

### 4.5 设置窗口

设置已拆分为独立文件，共 **三个 Tab**（「高级」Tab 已移除，默认文件夹查看器仅在「通用」中保留一份）。

**文件：**
- `Sources/Explorer/Settings/SettingsView.swift` — Tab 容器、通用、Snippets
- `Sources/Explorer/CustomPreviewSettings.swift` — 预览 Tab 及规则编辑器

#### Tab 标签

| 键 | zh-Hans | en |
|----|---------|-----|
| `settings.tab.general` | 通用 | General |
| `settings.tab.snippets` | Snippets | Snippets |
| `settings.tab.preview` | 预览 | Preview |

#### 通用 Tab — `SettingsView.swift` → `GeneralSettingsTab`

| 键 | zh-Hans | en |
|----|---------|-----|
| `settings.blank_double_click` | 空白处双击 | Double-click on blank area |
| `settings.blank_action.parent` | 返回上级目录 | Go to parent folder |
| `settings.blank_action.terminal` | 在本目录打开终端 | Open Terminal here |
| `settings.window_snap` | 启用窗口吸附与联动移动 | Enable window snap and linked movement |
| `settings.default_viewer.title` | 默认文件夹查看器 | Default Folder Viewer |
| `settings.default_viewer.current` | 当前默认 | Current Default |
| `settings.default_viewer.set` | 设为默认文件夹查看器 | Set as Default Folder Viewer |
| `settings.default_viewer.restore_finder` | 恢复 Finder | Restore Finder |
| `settings.default_viewer.restart_hint` | 更改后请注销并重新登录，或重启 Mac，才能在全部场景中生效。 | Log out and back in, or restart your Mac, for changes to take effect everywhere. |
| `alert.ok` | 好 | OK |

#### Snippets Tab — `SettingsView.swift` → `SnippetsSettingsTab`

| 键 | zh-Hans | en |
|----|---------|-----|
| `settings.snippets.display_mode` | 面板显示模式 | Panel display mode |
| `settings.snippets.display.standard` | 标准 | Standard |
| `settings.snippets.display.minimal` | 极简 | Minimal |
| `settings.pin_recent_snippets` | 最近执行置顶 | Pin Recently Executed |
| `settings.job_concurrency_limit` | Job 并发上限：%lld | Job Concurrency Limit: %lld |
| `settings.auto_show_output` | Shell 执行时自动展开输出面板 | Auto-show Output Panel on Shell Run |
| `settings.confirm_destructive` | 危险命令二次确认 | Confirm Destructive Commands |

#### 预览 Tab — `CustomPreviewSettings.swift`

| 键 | zh-Hans | en |
|----|---------|-----|
| `settings.preview.detached_browse` | 独立窗口浏览 | Browse in Detached Window |
| `settings.preview.detached_browse.footer` | 开启后，弹出预览窗口时胶片条与 ← → 导航仅在同类型文件间切换。 | When enabled, the filmstrip and ← → navigation in a detached preview window only switch between files of the same type. |
| `settings.preview.code_line_numbers` | 代码预览显示行号 | Show line numbers in code preview |
| `settings.preview.code_line_numbers.footer` | 开启后，在右侧预览面板查看代码文件时，于代码左侧显示行号。 | When enabled, line numbers appear to the left of code in the sidebar preview panel. |
| `settings.preview.no_rules_hint` | 尚未添加自定义规则。选中无法预览的文件时，可直接在预览面板一键添加。 | No custom rules yet. Select an unpreviewable file to add one from the preview panel. |
| `settings.preview.custom_types` | 自定义文件类型 | Custom File Types |
| `settings.preview.add_rule` | 添加规则… | Add Rule… |
| `settings.preview.export_rules` | 导出规则… | Export Rules… |
| `settings.preview.import_rules` | 导入规则… | Import Rules… |
| `settings.preview.override_builtin` | 覆盖内置 | Override Built-in |
| `settings.preview.disabled` | 已禁用 | Disabled |
| `settings.preview.edit` | 编辑 | Edit |
| `settings.preview.add_rule_title` | 添加预览规则 | Add Preview Rule |
| `settings.preview.edit_rule_title` | 编辑预览规则 | Edit Preview Rule |
| `settings.preview.import.merge` | 合并 | Merge |
| `settings.preview.import.replace` | 替换 | Replace |
| `action.cancel` | 取消 | Cancel |
| `action.save` | 保存 | Save |

`CustomPreviewMode.displayName` / `detail` 共 7 种模式，各需独立键（`settings.preview.mode.*`）。

#### Alert 消息 — `DefaultFileViewerSettingsModel.swift` / `DefaultFileViewerManager.swift`

成功/失败消息改为 catalog 或 `LocalizedError`：

| 键 | zh-Hans | en |
|----|---------|-----|
| `settings.default_viewer.success` | 已将 MeoFind 设为默认文件夹查看器。请注销并重新登录（或重启）后，更改才会在全部场景中生效。 | MeoFind is now the default folder viewer. Log out and back in (or restart) for the change to take effect everywhere. |
| `error.preferences_sync_failed` | 无法写入系统偏好设置。 | Could not write system preferences. |
| `error.finder_not_found` | 未找到 Finder 应用。 | Finder application not found. |

---

### 4.6 主工具栏与路径栏（Phase 2）

**文件：** `ContentView.swift`、`PathBarView.swift`、`FileListView.swift`

| 键 | zh-Hans | en |
|----|---------|-----|
| `toolbar.show_left_panel` | 显示左侧面板 | Show Left Panel |
| `toolbar.hide_left_panel` | 隐藏左侧面板 | Hide Left Panel |
| `toolbar.new_folder` | 新建文件夹 | New Folder |
| `toolbar.list_view` | 列表视图 | List View |
| `toolbar.thumbnail_view` | 缩略图视图 | Icon View |
| `toolbar.thumbnail_size` | 缩略图大小 | Icon Size |
| `toolbar.browse_settings` | 浏览设置 | Browse Settings |
| `toolbar.auto_folder_size` | 自动计算文件夹大小 | Calculate All Folder Sizes |
| `search.prompt` | 搜索文件 | Search files |
| `search.focus` | 聚焦搜索 | Focus Search |
| `pathbar.clear` | 清除 | Clear |
| `pathbar.select_all` | 点击全选路径 | Click to select full path |
| `pathbar.commit` | 进入新路径 | Go to path |
| `pathbar.edit` | 点击编辑完整路径 | Click to edit full path |
| `pathbar.subdirs` | 显示子目录 | Show subdirectories |
| `pathbar.no_subdirs` | 无子文件夹 | No subfolders |
| `pathbar.parent` | 显示上级路径 | Show parent path |
| `dialog.create` | 创建 | Create |
| `dialog.new_file` | 新建文件 | New File |
| `error.symlink_loop` | 检测到循环链接 | Symbolic link loop detected |

---

### 4.7 预览 UI（Phase 2–3）

预览子系统文案约 **120–150 条**，建议按工具栏扩展分组建键：

| 键前缀 | 覆盖文件 | 示例 |
|--------|----------|------|
| `preview.panel.*` | `PreviewViews.swift`、`PreviewPlaceholderView.swift` | `预览`、`Select a file to preview` |
| `preview.toolbar.pdf.*` | `PreviewSession+ToolbarPDF.swift` | `上一页`、`放大`、`适配宽度` |
| `preview.toolbar.office.*` | `PreviewSession+ToolbarOffice.swift` | `页码`、`缩放比例`、`还原` |
| `preview.toolbar.text.*` | `PreviewSession+ToolbarText.swift` | `开启自动换行`、`复制全文` |
| `preview.toolbar.image.*` | `PreviewSession+ToolbarImage.swift` | `逆时针旋转`、`调整尺寸` |
| `preview.toolbar.media.*` | `PreviewSession+ToolbarMedia.swift` | `播放`/`暂停`、`静音` |
| `preview.toolbar.archive.*` | `PreviewSession+ToolbarArchive.swift` | `刷新目录`、`复制清单` |
| `preview.browser.*` | `PreviewBrowserNavBar.swift` | `上一个`、`下一个`、`收起胶片条` |
| `preview.image.*` | `ImagePreviewContent.swift`、`ImageResizeSheet.swift` | `标记…`、`设为桌面图片` |
| `preview.folder.*` | `FolderPreviewView.swift` | `文件夹为空`、`N 项` |
| `preview.unavailable.*` | `CustomPreviewSettings.swift` → `UnavailablePreviewActions` | `无法预览 … 文件`、`以文本预览` |

**策略：** 工具栏按钮优先用 `L10n.Preview.Toolbar.*`；tooltip 与按钮可共用键或加 `.tooltip` 后缀。

---

### 4.8 Snippets UI（Phase 3）

| 键前缀 | 覆盖 | 示例 |
|--------|------|------|
| `snippets.panel.*` | `SnippetsPanelView.swift` | `展开 Snippets`、`无搜索结果` |
| `snippets.editor.*` | `SnippetEditorSheet.swift` | `新建 Snippet`、`作用域` |
| `snippets.output.*` | `OutputPanelView.swift` | `排队中`、`清屏`、`停止` |
| `snippets.builtin.*` | `SnippetStore.swift` | 内置 7 条中文名称 |
| `snippets.import.*` | `SnippetImportExport.swift` | `导入冲突`、`跳过`/`覆盖`/`重命名` |
| `snippets.confirm.*` | `DestructiveActionConfirmer.swift` | `危险命令确认`、`仍要执行` |

---

### 4.9 Info.plist 与权限文案

`Explorer/Info.plist` 当前中英混用：

| 键 | 现状 | 处理 |
|----|------|------|
| `NSAppleEventsUsageDescription` | 中文 | `zh-Hans.lproj/InfoPlist.strings` |
| `NSFileProviderDomainUsageDescription` | 英文 | `en.lproj/InfoPlist.strings` + 补中文翻译 |
| `CFBundleTypeName`（Folder） | 英文 | 各语言 `InfoPlist.strings` |

---

## 五、构建与打包

当前 `build_and_run.sh` 仅复制可执行文件与 `Info.plist`，**未处理本地化 bundle**。

SPM 编译后，本地化资源通常位于：

```
.build/release/Explorer_Explorer.bundle/
  Localizable.xcstrings → 编译为 zh-Hans.lproj/Localizable.strings 等
```

**需在 `build_and_run.sh` 中增加：**

```bash
# 复制 SPM 资源 bundle 到 App Resources
BUNDLE_SRC=$(find -L .build/$BUILD_CONFIG -name "Explorer_Explorer.bundle" -type d | head -1)
if [ -n "$BUNDLE_SRC" ]; then
    cp -R "$BUNDLE_SRC" "$RESOURCES_DIR/"
fi
# FileList bundle 同理
FILELIST_BUNDLE=$(find -L .build/$BUILD_CONFIG -name "Explorer_FileList.bundle" -type d | head -1)
if [ -n "$FILELIST_BUNDLE" ]; then
    cp -R "$FILELIST_BUNDLE" "$RESOURCES_DIR/"
fi
```

**Info.plist 权限说明** 通过 `Explorer/Resources/en.lproj/InfoPlist.strings` 与 `zh-Hans.lproj/InfoPlist.strings` 提供，并在打包脚本中确保 `.lproj` 进入 `MeoFind.app/Contents/Resources/`。

---

## 六、实施阶段

### Phase 0 — 基础设施（约 2 天）

1. 修改 `Package.swift`：`defaultLocalization`、`resources`
2. 创建 `Localizable.xcstrings`（Explorer + FileList）
3. 创建 `L10n.swift` 骨架（Explorer + FileList）
4. 验证 `swift build` 后 bundle 内含 `.lproj`
5. 更新 `build_and_run.sh` 复制 resource bundle
6. 添加 `InfoPlist.strings`（en + zh-Hans）

### Phase 1 — 首屏五块界面（约 1 周）

按依赖顺序：

1. **废纸篓逻辑重构**（`TrashLoader.isTrashInput`，避免后续返工）
2. **`FavoriteItem` + `kind` 迁移**（`FavoritesStore`）
3. **侧边栏显示**（分区标题 + 收藏夹 + 废纸篓 + `No devices`）
4. **右键菜单**（文件行 / 空白处 / 收藏夹 / 表头列）
5. **系统菜单**（`FileCommands`、`ExplorerApp.commands`）
6. **设置窗口三 Tab**（通用 / Snippets / 预览，含 `CustomPreviewMode` 枚举）

### Phase 2 — 主界面与预览基础（约 1 周）

1. 主工具栏、路径栏 tooltip、搜索框（`ContentView`、`PathBarView`）
2. 列头统一本地化 + `knownHeaderTitles` 兼容
3. 权限 Sheet（全盘访问、自动化）
4. 文件操作 `NSAlert`（`FileOperations.swift`）
5. 预览面板标题、空状态、浏览器导航条
6. 预览不可用时的快捷操作（`UnavailablePreviewActions`）

### Phase 3 — 全面覆盖（约 1–2 周）

1. 预览工具栏全量（PDF / Office / 文本 / 图片 / 媒体 / 压缩包）
2. Snippets 面板、编辑器、输出面板、内置名称
3. `LocalizedError` 全文（8+ 类型）
4. Tooltip / accessibility 渐进替换（~50 处）
5. 单元测试适配（列标题、废纸篓路径断言改为语言无关）
6. 可选：设置内「界面语言」选项

---

## 七、测试策略

| 测试项 | 方法 |
|--------|------|
| 系统语言切换 | 系统设置 → 语言与地区 → 将 English / 简体中文 置顶，重启应用 |
| 侧边栏 | 中文下显示「桌面」「文稿」「下载」；英文下 Desktop/Documents/Downloads |
| 废纸篓路径栏 | 中英文下输入「废纸篓」/「Trash」均可跳转 |
| 旧数据迁移 | 保留含英文 `name` 的 `UserDefaults`，升级后显示正确本地化名 |
| 列偏好兼容 | 旧版保存的「名称」「Name」列偏好仍能正确识别 |
| 设置三 Tab | 通用 / Snippets / 预览 标签与内容均随语言切换 |
| 打包验证 | `MeoFind.app` 内存在 `Explorer_Explorer.bundle` 及 `zh-Hans.lproj` |

**自动化**：可为 `L10n` 或 `FavoriteItem.displayName` 写单元测试，用测试 bundle 指定 `zh-Hans` / `en` 验证关键字符串。

---

## 八、关键文件改动清单

| 优先级 | 文件 | 改动类型 |
|--------|------|----------|
| P0 | `Package.swift` | 增加 `defaultLocalization`、`resources` |
| P0 | `Sources/Explorer/Resources/Localizable.xcstrings` | 新建 |
| P0 | `Sources/Explorer/L10n.swift` | 新建 |
| P0 | `Sources/FileList/Resources/Localizable.xcstrings` | 新建 |
| P0 | `Sources/FileList/L10n.swift` | 新建 |
| P0 | `build_and_run.sh` | 复制 resource bundle |
| P1 | `Sources/Explorer/Domain/TrashLoader.swift` | 逻辑 token 与显示名分离 |
| P1 | `Sources/Explorer/Domain/FavoritesStore.swift` | `FavoriteKind` 迁移 |
| P1 | `Sources/Explorer/SidebarView.swift` | 分区标题、废纸篓 |
| P1 | `Sources/Explorer/AppModule.swift` | 系统菜单、收藏夹默认项 |
| P1 | `Sources/Explorer/FileListRowContextMenuBuilder.swift` | 菜单项本地化 |
| P1 | `Sources/FileList/FileListBlankMenuController.swift` | 菜单项本地化 |
| P1 | `Sources/Explorer/FavoritesSidebarHost.swift` | `displayName`、取消收藏 |
| P1 | `Sources/Explorer/Settings/SettingsView.swift` | 通用 / Snippets Tab |
| P1 | `Sources/Explorer/CustomPreviewSettings.swift` | 预览 Tab + 规则编辑器 |
| P1 | `Sources/FileList/FileListColumn.swift` | 列标题统一本地化 |
| P1 | `Sources/FileList/FileListTableController+ColumnLayout.swift` | 表头菜单 |
| P2 | `Sources/Explorer/ContentView.swift` | 工具栏、搜索、新建对话框 |
| P2 | `Sources/Explorer/PathBarView.swift` | 路径栏 tooltip |
| P2 | `Sources/Explorer/DefaultFileViewerSettingsModel.swift` | Alert 文案 |
| P2 | `Sources/Explorer/Domain/FileOperations.swift` | 删除/清空等 Alert |
| P2 | `Sources/Explorer/Preview/` | 预览 UI 批量替换 |
| P3 | Snippets / Output 相关文件 | 批量替换 |
| P3 | `Explorer/Info.plist` + `*.lproj/InfoPlist.strings` | 权限描述本地化 |

---

## 九、设计决策摘要

| 决策点 | 选择 | 原因 |
|--------|------|------|
| 本地化技术 | String Catalog + SPM resources | 与 Swift 5.9/macOS 13 匹配，SPM 原生支持 |
| 开发语言 | `en` | 键即英文源文案，符合 Apple 惯例 |
| 语言切换 | 跟随系统 | 首期简单可靠；应用内切换可后加 |
| 系统文件夹名 | `FavoriteKind` + `L10n` | 避免 UserDefaults 持久化语言绑定 |
| 废纸篓 | 逻辑 token 与显示名分离 | 修复路径栏多语言匹配 bug |
| 设备卷名 | 继续用系统 API | 已本地化，无需重复 |
| 产品名 | 保留英文 | `Snippets`、`Job`、`Finder`、`MeoFind` 等品牌一致 |
| 设置结构 | 三 Tab，无「高级」 | 默认查看器仅在通用 Tab；与当前代码一致 |
| 预览文案 | 按工具栏扩展分组建键 | 69 个文件，需分阶段避免一次性大 diff |
| `AppModule.swift` | 不先拆分文件 | 控制 diff 范围；i18n 可与后续重构并行 |

---

## 十、待确认事项

实施前建议确认：

1. **开发语言**用 `en` 还是 `zh-Hans`？（推荐 `en`）
2. **首期是否只做「跟随系统语言」**，还是要在设置里加「界面语言」选项？
3. **内置 Snippet 名称**是否随界面语言翻译，还是保持用户可编辑的固定中文？
4. **列头英文**（`Name`/`Type` 等）在中文界面下是否改为「名称」「类型」（推荐与 Finder 中文一致）？

---

## 附录 A：字符串分布速查

```
菜单栏命令          → AppModule.swift (FileCommands, ExplorerApp.commands)
文本编辑菜单        → TextEditingSupport.swift
设置（通用/Snippets）→ Settings/SettingsView.swift
设置（预览）        → CustomPreviewSettings.swift
侧边栏              → SidebarView.swift
侧边栏收藏夹        → Domain/FavoritesStore.swift, FavoritesSidebarHost.swift
侧边栏废纸篓        → Domain/TrashLoader.swift, SidebarView.swift
侧边栏设备          → SidebarView.swift + SidebarVolumeLoader（卷名用系统 API）
主工具栏/搜索       → ContentView.swift
路径栏 tooltip      → PathBarView.swift
文件行右键          → FileListRowContextMenuBuilder.swift
空白右键            → FileListBlankMenuController.swift
表头右键            → FileListTableController+ColumnLayout.swift + FileListColumn.swift
预览全量            → Preview/ 目录（69 文件）
Snippets            → Snippets/ 目录、SnippetModels.swift、SnippetStore.swift
输出面板            → OutputPanelView.swift
Alert/确认框        → Domain/FileOperations.swift, SnippetsPanelView, DefaultFileViewerSettingsModel
错误消息            → SnippetImportExport, SnippetExpander, DefaultFileViewerManager 等 LocalizedError
权限引导            → FullDiskAccessPermission.swift, FinderAutomationPermission.swift
无障碍/工具提示     → 分散于各 View 的 .help() / instantHoverTooltip / accessibilityLabel
Info.plist         → Explorer/Info.plist + InfoPlist.strings
```

## 附录 B：语言混用地图

```
中文为主 ─────────────────────────────────────────►
  右键菜单、设置、Alert、输出面板、路径栏 tooltip、
  预览工具栏按钮、文件夹预览、权限 Sheet、文件操作对话框

英文为主 ─────────────────────────────────────────►
  侧边栏 Favorites/Devices、默认收藏名、列表列头 headerTitle、
  主搜索框 Search files、预览空状态、部分错误页

故意保留英文 ─────────────────────────────────────►
  Snippets、Job、Shell、QuickLook、Finder、MeoFind、
  zsh/bash、设置 Tab 名 Snippets
```
