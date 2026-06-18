# MeoFind 国际化（i18n）设计方案

> 目标：为 MeoFind（SPM 可执行目标 `Explorer`）实现 **简体中文 / 英文** 双语界面，首期覆盖侧边栏系统目录、废纸篓、右键菜单、系统菜单与设置窗口；后续逐步覆盖全应用 UI。  
> 本文档基于 2026-06 代码库现状编写，作为实施参考。

---

## 一、现状分析

### 1.1 项目结构

| 维度 | 结论 |
|------|------|
| 平台 | Swift / macOS 13+，SwiftUI + AppKit 混合 |
| 构建 | Swift Package Manager（SPM），无 `.xcodeproj` |
| 产物 | `Package.swift` 定义可执行目标 `Explorer`；`build_and_run.sh` 打包为 `MeoFind.app` |
| 模块 | `Explorer`（主应用）依赖 `FileList`（文件列表库） |

### 1.2 当前字符串组织方式

**结论：零 i18n 基础设施，几乎全部硬编码，且中英混用。**

| 模式 | 示例 | 分布 |
|------|------|------|
| SwiftUI 字面量 | `Button("切换左侧面板")` | `AppModule.swift`、Snippets 相关视图 |
| AppKit 字面量 | `NSMenuItem(title: "打开", ...)` | 右键菜单 builder |
| 枚举 `displayName` | `BlankDoubleClickAction`、`FileListColumnID` | 局部集中，不可扩展 |
| `LocalizedError` | Snippet 相关错误 | 中文硬编码 |

**语言混用现状：**

| 区域 | 倾向 |
|------|------|
| 菜单、对话框、工具提示、设置 | 以中文为主 |
| 侧边栏分区标题 | 英文：`Favorites`、`Devices` |
| 默认收藏夹名称 | 英文：`Home`、`Desktop`、`Documents`、`Downloads` |
| 列头 `headerTitle` | 英文：`Name`、`Type`、`Size`、`Date Modified` |
| 废纸篓 | 中文：`"废纸篓"`（`TrashLoader.displayName`） |
| 预览空状态、搜索框 | 英文 |
| 产品功能名 | 保留英文：`Snippets`、`Job` |

**未发现：** `NSLocalizedString`、`String(localized:)`、`Localizable.strings`、`.xcstrings`、`.lproj` 目录、`defaultLocalization`。

### 1.3 关键热点文件

| 文件 | 说明 |
|------|------|
| `Sources/Explorer/AppModule.swift` | 主窗口、侧边栏、菜单栏、设置、废纸篓、收藏夹（约 8000+ 行） |
| `Sources/Explorer/FileListRowContextMenuBuilder.swift` | 文件行右键菜单 |
| `Sources/FileList/FileListBlankMenuController.swift` | 空白处右键菜单 |
| `Sources/FileList/FileListColumn.swift` | 列头英/中双轨定义 |
| `Sources/Explorer/FavoritesSidebarHost.swift` | 收藏夹侧边栏显示与右键 |

---

## 二、目标与范围

### 2.1 语言支持

| 语言 | 标识 | 优先级 |
|------|------|--------|
| 简体中文 | `zh-Hans` | P0 |
| 英文 | `en` | P0 |

**首期策略**：跟随 **系统语言**（macOS 首选语言）自动切换，不在设置里单独做「语言选择」——实现成本低，符合 macOS 惯例。若后续需要应用内强制语言，可在 Phase 2 增加。

### 2.2 首期必做界面

| # | 区域 | 现状 | 关键文件 |
|---|------|------|----------|
| 1 | 左侧系统文件夹 | `Home`/`Desktop`/`Documents`/`Downloads` 英文写死并持久化 | `AppModule.swift` → `FavoritesStore` |
| 2 | 废纸篓 | 固定 `"废纸篓"`，且用于路径栏逻辑匹配 | `TrashLoader`、`SidebarView` |
| 3 | 右键菜单 | 文件行/空白处/收藏夹/Snippets 等全中文硬编码 | `FileListRowContextMenuBuilder.swift`、`FileListBlankMenuController.swift` 等 |
| 4 | 系统菜单 | `FileCommands` + `ExplorerApp.commands` | `AppModule.swift` |
| 5 | 设置窗口 | 通用 / Snippets / 高级三个 Tab | `AppModule.swift` → `SettingsView` 及子视图 |

### 2.3 首期范围外（Phase 2）

- 工具栏、搜索框、预览面板、Alert 全文、Snippets 编辑器、错误消息、无障碍 `.help()` 等
- 数量大但模式相同，可在首期框架搭好后批量迁移

---

## 三、技术选型

### 3.1 推荐方案：String Catalog + `L10n` 封装

```
Sources/
  Explorer/
    Resources/
      Localizable.xcstrings      ← Explorer 主应用文案
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
}
```

**键名规范**：`区域.语义`，如 `menu.context.paste`、`settings.general.blank_double_click`。

### 3.4 SwiftUI / AppKit 用法对照

| 场景 | 写法 |
|------|------|
| SwiftUI 静态文本 | `Text("action.open", bundle: .module)` 或 `Text(L10n.Action.open)` |
| SwiftUI Picker / Toggle | `Toggle("settings.pin_recent", bundle: .module, isOn: ...)` |
| AppKit NSMenuItem | `NSMenuItem(title: L10n.Action.open, ...)` |
| NSAlert | `alert.messageText = L10n.Alert.emptyTrashTitle` |
| 带插值 | `String(localized: "settings.job_limit \(count)", bundle: .module)` |

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

设备卷名已由 `SidebarVolumeLoader` 使用系统 `volumeLocalizedName`，**无需应用翻译**。

**系统文件夹翻译对照：**

| 键 | zh-Hans | en |
|----|---------|-----|
| `folder.home` | 个人 | Home |
| `folder.desktop` | 桌面 | Desktop |
| `folder.documents` | 文稿 | Documents |
| `folder.downloads` | 下载 | Downloads |

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
| `action.paste` | 粘贴 | Paste |
| `action.cut` | 剪切 | Cut |
| `action.copy` | 复制 | Copy |
| `action.delete` | 删除 | Delete |
| `action.rename` | 重命名 | Rename |
| `action.open_with` | 打开方式 | Open With |
| `action.add_favorite` | 收藏 | Add to Favorites |
| `action.show_package` | 显示包内容 | Show Package Contents |
| `action.get_info` | 显示简介 | Get Info |

改造方式：所有 `menuItem(title: "打开")` → `menuItem(title: L10n.Action.open)`。

#### B. 空白处右键 — `FileListBlankMenuController.swift`

| 键 | zh-Hans | en |
|----|---------|-----|
| `action.go_back` | 返回 | Back |
| `action.go_up` | 向上 | Up |
| `action.new_folder` | 新建文件夹 | New Folder |
| `action.new_file` | 新建文件 | New File |
| `action.open_terminal_here` | 在此处打开终端 | Open Terminal Here |

#### C. 其他右键

| 文件 | 内容 |
|------|------|
| `FavoritesSidebarHost.swift` | 「取消收藏」 |
| `SnippetsContextMenuBuilder.swift` | 子菜单标题「Snippets」（建议保留英文产品名） |
| `FileListTableController.swift` | 列显示「左移」「右移」 |
| `FileListColumn.swift` | 合并 `headerTitle` / `menuTitle` 为单一本地化源 |

**列头特别处理：**

`FileListColumnID` 目前有 `headerTitle`（英）和 `menuTitle`（中）双轨。改造后：

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
| `column.move_left` | 左移 | Move Left |
| `column.move_right` | 右移 | Move Right |

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

SwiftUI `Commands` 中：

```swift
Button(L10n.Menu.toggleLeftPanel) { ... }
```

对于「关闭/显示」成对文案，可用两个键或带参数的本地化字符串。

#### C. 标准菜单

`Settings { SettingsView() }`、`.newItem`、`.saveItem` 等由 SwiftUI 自动本地化（依赖系统），**一般无需处理**。自定义 `CommandGroup` 才需要改。

---

### 4.5 设置窗口

#### Tab 标签

| 键 | zh-Hans | en |
|----|---------|-----|
| `settings.tab.general` | 通用 | General |
| `settings.tab.snippets` | Snippets | Snippets |
| `settings.tab.advanced` | 高级 | Advanced |

#### 通用 Tab

| 控件 | 键示例 |
|------|--------|
| 空白处双击 | `settings.blank_double_click` |
| Picker 选项 | `settings.blank_action.parent` / `.terminal` |
| 默认文件夹查看器区块 | `settings.default_viewer.*` |

| 键 | zh-Hans | en |
|----|---------|-----|
| `settings.blank_double_click` | 空白处双击 | Double-click on blank area |
| `settings.blank_action.parent` | 返回上级目录 | Go to parent folder |
| `settings.blank_action.terminal` | 在本目录打开终端 | Open Terminal here |
| `settings.default_viewer.title` | 默认文件夹查看器 | Default Folder Viewer |
| `settings.default_viewer.current` | 当前默认 | Current Default |
| `settings.default_viewer.set` | 设为默认文件夹查看器 | Set as Default Folder Viewer |
| `settings.default_viewer.restore_finder` | 恢复 Finder | Restore Finder |

#### Snippets Tab

| 键 | zh-Hans | en |
|----|---------|-----|
| `settings.pin_recent_snippets` | 最近执行置顶 | Pin Recently Executed |
| `settings.job_concurrency_limit` | Job 并发上限：%lld | Job Concurrency Limit: %lld |
| `settings.auto_show_output` | Shell 执行时自动展开输出面板 | Auto-show Output Panel on Shell Run |
| `settings.confirm_destructive` | 危险命令二次确认 | Confirm Destructive Commands |

#### 高级 Tab

长说明文案放入 catalog，避免散落在 `Text("...")` 字面量中。

#### Alert 消息

`DefaultFileViewerSettingsModel` 中的成功/失败消息改为 `LocalizedError` + catalog，或 `L10n.Settings.Viewer.*`。

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
BUNDLE_SRC=$(find .build/release -name "Explorer_Explorer.bundle" -type d | head -1)
if [ -n "$BUNDLE_SRC" ]; then
    cp -R "$BUNDLE_SRC" "$RESOURCES_DIR/"
fi
# FileList bundle 同理（若 Explorer 依赖其资源）
```

**Info.plist 权限说明**（`NSAppleEventsUsageDescription` 等）应增加：

```
Explorer/
  en.lproj/InfoPlist.strings
  zh-Hans.lproj/InfoPlist.strings
```

并在打包脚本中复制对应 `.lproj` 目录。

---

## 六、实施阶段

### Phase 0 — 基础设施（约 2 天）

1. 修改 `Package.swift`：`defaultLocalization`、`resources`
2. 创建 `Localizable.xcstrings`（Explorer + FileList）
3. 创建 `L10n.swift` 骨架
4. 验证 `swift build` 后 bundle 内含 `.lproj`
5. 更新 `build_and_run.sh`

### Phase 1 — 首期五块界面（约 1 周）

按依赖顺序：

1. **废纸篓逻辑重构**（避免后续返工）
2. **`FavoriteItem` + `kind` 迁移**
3. **侧边栏显示**（分区标题 + 收藏夹 + 废纸篓）
4. **右键菜单**（三个 builder/controller）
5. **系统菜单 + 设置**

### Phase 2 — 全面覆盖（约 1 周）

- `AppModule.swift` 剩余文案（工具栏、预览、搜索、Alert）
- Snippets 面板、输出面板
- 错误消息、`LocalizedError`
- 单元测试适配（列标题断言改为不依赖语言）

---

## 七、测试策略

| 测试项 | 方法 |
|--------|------|
| 系统语言切换 | 系统设置 → 语言与地区 → 将 English / 简体中文 置顶，重启应用 |
| 侧边栏 | 中文下显示「桌面」「文稿」「下载」；英文下 Desktop/Documents/Downloads |
| 废纸篓路径栏 | 中英文下输入「废纸篓」/「Trash」均可跳转 |
| 旧数据迁移 | 保留含英文 `name` 的 `UserDefaults`，升级后显示正确本地化名 |
| 列偏好兼容 | 旧版保存的「名称」「Name」列偏好仍能正确识别 |
| 打包验证 | `MeoFind.app` 内存在 `Explorer_Explorer.bundle` 及 `zh-Hans.lproj` |

**自动化**：可为 `L10n` 或 `FavoriteItem.displayName` 写单元测试，用 `Bundle` 指定 `zh-Hans` / `en` 测试 bundle 验证关键字符串。

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
| P1 | `Sources/Explorer/AppModule.swift` | 侧边栏、菜单、设置、废纸篓、收藏夹 |
| P1 | `Sources/Explorer/FileListRowContextMenuBuilder.swift` | 菜单项本地化 |
| P1 | `Sources/FileList/FileListBlankMenuController.swift` | 菜单项本地化 |
| P1 | `Sources/Explorer/FavoritesSidebarHost.swift` | 使用 `displayName`、取消收藏 |
| P1 | `Sources/FileList/FileListColumn.swift` | 列标题统一本地化 |
| P1 | `Sources/FileList/FileListTableController.swift` | 表头菜单 |
| P2 | `Sources/Explorer/DefaultFileViewerSettingsModel.swift` | Alert 文案 |
| P2 | Snippets / Output / Preview 相关文件 | 批量替换 |
| P2 | `Explorer/Info.plist` + `*.lproj/InfoPlist.strings` | 权限描述本地化 |

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
| 产品名 Snippets | 保留英文 | 与功能品牌一致 |
| `AppModule.swift` | 不先拆分文件 | 控制 diff 范围；i18n 可与后续重构并行 |

---

## 十、待确认事项

实施前建议确认：

1. **开发语言**用 `en` 还是 `zh-Hans`？
2. **首期是否只做「跟随系统语言」**，还是要在设置里加「界面语言」选项？

---

## 附录：字符串分布速查

```
菜单栏命令          → AppModule.swift (FileCommands, ExplorerApp.commands)
设置               → AppModule.swift (SettingsView 及子 Tab)
侧边栏收藏夹        → AppModule.swift (FavoritesStore, SidebarView)
侧边栏废纸篓        → AppModule.swift (TrashLoader, SidebarView)
侧边栏设备          → AppModule.swift (SidebarVolumeLoader + "No devices")
文件行右键          → FileListRowContextMenuBuilder.swift
空白右键            → FileListBlankMenuController.swift
表头右键            → FileListTableController.swift + FileListColumn.swift
工具栏/预览/搜索    → AppModule.swift (ContentView 工具栏、PreviewPanel)
Alert/确认框        → AppModule.swift (FileOperations), SnippetsPanelView, SnippetExecutor
错误消息            → SnippetModels 相关 Error 枚举、DefaultFileViewerError
无障碍/工具提示     → 分散于各 View 的 .help() / accessibilityLabel
Info.plist         → Explorer/Info.plist
```
