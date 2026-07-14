# Snippets 面板与脚本执行 — 设计方案

> 目标：在右侧预览面板下方增加 **Snippets（命令片段）** 管理区，支持自定义脚本的增删改查、**整体/单条导入导出**、上下文变量展开、键盘/鼠标快速执行；Shell 类脚本走应用内 **输出面板 + 任务队列（Jobs）**，AppleScript 等类型走独立执行引擎。  
> 本文档为 Snippets 与脚本执行的**自包含设计**；原「工具栏搜索栏 `>` 命令模式」方案已放弃，不在本文档范围内。

---

## 一、背景与目标

### 1.1 现状

| 区域 | 现状 |
|------|------|
| 右侧面板 | 仅 `FilePreviewView`（预览），可通过菜单「显示/关闭预览」切换，宽度可拖拽持久化 |
| 脚本执行 | 尚无应用内执行与输出面板；Snippets 方案将引入变量展开、输出面板、Job 队列 |
| 设置 | `SettingsView` 含「通用 / 高级」Tab，高级项尚少 |

### 1.2 目标

1. **右侧面板纵向堆叠**：预览在上、Snippets 在下，各自独立折叠/关闭；两面板之间提供可拖拽分隔条，用于调整各自高度（比例持久化）。
2. **Snippets 全生命周期**：创建（名称、类型、**作用域**、内容、占位符提示）、编辑、删除、搜索、列表展示、执行、**整体/单条导入导出**。
3. **响应式列表布局**：随 **右侧面板总宽度** 自动 1→2→3… 列（见 §4.3；用户描述中的「左侧面板」在此按右侧面板宽度理解）。
4. **多脚本类型**：首版 **3 种**（Shell、Python、AppleScript），见 §6.1。
5. **上下文变量**：`%p`、`%d` 等，执行前展开。
6. **作用域**：定义 Snippet 在何种选中/浏览上下文中出现在列表（见 §3.5）；与占位符校验互补。
7. **执行体验**：搜索框模糊匹配、方向键导航、回车/双击执行、点击列表中的执行按钮执行、可选「最近执行置顶」。
8. **导入导出**：支持将全部 Snippets 或单条 Snippet 导出为 JSON 文件，并从 JSON 文件导入（含冲突处理）。
9. **Shell 输出**：底部 IDE 式输出面板 + 多 Job 标签页，流式输出、并发上限、取消/失败高亮。

### 1.3 非目标（首版）

- 用户可安装的任意第三方脚本插件（安全沙箱另议）
- Snippets 云端同步 / 市场
- 多窗口间 Snippets 实时同步
- 图形化脚本编辑器（首版用多行文本框即可）

---

## 二、总体布局

### 2.1 主窗口结构

```
┌──────────┬──────────────────────────────────────┬─────────────────┐
│          │  工具栏（路径 / 搜索）                 │                 │
│  左侧面板 │──────────────────────────────────────│   右侧面板       │
│ sidebar  │                                      │ ┌─────────────┐ │
│ / rail   │         文件列表（主区域）              │ │  预览面板    │ │
│          │                                      │ │ (可折叠)    │ │
│          │                                      │ ├─────────────┤ │
│          │                                      │ │  Snippets   │ │
│          │                                      │ │  (可折叠)    │ │
│          │                                      │ └─────────────┘ │
├──────────┴──────────────────────────────────────┴─────────────────┤
│  输出面板（可折叠）— Job 标签栏 + 流式 stdout/stderr               │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 右侧面板拆分

将现有 `explorerPreviewColumn` 扩展为 **右侧栈（RightPanelStack）**：

```swift
VStack(spacing: 0) {
    if showPreview {
        FilePreviewView(...)
            .frame(height: previewHeight) // 或 flex 比例
    }
    if showSnippets {
        SnippetsPanelView(...)
            .frame(maxHeight: .infinity)
    }
}
.frame(width: liveRightPanelWidth)
```

| 状态键 | 持久化 | 说明 |
|--------|--------|------|
| `showPreview` | 可选 `@AppStorage` | 与现有一致 |
| `showSnippets` | `@AppStorage` | 默认 `true` |
| `previewSnippetsSplitRatio` | `@AppStorage` | 预览:Snippets 高度比，默认 0.55 : 0.45 |
| `liveRightPanelWidth` | 沿用 `previewPanelWidthKey` | 键名可保留兼容，语义改为「右侧面板宽度」 |

**折叠行为**：

- 各子面板顶栏右侧 `×` 关闭 → 对应 `show*` 置 `false`，另一块占满剩余高度。
- 两者都关闭时，右侧整列隐藏（与当前 `showPreview == false` 行为一致），主列表区拉宽。
- 中间可加 **垂直拖拽分隔条**，调整预览与 Snippets 高度比。

### 2.3 系统菜单

在 `ExplorerApp.commands` 的 `CommandGroup(after: .sidebar)` 中扩展：

| 菜单项 | 快捷键（建议） | 行为 |
|--------|----------------|------|
| 显示/关闭预览 | 已有 | `showPreview.toggle()` |
| 显示/关闭 Snippets | `Cmd+Shift+S` | `showSnippets.toggle()` |
| 显示/关闭输出面板 | `Cmd+J` | 切换底部输出面板显示/隐藏 |
| 导入 Snippets… | — | 打开文件选择器，导入 JSON（见 §3.4） |
| 导出全部 Snippets… | — | 将全部条目写入 JSON 文件 |

---

## 三、Snippets 数据模型

### 3.1 核心结构

```swift
/// 首版仅 3 种；zsh 通过 `shell` + `interpreter` 切换，不单独占类型（§6.1）
enum SnippetScriptType: String, Codable, CaseIterable {
    case shell       // 默认 /bin/zsh（§8.2）；编辑时可改为 bash
    case python3     // /usr/bin/python3，多行写入临时 .py
    case appleScript // NSAppleScript / osascript
}

struct SnippetVariableHint: Codable, Identifiable {
    var id: UUID
    var placeholder: String   // 如 "%p"
    var label: String         // 如 "当前选中路径"
    var example: String?      // 如 "/Users/me/file.txt"
}

struct Snippet: Codable, Identifiable {
    var id: UUID
    var name: String
    var scriptType: SnippetScriptType
    var scope: SnippetScope                    // 何时出现在列表中，见 §3.5
    var content: String
    var variableHints: [SnippetVariableHint]  // 创建时勾选/自定义
    var sortOrder: Int                        // 手动排序
    var lastExecutedAt: Date?                 // 最近执行置顶用
    var executionCount: Int
    var createdAt: Date
    var updatedAt: Date
    // Shell 专用可选字段
    var workingDirectory: SnippetWorkingDirectory? // .cwd | .selectedParent | fixedPath
    var interpreter: String?                  // 覆盖默认解释器，如 /opt/homebrew/bin/fish
}
```

#### 3.1.1 作用域类型（首版 7 种）

首版仅实现下列作用域；其余见 §3.5.1「后续扩展」。

| 作用域 | 简述 |
|--------|------|
| `anytime` | 无需选中，始终可见 |
| `global` | 选中任意 1+ 项（文件或目录） |
| `filesOnly` | 有选中且全部为文件 |
| `directoriesOnly` | 有选中且全部为目录 |
| `singleSelection` | 恰好选中 1 项 |
| `fileExtensions` | 指定扩展名（如 `pdf`、`png`） |
| `specificFiles` | 指定文件路径（完整路径匹配） |

```swift
/// 首版 `SnippetScope` 仅包含以下 case
enum SnippetScope: Codable, Equatable {
    case anytime
    case global
    case filesOnly
    case directoriesOnly
    case singleSelection
    case fileExtensions([String])   // 小写、无点：["pdf", "md"]
    case specificFiles([String])    // 标准化 POSIX 路径
}
```

### 3.2 持久化

- 路径：`~/Library/Application Support/Explorer/snippets.json`
- 格式：JSON 数组，带 `schemaVersion` 便于迁移
- Store：`SnippetStore`（`ObservableObject`）
- 内置默认 Snippets：首次启动写入若干条（见 §6.2），`isBuiltin: true` 可禁止删除、允许禁用

### 3.3 编辑 UI（Sheet / Inspector）

| 字段 | 控件 |
|------|------|
| 名称 | `TextField`，列表标签展示，限长 24 字 |
| **作用域** | `Picker` + 条件附加控件（§3.5.3）；保存时做与占位符的一致性提示 |
| 脚本类型 | `Picker`，切换时更新占位符建议与语法高亮（可选 Phase 2） |
| 内容 | 多行 `TextEditor`，等宽字体，高度 8–12 行 |
| 变量占位符 | 下方「插入变量」芯片按钮 + 已选提示列表（勾选常用项）；编辑时支持快捷键插入（§7.4） |
| 高级（Shell） | 解释器：`zsh`（默认，§8.2）/ `bash` / 自定义路径；工作目录 |
| 操作 | 保存 / 取消 / 删除（二次确认）/ **导出此条** |

### 3.4 导入与导出

支持 **整体（批量）** 与 **单条** 两种粒度，统一使用 JSON 文件交换，便于备份、迁移与团队共享。

#### 3.4.1 文件格式

导出文件为 UTF-8 JSON，扩展名建议 `.mqf-snippets.json`（亦接受 `.json`）。

**整体导出** — 根对象为信封结构：

```json
{
  "schemaVersion": 1,
  "exportedAt": "2026-06-17T10:00:00Z",
  "app": "MeoFind",
  "kind": "snippet-bundle",
  "snippets": [ /* Snippet 对象数组，见下 */ ]
}
```

**单条导出** — 根对象为单条 Snippet（或同样使用信封，`kind: "snippet-single"` 且 `snippets` 仅含一项）。单文件导入时两种格式均识别。

单条 `Snippet` 导出字段（与 §3.1 一致；**不导出**运行时统计，避免覆盖本地使用数据）：

| 字段 | 导出 | 说明 |
|------|------|------|
| `id` | ✅ | 导入时用于冲突检测 |
| `name` / `scriptType` / `content` | ✅ | 核心定义 |
| `scope` | ✅ | 作用域定义 |
| `variableHints` / `workingDirectory` / `interpreter` | ✅ | 可选配置 |
| `sortOrder` | ✅（整体）/ 可选（单条） | 单条导入时追加到列表末尾 |
| `lastExecutedAt` / `executionCount` | ❌ | 各端本地维护 |
| `isBuiltin` | ❌ | 内置项不可导出为可编辑副本时单独标记 |

#### 3.4.2 入口与交互

| 粒度 | 入口 | 行为 |
|------|------|------|
| **整体导出** | 顶栏 `⋯` →「导出全部…」；菜单「导出全部 Snippets…」 | `NSSavePanel`，默认文件名 `snippets-YYYYMMDD.json` |
| **整体导入** | 顶栏 `⋯` →「导入…」；菜单「导入 Snippets…」 | `NSOpenPanel` 选文件 → 校验 → 冲突处理（§3.4.3）→ 合并入 `SnippetStore` |
| **单条导出** | 列表项右键 →「导出…」；编辑 Sheet「导出此条」 | 默认文件名 `{名称}.mqf-snippets.json` |
| **单条导入** | 顶栏 `⋯` →「导入…」（与整体共用） | 解析为 1 条时直接走单条冲突流程；多条时走批量流程 |
| **拖拽**（可选 Phase 2） | 将 `.json` 拖到 Snippets 列表区 | 等同「导入」 |

顶栏 `⋯` 菜单结构：

```
导入…
导出全部…
─────────
从剪贴板导入（可选 Phase 2）
```

单条导出额外支持 **复制为 JSON 到剪贴板**（右键子项），便于即时分享给他人。

#### 3.4.3 导入校验与冲突处理

**校验**（失败则弹窗，不写入）：

- JSON 语法合法、`schemaVersion` 受支持
- 每条 `name` 非空、`scriptType` 为已知枚举、`content` 非空
- 单文件最多 500 条（可配置），防止误导入超大文件

**冲突**：当导入条目的 `id` 或 `name`（忽略大小写）与本地已有条目重复时，弹出确认 Sheet：

| 策略 | 行为 |
|------|------|
| **跳过** | 保留本地，忽略导入项 |
| **覆盖** | 用导入项替换同 `id` 项；同 `name` 不同 `id` 时替换名称匹配项 |
| **重命名** | 保留本地，导入项改名为 `名称 (导入)` 或 `名称 (2)`… |
| **全部应用** | 对**本次导入**统一选一种策略（仅当次有效，不写入设置） |

首版默认：发生冲突时 **弹出询问**（不预设跳过/覆盖）；用户可在对话框中选择策略，或使用「全部应用」作用于当次批量导入。

单条导入冲突时可用简化对话框：「替换现有 / 保留两者（重命名）/ 取消」。

导入完成后：Toast「已导入 N 条，跳过 M 条」；列表滚动到第一条新导入项。

#### 3.4.4 实现要点

```swift
enum SnippetExportScope {
    case single(Snippet)
    case all([Snippet])
}

struct SnippetImportExport {
    static func export(_ scope: SnippetExportScope, to url: URL) throws
    static func importSnippets(from url: URL) throws -> [SnippetImportItem]
}

struct SnippetImportItem {
    var snippet: Snippet
    var conflict: SnippetImportConflict? // .duplicateID | .duplicateName
}
```

- `SnippetStore` 提供 `importItems(_:strategy:)`、`exportAll()`、`exportSnippet(id:)`
- 整体导出**不包含** `isBuiltin: true` 的条目，或导出为只读副本并在导入时强制 `isBuiltin: false`（推荐后者并加 `origin: "builtin"` 元数据）
- 导入在后台线程解析 JSON，主线程更新 UI

### 3.5 Snippet 作用域

作用域决定 Snippet **是否出现在 Snippets 列表**（及文件列表上下文菜单，§11.3）。  
**作用域 ≠ 执行校验**：列表可见后，执行时仍由占位符展开（§7）做运行时校验；两者应一致配置，保存时给出警告。

#### 3.5.1 作用域一览（首版）

| 作用域 | 可见条件 | 典型用途 |
|--------|----------|----------|
| **anytime** | 始终可见（无选中亦可） | `ls -la %d`、打开当前目录 |
| **global** | `selection.count ≥ 1`（文件或目录均可） | 通用 `stat %P`、混合选中 |
| **filesOnly** | 有选中，且**每一项** `!isDirectory` | `open %p`、处理文件内容 |
| **directoriesOnly** | 有选中，且**每一项** `isDirectory` | 对文件夹批量操作 |
| **singleSelection** | `selection.count == 1` | `stat %p`、复制路径 |
| **fileExtensions** | 至少一个选中**文件**的扩展名在列表中（小写、无点；目录项不参与匹配） | 仅 PDF、仅 Markdown |
| **specificFiles** | 至少一个选中项的标准化路径 **完全等于** 列表中某路径 | 对固定配置文件一键执行 |

**首版不包含、后续再扩展**（导入 JSON 若含未知 `kind` 则提示跳过或映射为 `global`）：

| 作用域 | 说明 |
|--------|------|
| `multipleSelection` | 选中 2+ 项；首版可用 `global` + `%P`，执行时校验 |
| `uniformTypes` | UTType 匹配；首版用 `fileExtensions` 代替 |
| `underDirectories` / `cwdUnder` | 按目录路径限定可见性 |
| `symlinksOnly` / `packagesOnly` / `hiddenItemsOnly` | 特殊项类型 |
| `composite AND` | 组合条件（如「文件且 pdf」） |

**不建议作为作用域、而用占位符/执行校验表达的**：

- 「需要选中文件但允许混选目录」→ 用 `global` + 执行时 `%f` 报错更清晰
- 「按文件大小 / 修改时间」→ 运行时条件，首版不做作用域

#### 3.5.2 列表过滤规则

```swift
struct SnippetVisibilityContext {
    var cwd: String
    var selectedItems: [FileItem]
    var showHiddenFiles: Bool
}

enum SnippetScopeMatcher {
    static func isVisible(_ snippet: Snippet, context: SnippetVisibilityContext) -> Bool
}
```

**首版固定行为**：不满足作用域的 Snippet **直接隐藏**（不提供灰显开关，见 §8.2）。

过滤顺序：

```
全部 Snippets
  → 作用域过滤（§3.5.1）
  → 底部搜索关键字过滤（§4.4）
  → 排序（最近执行置顶 / sortOrder）
```

`selection` 或 `path` 变化时，列表 **即时刷新**可见项，不重启应用。

#### 3.5.3 编辑 UI：作用域配置

首版 Picker **仅展示 §3.5.1 首版 7 种**。

| 作用域类型 | 附加控件 |
|------------|----------|
| anytime / global / filesOnly / directoriesOnly / singleSelection | 仅 Picker |
| fileExtensions | 标签输入框，逗号分隔；常见扩展名建议（pdf、png、md…） |
| specificFiles | 「添加文件…」`NSOpenPanel` 多选，列表可删 |

**智能建议**（保存时非阻断提示）：

| 脚本内容含 | 建议作用域 |
|------------|------------|
| 仅 `%d` | `anytime` |
| `%p` / `%f` | `singleSelection` 或 `filesOnly` |
| `%P` / `%F` | `global`（首版无 `multipleSelection`） |
| 特定扩展名语义 | `fileExtensions` |

#### 3.5.4 与内置示例的对应

见 §6.2；每条内置 Snippet 应带合理默认 `scope`。

---

## 四、Snippets 面板 UI

### 4.1 顶栏

与 `FilePreviewView` 共用 `PanelTopBarMetrics`：

```
[ Snippets ]                    [ + 新建 ] [ ⋯ 导入导出 ] [ × 关闭 ]
```

### 4.2 列表项样式

单行（1 列时）结构：

```
┌────────────────────────────────────────────────────────────┐
│ [标签: 名称] [pdf]  stat %p…       │  ▶ 执行  │
└────────────────────────────────────────────────────────────┘
```

| 元素 | 规则 |
|------|------|
| 名称 | `Capsule` / 浅色背景标签，主色或按类型分色 |
| 作用域徽标（可选） | 非 `global` / `anytime` 时，名称旁小号次要标签，如 `文件`、`1项`、`pdf`；悬停显示完整作用域说明 |
| 内容预览 | 展开变量前的 **原始** 模板文本，默认 **10 个字符** + `…`（`truncationMode(.tail)`） |
| 执行按钮 | `▶` 或 `play.fill`，`buttonStyle(.borderless)`；灰显项禁用 |
| 选中态 | 搜索/键盘导航时整行背景高亮 |
| 悬停 | 显示完整内容 `help` 或 tooltip |

**列表数据源**：仅包含当前 `SnippetVisibilityContext` 下 **可见** 的 Snippets（§3.5.2）；搜索在可见集上再做关键字过滤。

**交互**：

- 单击行：选中（不执行）
- 双击行 / 回车（焦点在列表或搜索框）：执行当前选中项
- 右键：编辑 / 删除 / **导出…** / 复制
- 长按拖拽（Phase 2）：调整 `sortOrder`

### 4.3 响应式列数

基于 **右侧面板当前宽度** `w`（非左侧 sidebar）：

| 宽度 `w` | 列数 |
|----------|------|
| `w ≤ 400` | 1 |
| `400 < w ≤ 600` | 2 |
| `600 < w ≤ 800` | 3 |
| `800 < w ≤ 1000` | 4 |
| … | `列数 = min(maxColumns, 1 + floor((w - 400) / 200))`，其中 `w > 400` |

实现：`LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount), spacing: 8)`

`maxColumns` 建议上限 4，避免单元格过窄。

### 4.4 底部搜索框

位于列表 **下方**（用户明确要求）：

```
┌──────────────────────────────────────────┐
│  🔍  搜索名称或脚本内容…              [×] │
└──────────────────────────────────────────┘
```

| 元素 | 规则 |
|------|------|
| 关闭按钮 `×` | 位于输入框**右侧**；**仅当有关键词输入时显示**（非空时可见） |
| 点击 `×` | 清空搜索文本、恢复完整列表（仍受作用域过滤）、焦点保留在搜索框 |

| 行为 | 说明 |
|------|------|
| 模糊匹配 | 名称 + `content` 子串匹配（首版）；在 **作用域已过滤** 的列表上检索 |
| 过滤 | 实时过滤列表，无匹配时显示空状态（区分「无 Snippet」与「当前上下文无匹配项」） |
| 默认选中 | **第一个匹配项**自动高亮 |
| 回车 | 执行当前高亮项 |
| `Esc` | 等同点击 `×`：清空搜索并恢复列表 |
| 焦点 | `Cmd+Shift+F` 聚焦 Snippets 搜索（与文件搜索区分） |

### 4.5 最近执行置顶

设置项（§8）：`pinRecentlyExecutedSnippets: Bool`，默认 `true`。

- 开启：每次成功触发执行后更新 `lastExecutedAt`，列表排序为 `lastExecutedAt DESC, sortOrder ASC`
- 关闭：仅按 `sortOrder`
- 手动拖拽排序与置顶可共存：置顶组内再按 `sortOrder`

---

## 五、键盘导航

### 5.1 焦点模型

Snippets 面板使用 `FocusState<SnippetsFocus>`：

- `.search` — 搜索框
- `.list` — 列表区

文件列表与 Snippets 列表互斥焦点：焦点在文件列表时方向键不作用于 Snippets。

### 5.2 方向键（列表焦点）

设当前过滤后列表为一维数组 `items`，再映射到 `row = index / cols`，`col = index % cols`。

| 布局 | 按键 | 行为 |
|------|------|------|
| 1 列 | `↑` / `↓` | 上一项 / 下一项 |
| 2+ 列 | `↑` / `↓` | 同列上一行 / 下一行（无则不动） |
| 2+ 列 | `←` / `→` | 上一项 / 下一项（按阅读顺序） |
| 任意 | `Enter` | 执行选中项 |
| 任意 | `Delete` | 删除选中项（确认） |
| 任意 | `Cmd+Enter` | 编辑选中项 |

**搜索框内**：`↓` 进入列表并选中第一项；`Enter` 执行第一项。

---

## 六、脚本类型与执行引擎

### 6.1 首版类型（3 种）

| 类型 | 执行方式 | 输出面板 | 典型场景 |
|------|----------|----------|------|
| **shell** | `Process` + `/bin/zsh -lc`（默认，§8.2）；编辑时可改为 bash | ✅ 流式 Job | `ls`、`stat`、`open`、`pbcopy`、调用 CLI |
| **python3** | `/usr/bin/python3` + 临时 `.py` 或 `-c`（单行） | ✅ 流式 Job | 文本处理、批量重命名、小脚本 |
| **appleScript** | `NSAppleScript` 或 `osascript` 子进程 | ⚠️ 见 §6.3 | Finder、系统 UI、控制其他 App |

**首版 Picker 仅上述 3 项。** `shell` 默认使用 zsh（§8.2）；编辑页可改为 bash，二者执行管线相同。

#### 6.1.1 首版不单独实现的类型（及原因）

| 类型 | 建议 | 原因 |
|------|------|------|
| **zsh**（独立类型） | 并入 `shell` 的解释器选项 | 与 bash 同属 Shell 管线，避免 Picker 重复 |
| **openURL / 默认应用打开** | **不实现** | 与文件列表双击打开重复；一条 shell 即可：`open %p` 或 `open -a Preview %p` |
| **JavaScript (JXA)** | Phase D+ | 用户面窄，与 AppleScript 场景重叠 |
| **Swift** | Phase D+ | 冷启动慢，不适合 Snippet 一键执行 |
| **纯通知** | Phase D+ | 可用 shell `osascript -e 'display notification …'` 代替 |

#### 6.1.2 后续可扩展

`javascript`、`swift`、`openURL`（若仍需无终端的 `NSWorkspace` 快捷方式）等；导入 JSON 含未知 `scriptType` 时提示跳过。

### 6.2 内置示例 Snippets

| 名称 | 类型 | 作用域 | 内容 |
|------|------|--------|------|
| 列出目录 | shell | `anytime` | `ls -la %d` |
| 查看属性 | shell | `singleSelection` | `stat %p` |
| 在终端打开 | shell | `anytime` | `open -a Terminal %d` |
| 复制路径 | shell | `singleSelection` | `printf '%s' %p \| pbcopy` |
| 用默认应用打开 | shell | `filesOnly` | `open %q` |
| 显示 Finder 信息 | appleScript | `singleSelection` | `tell application "Finder" to open information window of (POSIX file "%p" as alias)` |
| 打开 PDF（预览） | shell | `fileExtensions(["pdf"])` | `open -a Preview %q` |

### 6.3 AppleScript 执行引擎

**推荐方案**：进程内 `NSAppleScript` 为主，复杂脚本回退 `osascript` 子进程。

```swift
protocol ScriptExecutor {
    func execute(
        snippet: Snippet,
        context: SnippetExecutionContext,
        job: JobHandle?
    ) async throws -> ScriptExecutionResult
}

struct ScriptExecutionResult {
    var stdout: String
    var stderr: String
    var exitCode: Int32
}
```

| 路径 | 优点 | 缺点 |
|------|------|------|
| `NSAppleScript` | 无子进程开销、易捕获 `NSAppleEventDescriptor` 字符串结果 | 阻塞需放后台队列；错误信息需解析 `NSDictionary` |
| `osascript` 子进程 | 与 Shell 统一 Job 模型、可杀进程 | 多一次进程启动 |

**交互建议**：

- AppleScript 默认 **不强制** 打开输出面板；若 `stdout` 非空或执行失败，自动展开并新建 Job 标签「AppleScript: 名称」。
- 成功且无输出：可选 Toast「已执行」或状态栏短暂提示。
- 需 UI 回调的脚本（如 `display dialog`）必须在主线程执行 `NSAppleScript`，与 Job 取消语义分离。

### 6.4 Shell / Python 执行管线

`shell` 与 `python3` 均走 **SnippetExecutor → ShellRunner → JobStore → OutputPanelView**（解释器与参数不同）。

| 类型 | Process 组装 |
|------|----------------|
| `shell` | `{interpreter ?? /bin/zsh} -lc {expanded}` |
| `python3` | `/usr/bin/python3` + 临时脚本文件（多行）或 `-c`（单行且无换行） |

`shell` 默认解释器：**`/bin/zsh`**（`SnippetDefaults.shellInterpreter`，§8.2）；单条 Snippet 可在编辑页改为 bash 或自定义路径。

#### 6.4.1 执行流程

```
用户触发执行（按钮 / 回车 / 双击）
  → SnippetExecutor 校验上下文（占位符前置条件）
  → SnippetExpander.expand(content, context:) 展开变量
  → ShellRunner 组装 Process（解释器 + -lc / 临时脚本文件）
  → JobStore.enqueue(job) → queued → running
  → OutputPanelView 选中该 Job 标签，流式追加 stdout/stderr
  → 进程结束：记录 exitCode、结束时间 → succeeded | failed
  → 更新 Snippet.lastExecutedAt、executionCount（§4.5）
```

#### 6.4.2 Job 元数据

执行 Snippet 时，Job 记录：

| 字段 | 说明 |
|------|------|
| `displayCommand` | 展开后的完整命令行（用户可读） |
| `source` | `.snippet(id: UUID, name: String)` |
| `snippetName` | 列表标签名称，用于 Job 标签标题 |
| `startedAt` / `endedAt` | 开始 / 结束时间 |
| `exitCode` | 子进程退出码 |
| `status` | `queued` / `running` / `succeeded` / `failed` / `cancelled` |

Job 标签标题优先显示 `snippetName`，悬停展示完整 `displayCommand`。

#### 6.4.3 并发与取消

- 并发上限默认 **2**，可在设置中调整为 1–4（`maxConcurrentJobs`）
- 超出上限的 Job 保持 `queued`，有槽位后自动启动
- 输出面板 Job 标签上的 **×** 或工具栏 **停止**：`Process.terminate()` → `cancelled`
- 关闭标签视为强制结束，不等待优雅退出

#### 6.4.4 失败处理

| 场景 | 行为 |
|------|------|
| 占位符前置条件不满足（如未选中却用 `%p`） | **不启动进程**；输出面板展开并显示错误说明（非崩溃） |
| 命令不存在 / 无法启动进程 | Job 状态 `failed`，stderr 显示系统错误 |
| 退出码非 0 | Job 状态 `failed`；输出面板顶部红色/橙色 Banner：「命令失败，退出码 N」 |
| 用户取消 | Job 状态 `cancelled` |

#### 6.4.5 执行后反馈

- `autoShowOutputPanelOnShellRun == true`（默认）时，执行后自动展开输出面板并选中对应 Job
- 执行成功后可选择 Toast「已执行：{名称}」（不打断查看输出）
- 不写入已放弃的「命令行历史」；仅更新 Snippet 自身的 `lastExecutedAt` / `executionCount`

---

## 七、上下文变量（占位符）

### 7.1 首版必备

| 占位符 | 含义 | 展开规则 | 未满足时 |
|--------|------|----------|----------|
| `%p` | 当前选中项路径（单选） | 标准化 POSIX 路径 | 错误：需要单选 |
| `%d` | 当前浏览目录（cwd） | `ContentView.path` | 始终可用 |
| `%P` | 所有选中项路径 | 空格分隔多个路径 | 错误：需要至少一项 |
| `%f` | 仅选中**文件**（非目录） | 单选且 `!isDirectory` | 错误：需要选中文件 |
| `%F` | 所有选中文件 | 过滤目录后拼接 | 无文件时错误 |

**验收用例**（展开与错误提示）：

| 操作 | Snippet 内容 | 预期 |
|------|--------------|------|
| 单选文件，cwd 为某目录 | `ls -la %d` | 输出当前目录列表 |
| 单选文件 | `stat %p` | 输出该文件 stat 信息 |
| 多选 2+ 项 | `stat %P` | 输出所有选中路径的 stat |
| 未选中任何项 | 含 `%p` 或 `%P` | 输出面板显示明确错误，不启动进程 |
| 仅选中目录 | 含 `%f` | 显示「需要选中文件」类错误 |

### 7.2 建议扩展

| 占位符 | 含义 | 示例 |
|--------|------|------|
| `%n` | 选中项文件名（含扩展名） | `report.pdf` |
| `%b` | 不含扩展名的 basename | `report` |
| `%e` | 扩展名（小写，无点） | `pdf` |
| `%N` | 选中项数量 | `3` |
| `%q` | `%p` 的 shell 单引号转义版 | `'/path/with spaces'` |
| `%Q` | `%P` 每项分别转义后拼接 | 安全拼接多路径 |
| `%h` | 用户主目录 | `/Users/me` |
| `%u` | 短用户名 | `me` |
| `%w` | 当前目录名（非完整路径） | `Documents` |
| `%t` | 临时文件路径 | 写入展开内容到 temp 文件，Job 结束删除 |
| `%clipboard` | 当前剪贴板字符串 | 需剪贴板读权限 |
| `%date` | ISO8601 本地时间 | `2026-06-17T10:00:00` |
| `%uuid` | 每次执行生成新 UUID | 批量唯一命名 |
| `%ask{提示}` / `%ask[id]{提示}` | **执行前向用户询问**；提示作输入项标题；多参数一张表单 | 详见 [snippets-user-input-design.md](./snippets-user-input-design.md) |

**转义规则**：

- Shell 类：路径默认用 `shellQuote()`；用户显式写 `%q` / `%Q` 时不二次引号。
- AppleScript：路径用 `POSIX file "..."` 时内部双引号转义。
- 文档：设置页与编辑 Sheet 提供「变量参考」折叠区。

### 7.3 展开上下文

```swift
struct SnippetExecutionContext {
    var cwd: String
    var selectedItems: [FileItem]   // 来自 ContentView selection + items
    var environment: [String: String] // 可选：继承/覆盖环境变量
}
```

### 7.4 编辑时插入占位符快捷键

在 **Snippet 编辑 Sheet** 的 `content` 输入框聚焦时：

| 快捷键 | 插入 |
|--------|------|
| `Tab` | `%p` |
| `Option+D` | `%d` |
| `Option+F` | `%f` |
| `Option+P` | `%P`（可选） |

与列表搜索框、工具栏文件搜索 **无绑定**；`Tab` 在列表区仍用于焦点切换。

### 7.5 展开实现

```swift
enum SnippetExpander {
    static func expand(
        _ template: String,
        context: SnippetExecutionContext,
        scriptType: SnippetScriptType = .shell,
        askValues: [String: String] = [:]
    ) throws -> String
}
```

- 含 `%ask` 时先由 `SnippetAskParser` / 表单收集输入，再传入 `askValues`（见 [snippets-user-input-design.md](./snippets-user-input-design.md)）
- 未知占位符原样保留或警告（首版原样保留）
- 展开失败抛 `SnippetExpansionError` / `SnippetAskParseError`，由 `SnippetExecutor` 转为输出面板错误信息

---

## 八、设置项

在 `SettingsView` 新增 **「Snippets」** Tab（或并入「高级」）。首版 **仅暴露 4 项**，其余行为采用固定推荐默认值（§8.2），不设 UI 开关。

### 8.1 用户可配置（4 项）

| 键 | 类型 | 默认 | 说明 |
|----|------|------|------|
| `pinRecentlyExecutedSnippets` | Bool | `true` | 最近执行置顶 |
| `maxConcurrentJobs` | Int | `2` | Job 并发上限（1–4） |
| `autoShowOutputPanelOnShellRun` | Bool | `true` | Shell / Python 执行时自动展开输出面板 |
| `confirmDestructiveSnippets` | Bool | `true` | 内容含 `rm`、`mv` 等关键字时二次确认 |

持久化：`@AppStorage` 或 `UserDefaults`，键名加 `snippets.` 前缀。

### 8.2 推荐默认值（不设设置入口）

下列行为写死在实现或常量中，首版不提供设置 UI；后续若反馈强烈再考虑开放。

| 常量 / 行为 | 推荐默认 | 说明 |
|-------------|----------|------|
| `SnippetDefaults.shellInterpreter` | **`zsh`**（`/bin/zsh`） | 新建 `shell` 类型 Snippet 的默认解释器；编辑 Sheet 仍可改为 bash |
| 导入冲突 | **每次询问** | 不默认跳过/覆盖；批量导入时可「全部应用」但仅当次有效（§3.4.3） |
| 作用域不可用项 | **隐藏** | 列表不展示当前上下文不匹配的 Snippet（不灰显） |

```swift
enum SnippetDefaults {
    static let shellInterpreter = "/bin/zsh"
    static let hidesUnavailableSnippets = true
}
```

---

## 九、输出面板与任务队列

> Snippets 触发的 Shell 执行与（未来）其他脚本来源共用同一套输出面板与 Job 队列。

### 9.1 输出面板

| 能力 | 说明 |
|------|------|
| 位置 | 主窗口底部，`VStack` 最下层 |
| 折叠 | 垂直拖拽条调整高度 + `Cmd+J` 切换显示/隐藏；持久化 `outputPanelHeight`、`isOutputPanelVisible` |
| 自动展开 | Snippet 执行 Shell 时，若 `autoShowOutputPanelOnShellRun` 为 true，自动展开并选中当前 Job |
| 流式输出 | `FileHandle` 异步读取子进程 stdout/stderr，主线程追加 `AttributedString`（stderr 可用区分色） |
| 元数据栏 | **展开后的命令**、开始时间、结束时间、运行时长、**退出码** |
| 工具栏 | **清屏**（仅当前 Job 视图）、**复制全部**输出、面板内**查找**（`Cmd+F` 在输出区聚焦时） |
| 失败条 | Job 为 `failed` 时，输出区顶部高亮 Banner：「命令失败，退出码 {code}」 |
| 空状态 | 无 Job 时显示「执行 Snippet 后在此查看输出」 |

**验收项**：

- [ ] 执行 Snippet 后输出面板可自动展开（可设置关闭）
- [ ] stdout / stderr 实时流式追加，不阻塞 UI
- [ ] 元数据栏展示展开后命令行与退出码
- [ ] `Cmd+J` 可切换面板显示/隐藏
- [ ] 支持清屏、复制输出、面板内查找
- [ ] 命令不存在或退出码非 0 时状态为失败，退出码可见

### 9.2 Job 队列

```
┌─ [查看属性 ×] [列出目录 ×] [+] ───────────────────────────────────┐
│ 命令: /bin/zsh -lc 'stat /Users/me/file.txt'  退出码: —  运行中…  │
├──────────────────────────────────────────────────────────────────┤
│ … 流式输出 …                                                      │
└──────────────────────────────────────────────────────────────────┘
```

| 状态 | 含义 | UI |
|------|------|-----|
| `queued` | 等待并发槽位 | 标签显示排队图标 |
| `running` | 子进程活跃 | 标签显示进行中；提供 **停止** 按钮 |
| `succeeded` | 退出码 0 | 标签正常样式 |
| `failed` | 退出码非 0 或启动失败 | 标签警示色 + 顶部失败 Banner |
| `cancelled` | 用户关闭标签或点停止 | 标签灰显 |

**交互**：

- 每次 Snippet 执行产生 **一个新 Job**，对应输出面板顶部 **一个可关闭标签**
- 点击标签切换查看该 Job 的完整输出（已结束 Job 输出保留在内存，可设上限如 50 条后淘汰最旧）
- 标签 **×** 关闭：若仍在 `running`，`terminate()` 进程并标为 `cancelled`
- 连续执行多条 Snippet：最多 `maxConcurrentJobs`（默认 2）路并发，其余 `queued`

**验收项**：

- [ ] 连续提交多条 Snippet 时，最多 2 条并发（可调），其余排队
- [ ] 输出面板顶部可切换不同 Job 的输出
- [ ] 运行中 Job 可停止；关闭标签强制结束进程
- [ ] Job 状态涵盖 queued / running / succeeded / failed / cancelled

### 9.3 建议测试 Snippet

内置或手动创建以下 Snippet 用于联调：

```text
列出目录      shell    ls -la %d
查看属性      shell    stat %p
多选属性      shell    stat %P
必定失败      shell    /usr/bin/false
```

---

## 十、模块划分与文件结构

```
Sources/Explorer/
├── Snippets/
│   ├── SnippetModels.swift            // Snippet、SnippetScope
│   ├── SnippetScopeMatcher.swift      // 作用域可见性判定
│   ├── SnippetStore.swift
│   ├── SnippetExpander.swift          // 变量展开
│   ├── SnippetExecutor.swift          // 路由 shell / python3 / AppleScript
│   ├── AppleScriptEngine.swift
│   ├── SnippetsPanelView.swift
│   ├── SnippetListItemView.swift
│   ├── SnippetEditorSheet.swift
│   ├── SnippetImportExport.swift      // JSON 序列化、校验、冲突检测
│   └── SnippetsKeyboardHandler.swift
├── ScriptRuntime/                     // Shell 执行与输出（原命令面板执行层，不含搜索栏调起）
│   ├── ShellRunner.swift
│   ├── JobStore.swift
│   ├── OutputPanelView.swift
│   └── JobModels.swift
└── RightPanel/
    ├── RightPanelStackView.swift      // 预览 + Snippets 纵向栈
    └── RightPanelSplitDivider.swift   // 垂直高度拖拽
```

**依赖关系**：

```
ContentView
  ├── RightPanelStackView
  │     ├── FilePreviewView
  │     └── SnippetsPanelView → SnippetStore + SnippetScopeMatcher
  └── OutputPanelView → JobStore
        ↑
SnippetExecutor ──→ ShellRunner
                 └── AppleScriptEngine
```

---

## 十一、增强方案与交互建议

以下为可选迭代，首版可不实现，但架构上预留扩展点。

### 11.1 执行前预览（Dry Run）

- 按住 `Option` 点击执行：弹出 Sheet 显示 **展开后** 的最终命令 / AppleScript，确认后再跑。
- 对含 `%P`、`rm` 的脚本尤其有用。

### 11.2 分组与标签

- `Snippet.group: String?`（如「Git」「图片」「系统」），列表顶部分段筛选。
- 比纯搜索更适合 Snippets 数量 > 20 时。

### 11.3 文件列表上下文菜单

- 「Snippets」子菜单：仅列出 **当前作用域匹配** 的 Snippets（与右侧面板列表同源过滤）。
- 快速执行，无需切到右侧面板。

### 11.4 工具栏固定 Snippets

- 用户可将常用 Snippet  pin 到工具栏图标区（类似 Safari 扩展），一键执行。

### 11.5 AppleScript 体验优化

- 提供「在脚本编辑器中打开」按钮（`OSAScriptEditor`）。
- 模板库：窗口操作、剪贴板、通知中心。

### 11.6 安全

- 危险命令检测：`rm -rf`、`mkfs`、`dd` 等关键字 + `confirmDestructiveSnippets` 开关（§8.1）。
- Snippets **不**以管理员权限执行；如需 `sudo`，明确提示用户在终端手动执行。

---

## 十二、分阶段实施计划

| 阶段 | 范围 | 估时 |
|------|------|------|
| **Phase A** | 右侧面板栈、预览/Snippets 独立折叠、菜单项、`SnippetStore` 本地读写 | 2–3 天 |
| **Phase B** | Snippets CRUD UI、**作用域配置与列表过滤**、搜索、响应式列、键盘导航、单条/整体导入导出 | 3–4 天 |
| **Phase C** | 变量展开（§7）、`shell` + `python3` 执行、`ShellRunner` + JobStore + 输出面板（§6.4、§9） | 3–4 天 |
| **Phase D** | AppleScript 引擎、§8.1 设置项 UI；**扩展脚本类型**（JXA、Swift 等）与**扩展作用域** | 2–3 天 |
| **Phase E** | 文件列表上下文菜单、Dry Run | 2–4 天 |

**建议顺序**：Phase A–B 与 Phase C 中输出面板/Job 可并行；Shell 执行管线（§6.4、§9）应在 Snippets 列表可执行前打通。

---

## 十三、验收清单（摘要）

### 布局

- [ ] 预览在上、Snippets 在下，均可独立关闭并在菜单中重新打开
- [ ] 右侧面板宽度拖拽后，Snippets 列数按 400/600/800… 阶梯变化
- [ ] 预览与 Snippets 高度可拖拽调整

### Snippets 管理

- [ ] 新建/编辑/删除，含名称、类型、**作用域**、内容、变量提示
- [ ] 作用域（首版 7 种）：`filesOnly` 在仅选目录时不出现；`fileExtensions` 仅在匹配扩展名时出现；`singleSelection` 在多选时不出现
- [ ] `anytime` 类 Snippet 在无选中时仍可见；`global` 在无选中时隐藏
- [ ] 列表：名称标签 + 10 字内容预览 + 执行按钮
- [ ] 底部搜索：名称与内容模糊匹配，首项高亮，回车执行；有关键词时右侧显示 `×`，点击清空
- [ ] **整体导出**：菜单/顶栏可导出全部 Snippets 为 JSON，重新导入后内容一致
- [ ] **整体导入**：可选文件导入多条，冲突策略（跳过/覆盖/重命名）生效
- [ ] **单条导出**：右键或编辑 Sheet 可导出单条 JSON
- [ ] **单条导入**：导入仅含 1 条的 JSON 可追加或替换，不重命名时名称不冲突

### 执行与输出

- [ ] 脚本类型（首版 3 种）：`shell`（含 bash/zsh 解释器）、`python3`、`appleScript` 可执行
- [ ] Shell：输出面板流式输出、Job 标签、退出码、停止/关闭标签取消
- [ ] AppleScript：可执行简单 Finder 脚本，错误可查看
- [ ] `%p` / `%d` / `%P` / `%f` 验收用例符合 §7.1
- [ ] 占位符错误时不启动进程，输出面板显示明确提示
- [ ] `Cmd+J` 切换输出面板；清屏、复制、面板内查找可用
- [ ] 连续执行：并发上限与排队符合 §9.2

### 键盘

- [ ] 1 列：上下选择；多列：上下左右按 §5.2
- [ ] 双击与回车执行

### 设置

- [ ] §8.1 四项设置可读写且生效：最近执行置顶、Job 并发上限、自动展开输出面板、危险命令确认
- [ ] 新建 `shell` Snippet 默认解释器为 zsh（§8.2，无设置项）
- [ ] 作用域不匹配项默认隐藏（§8.2）

---

## 十四、与现有代码的衔接点

| 现有符号 | 改动 |
|----------|------|
| `ContentView.showPreview` | 抽出 `RightPanelStackView`，新增 `showSnippets` |
| `explorerPreviewColumn` | 改为右侧栈 + 单一水平 `HorizontalResizeDivider` |
| `FilePreviewView` 顶栏 `×` | 行为不变，仅关闭预览块 |
| `ExplorerApp.commands` | 增加 Snippets 菜单项 |
| `SettingsView` | 增加 Snippets Tab，仅 §8.1 四项 |
| `PanelTopBarMetrics` | Snippets 顶栏复用 |

---

## 附录 A：列数计算参考实现

```swift
func snippetColumnCount(for panelWidth: CGFloat, maxColumns: Int = 4) -> Int {
  guard panelWidth > 400 else { return 1 }
  let extra = Int((panelWidth - 400) / 200)
  return min(maxColumns, 2 + extra)
}
// 401→2, 600→2, 601→3, 800→3, 801→4
```

## 附录 B：模糊匹配（首版）

```swift
func matches(snippet: Snippet, query: String) -> Bool {
  let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  guard !q.isEmpty else { return true }
  return snippet.name.lowercased().contains(q)
      || snippet.content.lowercased().contains(q)
}
```

## 附录 C：单条导出 JSON 示例

```json
{
  "schemaVersion": 1,
  "exportedAt": "2026-06-17T10:00:00Z",
  "app": "MeoFind",
  "kind": "snippet-single",
  "snippets": [
    {
      "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
      "name": "查看属性",
      "scriptType": "shell",
      "scope": { "kind": "singleSelection" },
      "content": "stat %p",
      "variableHints": [
        { "id": "…", "placeholder": "%p", "label": "当前选中路径" }
      ],
      "sortOrder": 10,
      "workingDirectory": null,
      "interpreter": null
    }
  ]
}
```

---

## 附录 D：作用域匹配参考实现（首版）

```swift
func isVisible(scope: SnippetScope, context: SnippetVisibilityContext) -> Bool {
    let sel = context.selectedItems
    switch scope {
    case .anytime:
        return true
    case .global:
        return !sel.isEmpty
    case .filesOnly:
        return !sel.isEmpty && sel.allSatisfy { !$0.isDirectory }
    case .directoriesOnly:
        return !sel.isEmpty && sel.allSatisfy(\.isDirectory)
    case .singleSelection:
        return sel.count == 1
    case .fileExtensions(let exts):
        let set = Set(exts.map { $0.lowercased() })
        return sel.contains { !$0.isDirectory && set.contains($0.pathExtension.lowercased()) }
    case .specificFiles(let paths):
        let set = Set(paths.map { ($0 as NSString).standardizingPath })
        return sel.contains { set.contains(($0.path as NSString).standardizingPath) }
    }
}
```

---

*文档版本：1.6 · 设置项精简为 4 项*
