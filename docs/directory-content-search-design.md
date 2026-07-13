# 当前目录全文搜索（方案 A）— 设计方案

> 目标：在 Explorer 顶栏搜索框扩展「内容搜索」模式，在当前 PathBar 目录范围内跨文件搜索文本内容；有结果时**主区域替换为搜索结果视图**（方案 A），支持多文件、多处匹配 snippet 展示、键盘导航，以及与右侧预览的深度联动。  
> 开发计划见 [directory-content-search-plan.md](./directory-content-search-plan.md)。

---

## 一、背景与目标

### 1.1 参照对象

| 产品 | 相关能力 | 可借鉴点 |
|------|----------|----------|
| **VS Code** | 侧边栏 Search | 文件分组 + 行级 snippet + 折叠；glob `files to include/exclude` |
| **Cursor** | 同上 | 点击结果打开编辑器并定位；搜索与资源管理器过滤分离 |
| **Sublime Text** | Find in Files | 结果面板替换主编辑区；Enter 跳转下一匹配 |
| **MeoFind 预览内搜索** | `PreviewTextSearchToolbarControls` | `3/12` 计数、上下匹配、`PreviewTextSearchHighlighter` 黄/橙高亮 |

### 1.2 MeoFind 现有搜索体系（必须兼容）

| 机制 | 状态字段 | 行为 | 快捷键 |
|------|----------|------|--------|
| 顶栏搜索 | `searchText` | **过滤**当前目录文件名 | `⌘F` |
| Quick Search | `quickSearchText` | **不过滤**，高亮 + 滚动定位 | 列表焦点直接打字 |
| 预览内搜索 | `PreviewSession.text.searchQuery` | 单文件内容查找 | 预览工具栏 |
| Command Palette | — | 搜索**命令** | `⌘⇧P` |

**原则**：全文搜索是**第四套独立机制**，不覆盖 `searchText` 的过滤语义；与 Quick Search 互斥（内容搜索激活时列表内打字不唤起 Quick Search）。

### 1.3 需求目标

1. **范围**：PathBar 显示的当前目录；默认**包含子目录**；切换目录时取消进行中的搜索并清空结果。
2. **模式**：顶栏搜索框支持「文件名 / 内容」模式切换；文件名模式保持现有行为。
3. **结果展示（方案 A）**：有内容搜索结果时，中间主区域从 `FileListView` 切换为**搜索结果视图**；PathBar、左侧面板、右侧面板保持不变。
4. **多文件多匹配**：按文件分组折叠；每组展示行号 + 上下文 snippet + 关键词高亮；摘要栏显示文件数/匹配数/耗时。
5. **文件名过滤**：独立过滤条，支持 glob 包含/排除、大小写、子目录开关、单文件大小上限。
6. **预览联动**：选中匹配 → 右侧预览打开文件、跳到对应行、同步搜索词与高亮；`⌘G` / `⌘⇧G` 全局循环匹配。
7. **键盘导航**：`↑↓` 行间、`Enter` 打开并定位、`Esc` 退出内容搜索回到文件列表。
8. **i18n**：新增文案进 `Localizable.xcstrings`（`en` + `zh-Hans`）+ `L10n.swift`。

### 1.4 非目标（首版）

- 跨卷 / Spotlight 全局索引搜索（见 `docs/phase1-plan.md` Phase 3）
- `⌘P` 快速打开任意路径文件
- 正则表达式搜索（Phase 3 可选）
- PDF / Office 二进制内文本抽取（Phase 3；首版仅纯文本类扩展名）
- 搜索结果持久化、搜索历史云同步
- 替换（Replace in Files）

---

## 二、交互设计（方案 A）

### 2.1 总体布局

```
┌─ 左侧面板 ─┬─ PathBar: ~/Projects/app ────────────────────────────────┬─ 右侧面板 ─┐
│  sidebar   │  🔍 [TODO          ] [内容 ▾]  [过滤 ▾]   ☐ 区分大小写      │  预览      │
│            ├─────────────────────────────────────────────────────────────┤            │
│            │  ▼ AuthService.swift                              3 处匹配  │  （联动    │
│            │    │  42 │     // TODO: refresh expired tokens            │   跳转行）  │
│            │    │  89 │     guard !token.isEmpty // TODO               │            │
│            │    │ 156 │     // TODO: add rate limiting                 │            │
│            │  ▶ Config.plist                                   1 处匹配  │            │
│            │  ▶ Utils.swift                                    2 处匹配  │            │
│            ├─────────────────────────────────────────────────────────────┤            │
│            │  5 个文件 · 6 处匹配 · 0.3s              ⌘G 下一个匹配      │            │
└────────────┴─────────────────────────────────────────────────────────────┴────────────┘
```

**与文件列表的关系**：

| 状态 | 主区域显示 |
|------|------------|
| 模式 = 文件名，或内容模式但查询为空 | `FileListView`（现有） |
| 模式 = 内容，查询非空 | `DirectoryContentSearchResultsView` |
| 内容模式，查询非空，搜索进行中 | 结果视图 + 顶部进度条 + 已找到的部分结果 streaming 追加 |
| `Esc` / 清空查询 / 切回文件名模式 | 回到 `FileListView` |

**动画**：主区域切换使用 150ms `opacity` 交叉淡入淡出；PathBar 不闪烁。

### 2.2 顶栏搜索框扩展

在现有 `BarTextField`（220pt 胶囊，`ContentView` toolbar）上扩展：

```
┌──────────────────────────────────────────────┐
│ 🔍  [查询词…………………]  [文件名 ▾]  [⚙]        │
└──────────────────────────────────────────────┘
```

| 控件 | 说明 |
|------|------|
| 查询词 | 复用 `$searchText` 或新增 `$contentSearchQuery`（**推荐分离**，见 §4.1） |
| 模式下拉 | `SearchMode`: `.filename` / `.content`；持久化 `@AppStorage` |
| ⚙ 过滤 | 展开/收起过滤条（内容模式可见；文件名模式可隐藏或仅显示 glob） |
| 区分大小写 | 过滤条内 Toggle，默认关 |

**模式切换行为**：

- 切到「内容」：`searchText` 清空或迁移为 `contentQuery`（首版：**字段分离**，避免过滤语义冲突）
- 切到「文件名」：取消进行中的搜索任务，隐藏结果视图，恢复 `searchText` 过滤
- placeholder 随模式变化：`L10n.Search.prompt` / `L10n.Search.contentPrompt`

**快捷键**：

| 快捷键 | 行为 |
|--------|------|
| `⌘F` | 聚焦顶栏搜索（现有）；若已在内容模式则保持 |
| `⌘⇧F` | 聚焦顶栏搜索并切换到「内容」模式 |
| `Esc`（搜索框聚焦） | 内容模式：清空查询并回到文件名模式；文件名模式：清空 `searchText`（现有） |
| `Esc`（结果列表聚焦） | 退出内容搜索，回到文件列表 |

### 2.3 过滤条（可折叠）

点击 ⚙ 或 `⌘⌥F` 展开第二行（PathBar 下方、主区域上方）：

```
┌─ 过滤 ────────────────────────────────────────────────────────────────┐
│  包含  [*.swift *.md          ]    排除  [*_test.*  node_modules/** ]   │
│  ☑ 包含子目录   最大文件 [2 MB ▾]   最多显示 [200 处 ▾]   ☐ 正则      │
└───────────────────────────────────────────────────────────────────────┘
```

**Glob 语法（Phase 1）**：

- 空格分隔多个 pattern
- `*` 单段通配；`**` 跨目录（简化实现：`**/foo` 表示任意深度下的 `foo`）
- 示例：`*.swift`、`*. {swift,md}`（Phase 2）、`**/Tests/**`

**默认排除**（可取消）：

- `node_modules/**`、`.git/**`、`DerivedData/**`、`*.xcuserstate`
- 隐藏文件（遵循 `showHiddenFiles` 设置；隐藏文件默认不参与内容搜索）

**扫描限制**：

| 项 | 默认 | 说明 |
|----|------|------|
| 单文件大小上限 | 2 MB | 超出跳过，摘要不计入 |
| 最大匹配数 | 200 | 超出后停止扫描并提示 |
| 并发读文件 | 4 | 后台队列，主线程仅更新 UI |

### 2.4 搜索结果视图

#### 2.4.1 三层信息结构

**第 1 层 — 摘要栏（sticky footer 或 header）**

```
5 个文件 · 12 处匹配 · 扫描 0.3s          [⌘G 下一个]
```

- 搜索中：`已扫描 847/3200 文件 · 找到 3 处匹配` + 细进度条
- 无结果：橙色 `L10n.Search.contentNoResults`
- 结果被截断：`还有约 40 处未显示，请缩小范围或提高上限`

**第 2 层 — 文件分组 Header**

```
▼ AuthService.swift                    src/Auth/     3
```

- 左：展开/折叠 chevron + 文件图标 + 文件名（bold）
- 中：相对路径（仅当文件不在当前目录根层时显示，secondary）
- 右：匹配数 badge（caption2.monospacedDigit）
- 默认：前 5 个文件展开，其余折叠；记住用户折叠状态（会话内）

**第 3 层 — 匹配行（snippet）**

```
   42 │     // TODO: refresh expired tokens
```

- 行号：等宽、右对齐、可点击；宽度随最大行号自适应（最少 4 字符）
- 分隔符：`│`
- 正文：单行 snippet（匹配行原文 trim）；关键词用黄底高亮（复用 `FileListTextHighlight` 配色逻辑）
- 当前选中行：accent 背景 + 行号加粗（对齐列表选中行视觉）
- 可选 Phase 2：上下各 1 行上下文（灰色 secondary，折叠在 tooltip 或展开态）

#### 2.4.2 列表实现选型

| 方案 | 优点 | 缺点 | 建议 |
|------|------|------|------|
| SwiftUI `ScrollView` + `LazyVStack` | 与 ContentView 集成简单 | 超大结果性能 | **Phase 1 采用** |
| AppKit `NSOutlineView` | 原生分组折叠、键盘 | 实现成本高 | Phase 3 若 >500 行再评估 |

首版结果上限 200 处，`LazyVStack` 足够。

### 2.5 键盘与鼠标交互

#### 结果视图

| 输入 | 行为 |
|------|------|
| `↑` `↓` | 在**扁平化匹配行**间移动（跨文件） |
| `←` `→` | 折叠/展开当前文件分组 |
| `Enter` | 打开匹配：选中文件 + 预览定位 + 结果行高亮 |
| `⌘G` | 下一个匹配（全局） |
| `⌘⇧G` | 上一个匹配 |
| `Space` | 预览当前匹配（`showPreview = true`），不离开结果视图 |
| `Esc` | 退出内容搜索 |
| 单击 snippet 行 | 同 Enter |
| 单击文件 header | 切换折叠 |
| 双击文件 header | 在文件列表语义下「打开」文件（进入子目录或预览） |

#### 与 Quick Search 互斥

内容搜索激活条件：`searchMode == .content && !contentQuery.isEmpty`

此时 `FileListInteractionCoordinator.handleQuickSearchKeys` **不处理**字母输入（由顶栏搜索框或结果视图消费）。

#### 与预览内搜索协调

选中匹配并打开预览时：

1. `PreviewSession` 加载文件
2. 设置 `text.searchQuery = contentQuery`
3. 新增 `text.scrollToLine(_:)` 或通过 `PreviewTextSearchHighlighter` 定位到该行的第一个匹配
4. 预览内 `⌘G` 仅在**当前文件**内循环；结果视图的 `⌘G` 在**全局匹配**间循环——两者通过 `DirectoryContentSearchSession` 协调当前 global index

### 2.6 空态与边界

| 状态 | 展示 |
|------|------|
| 内容模式，查询为空 | 主区域仍显示文件列表；过滤条可用；placeholder 提示 |
| 搜索中，尚无匹配 | 摘要栏 spinner +「搜索中…」 |
| 完成，零匹配 | 结果视图占主区域，居中「未找到匹配内容」 |
| 目录无文本文件 | 「当前目录没有可搜索的文本文件」 |
| 网络卷 / 慢盘 | 进度更明显；支持 Esc 取消 |
| 切换目录 | 取消任务、清空结果、回文件列表 |
| 预览文本编辑中 | 允许搜索；Enter 打开其他文件时提示保存（沿用现有编辑守卫） |

---

## 三、搜索能力设计

### 3.1 可搜索文件类型

首版复用 `PreviewTypeClassifier.isTextFile` + `isCodeFile` 并集，减去：

- 二进制扩展名（已由 classifier 排除）
- HTML 预览模式依赖项（搜索读**磁盘原文**，不渲染 HTML）
- 大于 `maxFileSize` 的文件

**Phase 3 扩展**：PDF 文本层、Office 纯文本导出模式。

### 3.2 匹配算法

**Phase 1 — 子串匹配（与预览内搜索一致）**：

```swift
PreviewTextSearchHighlighter.findMatchRanges(of: query, in: line)
```

- 按行扫描文件内容（`String.Encoding` 检测：UTF-8 优先，失败试 UTF-16 / Latin1）
- 每行可产生 0~N 个匹配；每个匹配对应一条 `ContentSearchMatch`
- 默认 `caseInsensitive`；「区分大小写」开启时用 `.literal` 或去掉 `.caseInsensitive`

**Phase 3 — 正则**：过滤条「正则」Toggle 开启时，用 `NSRegularExpression`；无效正则显示 inline 错误，不发起搜索。

### 3.3 搜索引擎架构

```
DirectoryContentSearchEngine
  ├── enumerateFiles(root: URL, filter: ContentSearchFilter) -> AsyncStream<URL>
  ├── scanFile(url: URL, query: String, options: ContentSearchOptions) -> [ContentSearchMatch]
  └── run(session: DirectoryContentSearchSession) // 协调取消、进度、streaming 回调
```

**实现策略**：

| 阶段 | 策略 | 理由 |
|------|------|------|
| Phase 1 | Swift 原生枚举 + 逐文件读入 + 行扫描 | 无外部依赖；glob/大小/取消完全可控 |
| Phase 2 | 后台 `TaskGroup` 并行读文件 | 大目录提速 |
| Phase 3 | 可选调用 `/usr/bin/grep -rn` 或 bundled `rg` | 极大目录；需解析输出格式 |

**取消**：每次 `query` / `filter` 变化递增 `searchGeneration`；引擎在 generation 不匹配时停止写入结果。

**Debouncing**：查询输入停止 **300ms** 后触发搜索（PathBar 搜索框 `onChange` debounce）。

### 3.4 数据模型

```swift
enum DirectorySearchMode: String, Codable {
    case filename
    case content
}

struct ContentSearchFilter: Equatable, Codable {
    var includePatterns: [String]   // glob，空 = 全部
    var excludePatterns: [String]   // 默认含 node_modules、.git
    var includesSubdirectories: Bool
    var caseSensitive: Bool
    var maxFileSizeBytes: Int
    var maxMatchCount: Int
    var useRegex: Bool              // Phase 3
}

struct ContentSearchMatch: Identifiable, Equatable {
    let id: UUID
    let fileURL: URL
    let relativePath: String        // 相对搜索根目录
    let lineNumber: Int             // 1-based
    let lineText: String            // 单行原文
    let matchRangeInLine: Range<String.Index> // 高亮用
}

struct ContentSearchFileGroup: Identifiable, Equatable {
    let id: String                  // fileURL.path
    let fileURL: URL
    let relativePath: String
    let matches: [ContentSearchMatch]
    var isExpanded: Bool
}

struct ContentSearchProgress: Equatable {
    var scannedFileCount: Int
    var totalFileCount: Int?        // 枚举完成后可知
    var matchCount: Int
    var elapsed: TimeInterval
    var isComplete: Bool
    var wasCancelled: Bool
    var wasTruncated: Bool
}
```

### 3.5 Glob 匹配

`ContentSearchGlobMatcher`：

- 将 glob 转为 `NSRegularExpression` 或逐段匹配
- 路径分隔符统一 `/`
- 文件名-only pattern（无 `/`）匹配 `lastPathComponent`；含 `/` 的匹配相对路径

单元测试覆盖：`*.swift`、`**/Tests/**`、排除规则优先级（exclude 优先于 include）。

---

## 四、架构设计

### 4.1 状态模型

**推荐：`searchText` 与 `contentQuery` 分离**

| 字段 | 用途 |
|------|------|
| `searchText` | 文件名过滤（现有，不变） |
| `contentQuery` | 内容搜索关键词 |
| `searchMode` | `.filename` / `.content` |
| `contentSearchSession` | `DirectoryContentSearchSession`（`@StateObject` 每窗口） |

`DirectoryContentSearchSession`（`ObservableObject`）：

```swift
@MainActor
final class DirectoryContentSearchSession: ObservableObject {
    @Published var query: String
    @Published var filter: ContentSearchFilter
    @Published var groups: [ContentSearchFileGroup]
    @Published var progress: ContentSearchProgress
    @Published var selectedMatchID: UUID?
    @Published var flattenedMatches: [ContentSearchMatch] // 键盘导航用

    func search(root: URL, showHiddenFiles: Bool)
    func cancel()
    func selectNextMatch(forward: Bool)
    func toggleGroupExpansion(fileID: String)
}
```

持久化（`@AppStorage` / `AppPreferences`）：

- `searchMode`
- `contentSearchFilter`（JSON）
- 不持久化：query、results、selectedMatch

### 4.2 模块与文件规划

```
Sources/Explorer/DirectoryContentSearch/
├── DirectoryContentSearchModels.swift       # 模型
├── DirectoryContentSearchFilter.swift         # 过滤默认值、Codable
├── ContentSearchGlobMatcher.swift             # glob
├── DirectoryContentSearchEngine.swift         # 扫描引擎（actor）
├── DirectoryContentSearchSession.swift        # 会话、debounce、取消
├── DirectoryContentSearchResultsView.swift    # 主结果视图
├── DirectoryContentSearchFileGroupView.swift  # 文件分组
├── DirectoryContentSearchMatchRowView.swift   # snippet 行
├── DirectoryContentSearchSummaryBar.swift     # 摘要栏
├── DirectoryContentSearchFilterBar.swift      # 过滤条
├── DirectoryContentSearchModePicker.swift     # 模式下拉
└── DirectoryContentSearchKeyboardMonitor.swift # ⌘G / Esc 兜底
```

### 4.3 ContentView 集成

```swift
// explorerBrowserColumn 伪代码
VStack(spacing: 0) {
    PathBar(...)
    if searchMode == .content {
        DirectoryContentSearchFilterBar(session: contentSearchSession, isExpanded: $filterExpanded)
    }
    Group {
        if shouldShowContentSearchResults {
            DirectoryContentSearchResultsView(session: contentSearchSession, ...)
        } else {
            FileListView(...)
        }
    }
    .animation(.easeOut(duration: 0.15), value: shouldShowContentSearchResults)
}
```

**Toolbar 改动**：

- `searchContent` 闭包内：`BarTextField` + `DirectoryContentSearchModePicker`
- 文件名模式：绑定 `$searchText`
- 内容模式：绑定 `$contentSearchSession.query`

**目录切换**（`path` onChange）：

```swift
contentSearchSession.cancel()
contentSearchSession.groups = []
```

### 4.4 预览联动

新增 `PreviewSession+ContentSearchJump.swift`：

```swift
extension PreviewSession {
    func revealContentSearchMatch(_ match: ContentSearchMatch, query: String) {
        text.searchQuery = query
        // 加载完成后：
        text.scrollToLine(match.lineNumber)
        text.searchCurrentIndex = indexOfMatchOnLine(...)
    }
}
```

`DirectoryContentSearchResultsView` 在 `selectedMatchID` 变化时调用上述 API。

**FileList 选中同步**：选中匹配时 `selection = [FileItem(match.fileURL)]`，便于右键菜单、工具栏操作仍可用。

### 4.5 与现有组件复用

| 现有资产 | 复用方式 |
|----------|----------|
| `PreviewTextSearchHighlighter` | 行内匹配定位、预览高亮 |
| `FileListTextHighlight` | snippet 关键词高亮 |
| `PreviewTextSearchToolbarControls` | 交互参考（计数、⌘G） |
| `BarTextField` | 顶栏搜索框 |
| `PreviewTypeClassifier` | 可搜索扩展名 |
| `DirectorySizeVolumeFilter` | 网络卷提示（可选） |
| `HelpCheatSheetContent` | 新增 help 条目 |

### 4.6 多窗口策略

- 每 `ContentView` 窗口独立 `DirectoryContentSearchSession`
- 快捷键 `⌘⇧F` 仅作用于 key window
- 搜索任务绑定 `windowID`，窗口关闭时 `cancel()`

---

## 五、UI 实现要点

### 5.1 结果行样式

- 行高：28pt（对齐 Command Palette 行高）
- 字体：snippet 用 `NSFont.monospacedSystemFont(ofSize: 12)` 或 `.system(.body, design: .monospaced)`
- 高亮：黄底 `systemYellow` alpha 0.35/0.45（dark/light），当前匹配行额外 accent 行背景
- 文件 header 高：32pt；图标 16pt

### 5.2 滚动与可见性

- `selectedMatchID` 变化时 `ScrollViewReader.scrollTo`
- 展开分组时若选中匹配在折叠组内，自动展开

### 5.3 焦点

- 进入内容搜索结果视图时，结果列表获得焦点（`@FocusState` 或 `NSViewRepresentable`）
- 顶栏搜索框聚焦时，`↑↓` 不作用于结果列表

---

## 六、国际化（i18n）

### 6.1 新增键

| 键 | en | zh-Hans |
|----|-----|---------|
| `search.mode.filename` | Filename | 文件名 |
| `search.mode.content` | Content | 内容 |
| `search.content_prompt` | Search in folder… | 在当前文件夹中搜索… |
| `search.content_no_results` | No matches found | 未找到匹配内容 |
| `search.content_searching` | Searching… | 搜索中… |
| `search.content_summary` | %lld files · %lld matches · %.1fs | %lld 个文件 · %lld 处匹配 · %.1fs |
| `search.content_progress` | Scanned %lld/%lld files · %lld matches | 已扫描 %lld/%lld 个文件 · %lld 处匹配 |
| `search.content_truncated` | More matches not shown. Narrow your search. | 还有更多匹配未显示，请缩小范围。 |
| `search.content_no_text_files` | No searchable text files in this folder | 当前文件夹没有可搜索的文本文件 |
| `search.filter.title` | Filter | 过滤 |
| `search.filter.include` | Include | 包含 |
| `search.filter.exclude` | Exclude | 排除 |
| `search.filter.subdirectories` | Include subfolders | 包含子文件夹 |
| `search.filter.case_sensitive` | Case sensitive | 区分大小写 |
| `search.filter.max_file_size` | Max file size | 最大文件大小 |
| `search.filter.max_matches` | Max matches | 最多显示 |
| `search.content_next_match` | Next match | 下一个匹配 |
| `search.content_find_in_folder` | Find in Folder | 在文件夹中查找 |
| `help.entry.content_search.name` | Find in folder | 在文件夹中查找 |

`L10n.Search` 命名空间扩展；`Tests/ExplorerTests/L10nTests.swift` 增加 `XCTAssertNotEqual`。

---

## 七、菜单与发现性

| 入口 | 说明 |
|------|------|
| 菜单「编辑 → 在文件夹中查找…」 | `⌘⇧F` |
| Command Palette | 新增 `find_in_folder` → 切内容模式并聚焦 |
| Help 速查表 | `content_search` 条目 |
| `AppShortcutRegistry` | 注册 `⌘⇧F` |

---

## 八、风险与对策

| 风险 | 对策 |
|------|------|
| `searchText` 与内容 query 语义冲突 | 字段分离；模式切换时 UI 明确 |
| Quick Search 抢键 | 内容搜索激活时禁用 Quick Search 字母拦截 |
| 大目录阻塞主线程 | 引擎放 `actor` + 后台读文件；主线程仅 batch 更新（每 50ms 或每 20 匹配） |
| 二进制文件误判为文本 | 扩展名白名单 + 读前 N 字节 NUL 检测 |
| 预览跳转行号不准 | 测试 CRLF/LF；加载完成后延迟一帧 scroll |
| 网络卷超时 | 可取消 + 进度；可选降低并发 |
| 与文件名过滤叠加混淆 | Phase 2 再做「文件名+内容」组合模式；首版仅内容模式 + glob |

---

## 九、验收标准（整体）

1. 内容模式下输入关键词，主区域切换为结果视图，按文件分组展示 snippet。
2. Glob 过滤生效：仅 `*.swift` 时只出现 swift 文件匹配。
3. `↑↓` `Enter` `⌘G` `Esc` 行为符合 §2.5。
4. 点击/Enter 匹配 → 预览打开并跳到对应行，搜索词高亮。
5. 切换目录取消搜索；文件名模式与现有一致。
6. 中英文界面无键名泄露；`swift test` 通过新增单测。

---

## 十、相关文档

| 文档 | 关系 |
|------|------|
| [directory-content-search-plan.md](./directory-content-search-plan.md) | 开发计划 |
| [file-list-quick-search-phased-plan.md](./file-list-quick-search-phased-plan.md) | Quick Search 互斥参考 |
| [command-palette-design.md](./command-palette-design.md) | 命令注册、⌘⇧P 分工 |
| [i18n-design.md](./i18n-design.md) | 文案流程 |
