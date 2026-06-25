# MeoFind 功能速查表（Cheat Sheet）与帮助窗口实施计划

> 目标：在菜单栏 **帮助 → MeoFind 功能速查** 打开一张简洁的速查表，每项功能一句话说明，可选附带快捷键列。

---

## 一、Cheat Sheet 正文（可直接作为帮助内容）

### 浏览与导航

| 功能 | 一句话说明 | 快捷键 |
|------|-----------|--------|
| 文件列表 | 当前目录下的文件与文件夹，支持列表/缩略图两种视图 | — |
| 列表视图 | 表格形式显示名称、类型、大小、日期等列，可点击表头排序 | 工具栏切换 |
| 缩略图视图 | 图标网格浏览，可拖动滑块调整缩略图大小 | 工具栏切换 |
| 路径面包屑 | 点击路径段快速跳转；空间不足时自动折叠中间段 | — |
| 路径编辑 | 点击路径栏可手动输入或粘贴完整路径 | — |
| 前进 / 后退 | 在浏览历史中前进或后退 | ⌘[ / ⌘] |
| 路径历史 | 下拉查看最近访问过的目录 | 路径栏按钮 |
| 快速搜索 | 输入即过滤当前列表，Tab 循环匹配项并同步预览 | 直接打字 |
| 全局搜索框 | 工具栏搜索框聚焦，按文件名筛选 | ⌘F |
| 双击打开 | 文件夹进入、文件用默认应用打开 | 双击 |
| 空白处双击 | 可设为返回上级目录或在当前目录打开终端 | 设置 → 通用 |
| 拖放打开 | 将文件/文件夹拖入窗口可导航到对应位置 | — |
| 外部打开 | 双击文件夹或从 Finder 拖入可在外部新窗口打开 | — |

### 侧边栏

| 功能 | 一句话说明 | 快捷键 |
|------|-----------|--------|
| 收藏夹 | 固定常用目录，右键可添加/移除收藏 | — |
| 位置 | 快速访问主目录、桌面、文稿、下载等系统位置 | — |
| 设备 | 动态显示已挂载的磁盘与移动硬盘，可推出 | — |
| 废纸篓 | 浏览已删除文件，支持放回原处与清空 | — |
| 显示/隐藏左侧面板 | 切换侧边栏与窄轨模式 | ⌘B |

### 文件操作

| 功能 | 一句话说明 | 快捷键 |
|------|-----------|--------|
| 打开 | 用默认方式打开文件或进入文件夹 | 回车 / 双击 |
| 新窗口打开 | 在独立窗口中打开文件夹 | 右键 |
| 打开方式 | 选择其他应用打开文件 | 右键 |
| 剪切 / 复制 / 粘贴 | 标准文件剪贴板操作 | ⌘X / ⌘C / ⌘V |
| 删除 | 移入废纸篓 | Delete |
| 立即删除 | 废纸篓中永久删除，跳过废纸篓 | 右键（废纸篓内） |
| 放回原处 | 从废纸篓恢复文件到原位置 | 右键（废纸篓内） |
| 清空废纸篓 | 永久清空废纸篓全部内容 | 右键空白 / 废纸篓内 |
| 重命名 | 单击选中后再次点击文件名，或右键重命名 | — |
| 新建文件夹 / 文件 | 在当前目录创建 | 右键空白 |
| 复制文件名 / 路径 | 将选中项名称或完整路径复制到剪贴板 | 右键 |
| 在此处打开终端 | 在选中目录启动系统终端 | 右键 |
| 属性 | 独立窗口查看大小、权限、标签、注释等详情 | 右键 |
| 服务 | 调用 macOS 系统服务菜单 | 右键 |
| 收藏 | 将文件夹加入侧边栏收藏夹 | 右键 |

### 预览

| 功能 | 一句话说明 | 快捷键 |
|------|-----------|--------|
| 文件预览 | 右侧面板实时预览选中文件，无需离开浏览器 | 选中文件 |
| 文本 / 代码 | 语法高亮、行号、换行、字体缩放、文内搜索 | 预览工具栏 |
| Markdown / HTML | 源码与渲染模式切换 | 预览工具栏 |
| 图片 | 缩放、旋转、翻转、取色、简单编辑与保存 | 预览工具栏 |
| PDF | 翻页、缩放、适应宽度/页面 | 预览工具栏 |
| 音视频 | 播放、暂停、静音 | 预览工具栏 |
| 压缩包 | 浏览 ZIP/TAR 等归档内文件列表 | 选中归档 |
| 电子表格 | 文本模式与 Quick Look 预览切换 | 预览工具栏 |
| Quick Look | 对不支持的类型回退到系统 Quick Look | 自动 |
| 文内搜索 | 在预览内容中查找并高亮，跳转下一处匹配 | 预览工具栏 |
| 独立预览窗口 | 将预览拖出为独立窗口，主窗口仍保留列表 | ⌘⌥P |
| 预览浏览器 | 底部胶片条浏览当前目录文件，上一项/下一项 | 菜单 / ⌘⌥B 展开条 |
| 自定义预览规则 | 按扩展名指定预览方式，可导入导出规则 | 设置 → 预览 |

### Snippets（命令片段）

| 功能 | 一句话说明 | 快捷键 |
|------|-----------|--------|
| Snippets 面板 | 右侧面板管理可复用脚本，按上下文过滤显示 | ⌘⇧S 切换 |
| 执行片段 | 搜索、方向键选择、回车或双击运行 | — |
| 作用域 | 按全局、文件类型、路径等限制片段出现时机 | 编辑器 |
| 变量展开 | 脚本中 `%p`（路径）、`%d`（目录）等自动替换 | 执行时 |
| 新建 / 编辑 | 支持 Shell、Python、AppleScript 等类型 | 面板按钮 |
| 导入 / 导出 | 单条或全部 JSON 备份与恢复 | 菜单 / 面板 |
| 内置片段 | 列目录、复制路径、打开终端等开箱即用 | 右键菜单 |

### 输出面板

| 功能 | 一句话说明 | 快捷键 |
|------|-----------|--------|
| 输出面板 | 底部显示脚本执行结果与交互式命令行 | ⌘J 切换 |
| Job 标签页 | 每次执行一个标签，可并行多个任务 | — |
| 命令框 | 在当前目录执行 zsh 命令，目录随地址栏同步 | 回车提交 |
| 命令历史 | 上方向键调出历史命令 | ↑ |
| 终止任务 | 运行中按 Ctrl+C 或点停止按钮 | Ctrl+C |
| 输出查找 | 在输出文本中搜索并高亮匹配 | 查找按钮 |
| 复制 / 清空 | 复制全部输出或清空当前标签 | 工具栏 |

### 窗口与布局

| 功能 | 一句话说明 | 快捷键 |
|------|-----------|--------|
| 显示/隐藏右侧面板 | 切换预览 + Snippets 整列 | ⌘⇧B |
| 面板高度 | 拖拽预览与 Snippets 之间的分隔条调整比例 | 拖拽 |
| 面板宽度 | 拖拽主列表与右侧面板之间的分隔条 | 拖拽 |
| 窗口贴靠 | 拖拽窗口靠边自动半屏/全屏贴靠 | 设置可开关 |
| 多窗口 | 文件夹可在新窗口独立打开 | 右键 / 拖出 |

### 设置

| 功能 | 一句话说明 | 快捷键 |
|------|-----------|--------|
| 通用 | 空白双击行为、窗口贴靠、界面语言 | ⌘, |
| Snippets | 显示模式、最近置顶、自动显示输出、并发上限 | 设置 |
| 预览 | 行号、独立窗口浏览、自定义文件类型规则 | 设置 |
| 默认文件管理器 | 将 MeoFind 设为系统默认文件夹打开方式 | 设置 → 通用 |

### 权限

| 功能 | 一句话说明 | 快捷键 |
|------|-----------|--------|
| 完全磁盘访问 | 浏览受保护目录（如桌面、文稿）需在系统设置授权 | 首次引导 |
| 自动化 | 读取废纸篓、控制终端需要自动化权限 | 按需提示 |

---

## 二、实施范围评估

| 项 | 估算 |
|----|------|
| 新增 Swift 文件 | 2～3 个（~200 行） |
| 本地化字符串 | ~80 条 × 2 语言（条目 + 分组标题） |
| 改动现有文件 | `AppModule.swift`、`L10n.swift`、两份 `Localizable.strings` |
| 不涉及 | 网络、持久化、与业务逻辑耦合 |

结论：**代码量可控，约半天可完成 MVP**；条目多主要体现在文案而非逻辑。建议分两期：MVP 静态速查表 → 二期按需加搜索/锚点跳转。

---

## 三、技术方案

### 3.1 入口

在 `ExplorerApp.commands` 增加：

```swift
CommandGroup(replacing: .help) {
    Button(L10n.Help.cheatSheet) {
        HelpWindowPresenter.shared.show()
    }
}
```

保留系统默认「MeoFind 帮助」可改为 `CommandGroup(after: .help)` 仅追加一项，避免替换掉系统 About 等项。macOS SwiftUI 默认已有 **应用名 → 关于**；我们只需在 **帮助** 菜单追加 **功能速查**。

推荐：

```swift
CommandGroup(after: .help) {
    Button(L10n.Help.cheatSheet) {
        HelpWindowPresenter.shared.show()
    }
    .keyboardShortcut("?", modifiers: .command) // 可选，与多数 Mac 应用一致
}
```

### 3.2 窗口呈现

复用 `FilePropertiesWindowController` 模式：单例 `HelpWindowPresenter` + `NSWindow` + `NSHostingView`，避免新增 `WindowGroup` 场景。

```
HelpWindowPresenter.swift      // show()、单例窗口复用
HelpCheatSheetView.swift       // SwiftUI 视图
HelpCheatSheetModels.swift     // 静态条目数据（或从 L10n 键组装）
```

窗口属性建议：
- 标题：`L10n.Help.windowTitle`（「MeoFind 功能速查」）
- 尺寸：520 × 640，可调整
- `styleMask`: `.titled, .closable, .resizable`
- 再次打开时 `makeKeyAndOrderFront`，不重复创建

### 3.3 UI 布局（Cheat Sheet 风格）

```
┌─────────────────────────────────────┐
│  MeoFind 功能速查                    │
├─────────────────────────────────────┤
│  [ScrollView]                        │
│   ## 浏览与导航                      │
│   ┌──────────────────────────────┐  │
│   │ 快速搜索    输入即过滤…  Tab │  │
│   │ 前进后退    浏览历史…  ⌘[/]  │  │
│   └──────────────────────────────┘  │
│   ## 文件操作                        │
│   ...                                │
└─────────────────────────────────────┘
```

实现要点：
- `LazyVStack` + 分组 `Section` 标题（`help.section.navigation` 等）
- 每行：`HStack { Text(name).fontWeight(.medium); Text(desc).foregroundStyle(.secondary); Spacer(); Text(shortcut).font(.caption.monospaced()) }`
- 分组间 `Divider` 或 section header 用 `.headline`
- 可选顶部一行副标题：`help.subtitle`（「一句话了解 MeoFind 能做什么」）

### 3.4 数据与本地化

**方案 A（推荐）**：条目存于 `Localizable.strings`，Swift 只维护键列表：

```swift
enum HelpSection: CaseIterable {
    case navigation, sidebar, files, preview, snippets, output, layout, settings

    var title: String { ... }
    var entryKeys: [HelpEntryKey] { ... }
}

struct HelpEntryKey {
    let nameKey: String      // help.entry.quick_search.name
    let descKey: String      // help.entry.quick_search.desc
    let shortcutKey: String? // help.entry.quick_search.shortcut（可为空）
}
```

**方案 B**：单条字符串 `"快速搜索|输入即过滤…|Tab"` 用 `|` 分隔 — 不利于翻译，不推荐。

快捷键列：空则显示 `—` 或隐藏列。

### 3.5 L10n 扩展

在 `L10n.swift` 增加：

```swift
enum Help {
    static var windowTitle: String { ... }
    static var cheatSheet: String { ... }  // 菜单项
    static var subtitle: String { ... }
    enum Section { ... }
    // 或用通用 help.entry.\(id).name / .desc
}
```

### 3.6 文件清单

| 文件 | 操作 |
|------|------|
| `Sources/Explorer/Help/HelpWindowPresenter.swift` | 新建 |
| `Sources/Explorer/Help/HelpCheatSheetView.swift` | 新建 |
| `Sources/Explorer/Help/HelpCheatSheetContent.swift` | 新建（条目键表） |
| `Sources/Explorer/AppModule.swift` | 追加 CommandGroup |
| `Sources/Explorer/L10n.swift` | 追加 `Help` |
| `Resources/zh-Hans.lproj/Localizable.strings` | 追加 ~80 键 |
| `Resources/en.lproj/Localizable.strings` | 追加 ~80 键 |
| `Package.swift` | 若新目录需确认 target 已包含（通常 `Sources/Explorer/**` 自动包含） |

---

## 四、实施步骤（建议顺序）

1. **文案定稿**：以本文 §一 为底稿，你确认删减/增补后冻结条目列表（当前约 55 行）。
2. **骨架**：`HelpWindowPresenter` + 空 `HelpCheatSheetView`，菜单能弹出空白窗口。
3. **数据层**：`HelpCheatSheetContent` 定义 section + entry keys。
4. **视图**：分组列表渲染，对齐 cheat sheet 两栏/三栏视觉。
5. **i18n**：批量写入 zh-Hans / en 字符串。
6. **快捷键列**：从 `ExplorerKeyboardShortcuts` 与 `ContentView` 隐藏按钮核对，避免文档与实现不一致。
7. **手工测试**：中/英界面各打开一次；窗口复用；菜单项与 ⌘? 快捷键。

---

## 五、验收标准

- [ ] 菜单 **帮助 → MeoFind 功能速查**（或等价文案）可打开窗口
- [ ] 窗口内容为分组表格，每项一句话，无长段落
- [ ] 中英文随系统/应用语言设置切换
- [ ] 不遮挡主窗口；关闭后可再次打开
- [ ] 文档中的快捷键与代码一致（至少覆盖 §一 表中列出的项）

---

## 六、二期可选增强（非 MVP）

- 窗口内搜索过滤条目
- 点击条目复制快捷键到剪贴板
- 分组锚点侧边栏（条目 > 30 时）
- 从帮助页 deep link 打开对应设置 Tab
- 随版本自动从 `L10n` / 菜单定义生成条目，减少双份维护

---

## 七、需要你确认的两点

1. **菜单文案**：「MeoFind 功能速查」/「功能速查表」/「使用手册」？
2. **范围**：§一 是否需删减（例如权限、默认文件管理器对普通用户是否过细）？

确认后即可按 §四 实施 MVP。
