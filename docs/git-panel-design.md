# Git 面板 — 设计方案与实施计划

> 目标：在文件管理器中提供 **轻量、工作流驱动** 的 Git 集成——聚焦 **状态查看、提交、拉取/推送同步**；不做 VS Code 式分支图、内嵌 diff、hunk 级暂存。  
> 实现方式：**仅调用系统 `git` CLI**（不引入 libgit2）；命令输出复用 **输出面板 + JobStore**。  
> AI 生成提交说明预留接口，首版用 **规则型默认文案**。  
> 本文档为 Git 面板的**自包含设计**，基于 2026-07-03 代码库（`RightPanelStackView`、`JobStore`、`PathBarView` 等）。

---

## 一、背景与目标

### 1.1 现状

| 区域 | 现状 |
|------|------|
| 右侧面板 | `RightPanelStackView`：预览（上）+ Snippets（下），各自折叠/关闭，中间可拖拽调比 |
| 路径栏 | 面包屑 + 历史，无 Git 状态 |
| 脚本执行 | `JobStore` + `ShellRunner` + 底部 `OutputPanelView`，已可跑 `git status` 等 |
| Git 集成 | **无**；`Package.swift` 零外部依赖 |

### 1.2 产品定位（与 IDE 刻意错开）

| 维度 | VS Code / IDE | MeoFind Git 面板 |
|------|---------------|------------------|
| 隐喻 | 源代码管理工程 | **文件夹同步与发版** |
| 默认操作单位 | 单文件 stage/unstage | **全部变更** 或 **主列表选区** |
| 分支 | 切换器 + 图 | **只读显示**分支名；切换放 `⋯` 菜单 |
| Diff | 内嵌编辑器 | **不做**；点文件 → 主列表选中 + 现有预览 |
| 状态刷新 | 常驻 watcher | **面板打开时**刷新 + 手动 ⟳ + 路径栏摘要 |

### 1.3 目标（首版 MVP）

1. **右侧栈第三段**：预览 / Snippets / **Git** 纵向排列；Git 可独立折叠/关闭。
2. **路径栏 Git Chip**：仓库内显示 `分支名 · N 变更`；点击聚焦 Git 面板。
3. **状态卡 + 主 CTA**：四种工作区形态（已同步 / 有变更 / 领先远程 / 落后或冲突），主按钮 **「提交并同步」** 覆盖 add → commit → pull --rebase → push 链路。
4. **选区联动**：主列表多选时，可仅提交选中且确有变更的文件。
5. **CLI 执行**：所有 `git` 操作经 `GitService`，输出写入 Job；失败时面板一行摘要 + 输出面板全文。
6. **规则型提交说明**：说明为空时自动生成（统计 / 目录聚类 / 模仿近期 log 前缀）；提交框旁预留 ✨（AI，后续启用）。

### 1.4 非目标（首版）

- libgit2 / SwiftGit2 等原生绑定
- 内嵌 diff、blame、merge 三路对比 UI
- 分支图、tag 管理、submodule、rebase 交互向导
- 列表/缩略图图标角标（TortoiseGit 式 overlay）
- AI 生成提交说明（仅预留按钮与 `GitCommitMessageGenerator` 协议）
- 自动 stash / 自动解决冲突
- 多仓库 monorepo 工作区 UI（仅以 **当前目录向上解析的单个 `.git` 根** 为准）

---

## 二、总体布局

### 2.1 主窗口结构（Git 加入后）

```
┌──────────┬──────────────────────────────────────┬─────────────────┐
│  左侧面板 │  工具栏（路径栏 + Git Chip / 搜索）    │   右侧面板       │
│          │──────────────────────────────────────│ ┌─────────────┐ │
│          │                                      │ │  预览        │ │
│          │         文件列表（主区域）              │ ├─────────────┤ │
│          │                                      │ │  Snippets   │ │
│          │                                      │ ├─────────────┤ │
│          │                                      │ │  Git        │ │
│          │                                      │ └─────────────┘ │
├──────────┴──────────────────────────────────────┴─────────────────┤
│  输出面板 — Git 命令 Job 流式输出                                    │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 右侧栈三段式

在 `RightPanelStackView` 底部追加 `GitPanelView`：

```swift
VStack(spacing: 0) {
    if layout.showPreview { FilePreviewView(...).frame(height: previewHeight) }
    if showPreviewSnippetsDivider { VerticalResizeDivider(...) }  // 预览 ↔ 中下区
    if layout.showSnippets { SnippetsPanelView(...).frame(height: snippetsHeight) }
    if showSnippetsGitDivider { VerticalResizeDivider(...) }     // Snippets ↔ Git
    if layout.showGit { GitPanelView(...).frame(height: gitHeight) }
}
```

**高度策略（首版，避免重写全部比例逻辑）**：

| 区块 | 规则 |
|------|------|
| 预览 | 沿用 `RightPanelHeightCalculator`（相对「预览 + Snippets 可见部分」） |
| Snippets | 占「中下区」剩余（`maxHeight: .infinity`），与现行为一致 |
| Git | **固定默认高度** `gitPanelHeight`（默认 200pt，最小 120，最大 360），可拖拽分隔条；**折叠时**仅 `PanelTopBarMetrics.totalHeight` |

当 `showGit == false` 或 Git 内容折叠时，行为与当前双面板一致。

| 状态键 | 持久化键（`AppPreferences.Layout`） | 默认 |
|--------|-------------------------------------|------|
| `showGit` | `showGit` | `false` |
| `gitPanelHeight` | `gitPanelHeight` | `200` |
| `isGitContentCollapsed` | `Panels.gitContentCollapsed` | `false` |

### 2.3 路径栏 Git Chip

位于 `PathBarView` 面包屑行右侧（历史按钮左侧），**仅当 `GitRepositoryDetector` 解析到仓库根时显示**：

```
…/macquickfinder   │  main · 3●
```

| 元素 | 说明 |
|------|------|
| `main` | `git branch --show-current` |
| `3●` | 工作区变更文件数（不含已 commit 未 push）；0 变更时仅显示分支名 |
| 领先/落后 | 可选后缀：`↑2` / `↓5`（`git rev-list --left-right --count @{u}...HEAD`） |
| 点击 | `showGit = true`，刷新状态，滚动聚焦 Git 面板 |

Chip 数据来自 **轻量缓存**（与面板共用 `GitStatusStore`），面板关闭时仍可按节流刷新（见 §5.4）。

### 2.4 Git 面板线框（展开态）

```
┌─ Git ─────────────────────── ⟳  ⌄  ✕ ─┐
│  main  ·  本地领先 1  ·  3 变更          │  ← 状态条（只读）
├────────────────────────────────────────┤
│  ● 3 个文件待提交                       │  ← 状态卡标题
│    M  PreviewTextWrapLayout.swift       │
│    M  TextFilePreview.swift             │
│    A  docs/git-panel-design.md          │
│    还有 0 个…                           │
├────────────────────────────────────────┤
│  将提交全部变更 / 将提交选中的 2 个文件    │  ← 选区提示（动态）
│  ┌ 更新 Explorer 预览相关（3 文件） ─┐   │
│  └                          ✨ ────┘   │  ← ✨ disabled，tooltip 预留
│                                        │
│      [ 提交并同步 ]                     │  ← 主 CTA（`.borderedProminent`）
│   拉取更新              仅提交           │  ← 次要 `.plain` 文字按钮
└────────────────────────────────────────┘
```

顶栏交互与 `SnippetsPanelView` 一致：折叠 chevron、`⟳` 刷新、`✕` 关闭面板。

### 2.5 系统菜单与快捷键

在 `ExplorerApp.commands` 的 `CommandGroup(after: .sidebar)` 扩展：

| 菜单项 | 快捷键 | 行为 |
|--------|--------|------|
| 显示/关闭 Git 面板 | `Cmd+Shift+G` | `layout.showGit.toggle()` |
| 刷新 Git 状态 | `Cmd+Shift+R`（Git 面板聚焦时） | `GitStatusStore.refresh()` |
| 提交并同步 | `Cmd+Return`（Git 面板聚焦且非编辑提交说明时） | 主 CTA |

> `Cmd+Shift+S` 已被 Snippets 占用；Git 使用 `G`。

---

## 三、工作区状态机

### 3.1 四种状态卡形态

由 `GitWorkspaceSnapshot` 推导，**互斥主形态**（冲突优先）：

| 形态 | 枚举 | 判定条件（简化） | 主 CTA 文案 | 主 CTA 行为 |
|------|------|------------------|-------------|-------------|
| 已同步 | `cleanSynced` | 无 porcelain 变更 && 与 `@{u}` 无 ahead | **同步** | `pull` → 若 ahead 则 `push` |
| 有本地变更 | `dirty` | porcelain 非空 | **提交并同步** | §4.3 完整链路 |
| 领先远程 | `aheadOnly` | 无 porcelain && ahead > 0 | **推送到远程** | `push` |
| 落后/冲突 | `behindOrConflict` | behind > 0 或 merge 冲突标记 | **拉取更新** / **需解决冲突** | `pull --rebase`；冲突时禁用主 CTA |

面板中部 **状态卡** 展示对应标题、颜色（绿/黄/橙/红）与变更短列表。

### 3.2 变更短列表

| 规则 | 值 |
|------|-----|
| 最大行数 | 8 |
| 超出 | `还有 N 个…` 可点击展开全部 |
| 行内容 | 色点（M/A/D/R/?）+ 相对仓库根的 basename 或短路径 |
| 点击行 | 通知 `ContentView` 选中并滚动到主列表对应 `FileItem` |
| 右键 | 「在预览中打开」「在 Finder 中显示」 |

**不做** staged / unstaged 分区；首版合并为 **「待提交」** 单一列表（porcelain 全部视为将纳入本次提交）。

### 3.3 非 Git 目录

`GitPanelView` 显示空状态：

- 文案：「当前目录不在 Git 仓库中」
- 按钮：**初始化仓库** → `git init`（Job 输出）；**在终端打开**（已有能力）

路径栏 Chip 隐藏。

---

## 四、Git 服务层（CLI）

### 4.1 模块划分

```
Sources/Explorer/Git/
├── GitRepositoryDetector.swift      // 自 cwd 向上找 .git
├── GitCLI.swift                     // Process 封装、超时、编码
├── GitStatusStore.swift             // @MainActor 可观察状态 + 刷新节流
├── GitWorkspaceSnapshot.swift       // 解析后的领域模型
├── GitService.swift                 // 高层：refresh / commit / sync / pull / push
├── GitCommitMessageGenerator.swift  // 规则型；协议预留 AI 实现
├── GitJobRunner.swift               // 对接 JobStore
└── Views/
    ├── GitPanelView.swift
    ├── GitPathBarChip.swift
    └── GitChangeRowView.swift
```

### 4.2 刷新用 CLI（只读，可合并为一次 shell 脚本减少启动开销）

| 目的 | 命令 |
|------|------|
| 仓库根 | `git rev-parse --show-toplevel` |
| 分支 | `git branch --show-current` |
| 变更列表 | `git status --porcelain=v1 -z` |
|  ahead/behind | `git rev-list --left-right --count HEAD...@{u}`（无 upstream 时降级） |
| 冲突 | porcelain `UU` / `AA` 等 + `git diff --name-only --diff-filter=U` |

刷新在 **后台 `Task.detached`** 执行，`GitStatusStore` 主线程发布结果。

### 4.3 「提交并同步」链路

用户点击主 CTA 或 `Cmd+Return`：

```
1. 若 working tree 有变更：
   a. 确定 add 范围：全部 OR 选区过滤（§4.4）
   b. git add <paths> 或 git add -A
   c. 若提交说明为空 → GitCommitMessageGenerator.generate(...)
   d. git commit -m "<message>"
2. git pull --rebase
   - 失败：停止，状态卡 → behindOrConflict，输出面板展示 stderr
3. git push
   - 失败：停止，展示认证/权限错误
4. refresh()
```

**安全闸**：

| 场景 | 行为 |
|------|------|
| 有未提交变更时点「拉取更新」 | 按钮 **禁用**，提示「请先提交或暂存变更」 |
| `git commit` 将提交 > 50 个文件（可配置） | 确认 Alert |
| `commit -m` 为空且生成失败 | 聚焦提交框，不执行 |
| 存在冲突文件 | 主 CTA 禁用，列出冲突路径 |

### 4.4 选区联动

```swift
struct GitCommitScope: Equatable {
    case allChanges           // 默认
    case selectedPaths([String])  // 主列表选中的、且出现在 porcelain 中的路径
}
```

设置项 `AppPreferences.Git.commitSelectionOnly`（默认 `false`）：

- `false`：有选区时 UI 提示「将提交全部变更」，仍 `git add -A`
- `true`：有选区时 `git add -- <paths>`；无选区等同全部

### 4.5 规则型提交说明（`GitCommitMessageGenerator`）

```swift
protocol GitCommitMessageGenerating {
    func generate(
        repoRoot: String,
        stagedPaths: [String],
        porcelainLines: [GitPorcelainEntry]
    ) async throws -> String
}
```

**首版 `RuleBasedGitCommitMessageGenerator` 优先级**：

1. `git diff --stat`（或 `--cached --stat`）→ `更新 3 个文件（+42 −18）`
2. 变更路径聚合：若 ≥60% 在同一目录 → `更新 Explorer/Preview 下 2 个文件`
3. `git log -5 --format=%s` 检测常见前缀（`fix:`/`feat:`/`chore:`）并沿用

**预留**：`AIGitCommitMessageGenerator` 实现同一协议，由设置或 ✨ 按钮切换。

### 4.6 JobStore 集成

扩展 `JobSource`：

```swift
enum JobSource: Equatable {
    // ... 现有 case
    case gitOperation(label: String)  // 如 "Git: 提交并同步"
}
```

`GitJobRunner`：

- `createJob(displayCommand: "git pull --rebase", workingDirectory: repoRoot)`
- 复用 `ShellRunner` 或专用 `GitCLI.run(...)` 捕获 stdout/stderr
- 默认 **自动展开输出面板**（复用 `SnippetsSettings.autoShowOutputPanelOnShellRun` 或新增 `GitSettings.autoShowOutputOnOperation`）

---

## 五、刷新与性能

### 5.1 何时刷新

| 触发 | 行为 |
|------|------|
| Git 面板 `onAppear` | 立即 refresh |
| 用户点击 ⟳ | 立即 refresh |
| 路径变化且新路径在仓库内 | debounce 500ms refresh |
| Git 操作 Job 成功结束 | refresh |
| FSEvents（可选 Phase C） | 仅当 `showGit` 或 Chip 可见时 debounce 1s |

### 5.2 何时不刷新

- 非 Git 目录
- Git 面板关闭 **且** 路径栏 Chip 未显示（非仓库） 
- 已有 refresh `Task` 进行中（合并请求）

### 5.3 面板关闭时的 Chip

仓库内浏览时，Chip 仍需低频更新（每 30s 或路径/FSEvents 触发），但 **不** 跑完整 porcelain 以外的重型命令；ahead/behind 可每 60s 更新。

### 5.4 资源预算

- 单次 refresh：1–3 个短生命周期 `git` 进程，无常驻内存
- 不 watch `.git/index` 独立线程（首版）
- 变更列表仅保留字符串数组，不加载 diff 内容

---

## 六、数据模型（摘要）

```swift
struct GitPorcelainEntry: Equatable, Identifiable {
    var id: String { path }
    var status: GitPathStatus  // modified, added, deleted, renamed, untracked, conflict
    var path: String           // 仓库内相对路径
}

struct GitWorkspaceSnapshot: Equatable {
    var repoRoot: String
    var currentBranch: String?
    var entries: [GitPorcelainEntry]
    var aheadCount: Int
    var behindCount: Int
    var hasUpstream: Bool
    var conflictedPaths: [String]
    var lastRefreshedAt: Date?

    var changeCount: Int { entries.count }
    var workspacePhase: GitWorkspacePhase { ... }  // §3.1
}

enum GitPanelOperation: Equatable {
    case idle
    case running(GitPanelOperationKind)
    case succeeded(Date)
    case failed(String)
}

enum GitPanelOperationKind: String {
    case refresh, pull, commit, push, commitAndSync
}
```

---

## 七、与现有模块的衔接

| 模块 | 改动 |
|------|------|
| `RightPanelStackView` | 追加 `GitPanelView`、Snippets–Git 分隔条 |
| `RightPanelHeightCalculator` | 增加 `showGit` / `gitPanelHeight` / `isGitContentCollapsed` 输入 |
| `ExplorerWindowLayoutState` | `showGit`、`gitPanelHeight`、`isGitContentCollapsed` |
| `AppPreferences` | `Layout.showGit`、`Layout.gitPanelHeight`、`Panels.gitContentCollapsed`、`Git.commitSelectionOnly` 等 |
| `PathBarView` | 嵌入 `GitPathBarChip` |
| `ContentView` | 传入 `selection`/`items`/`path`；处理「定位到变更文件」 |
| `JobStore` / `JobModels` | `JobSource.gitOperation` |
| `ExplorerApp.commands` | Git 菜单项 |
| `ExplorerKeyboardShortcuts` | `toggleGit` |
| `Localizable.xcstrings` + `L10n.swift` | §九 |
| `Tests/ExplorerTests/` | `GitRepositoryDetectorTests`、`GitPorcelainParserTests`、`GitWorkspacePhaseTests`、`RuleBasedCommitMessageGeneratorTests` |

**不改** `FileList` 模块（无图标角标）。

---

## 八、设置项（首版）

| 键 | UI 位置 | 默认 | 说明 |
|----|---------|------|------|
| `git.commitSelectionOnly` | 设置 → 通用 或 Git 小节 | `false` | 仅提交选中文件 |
| `git.autoShowOutputOnOperation` | 同上 | `true` | Git 操作时弹出输出面板 |
| `git.largeCommitConfirmationThreshold` | 同上 | `50` | 超过 N 文件需确认 |
| `git.pullRebase` | 同上 | `true` | 同步时 `pull --rebase`（false 则 `pull`） |

Git 专属设置 Tab **首版可不建**，4 项放入「通用」底部折叠区即可。

---

## 九、i18n 键（须在 `Localizable.xcstrings` 注册）

| 键 | 中文 | English |
|----|------|---------|
| `git.panel.title` | Git | Git |
| `git.panel.close` | 关闭 Git 面板 | Close Git Panel |
| `git.panel.refresh` | 刷新状态 | Refresh Status |
| `git.panel.collapse` / `expand` | 折叠 / 展开 | Collapse / Expand |
| `git.status.clean` | 工作区干净，已与远程同步 | Working tree clean and synced |
| `git.status.dirty` | %lld 个文件待提交 | %lld files to commit |
| `git.status.ahead` | 本地领先远程 %lld 个提交 | %lld commits ahead of remote |
| `git.status.behind` | 远程领先本地 %lld 个提交 | %lld commits behind remote |
| `git.status.conflict` | 存在合并冲突 | Merge conflicts detected |
| `git.action.commitAndSync` | 提交并同步 | Commit & Sync |
| `git.action.sync` | 同步 | Sync |
| `git.action.pull` | 拉取更新 | Pull |
| `git.action.commitOnly` | 仅提交 | Commit Only |
| `git.action.push` | 推送到远程 | Push |
| `git.commit.placeholder` | 提交说明 | Commit message |
| `git.commit.generateAI` | 使用 AI 生成说明（即将推出） | Generate message with AI (coming soon) |
| `git.scope.allChanges` | 将提交全部变更 | All changes will be committed |
| `git.scope.selected` | 将提交选中的 %lld 个文件 | Commit %lld selected files |
| `git.empty.notRepo` | 当前目录不在 Git 仓库中 | Not a Git repository |
| `git.empty.init` | 初始化仓库 | Initialize Repository |
| `git.chip.ahead` | ↑%lld | ↑%lld |
| `git.chip.behind` | ↓%lld | ↓%lld |
| `git.error.pullWithDirty` | 存在未提交变更，请先提交 | Commit or stash changes before pulling |
| `git.confirm.largeCommit.title` | 将提交大量文件 | Commit many files? |

在 `L10n.Git` 下暴露；`L10nTests` 增加 `XCTAssertNotEqual` 抽检。

---

## 十、后续迭代（非 MVP）

| 迭代 | 内容 |
|------|------|
| **v1.1** | ✨ AI 提交说明（接 `ai-assistant-design.md`） |
| **v1.1** | `⋯` 菜单：切换分支、最近 10 条 log、放弃变更 |
| **v1.2** | 列表名称列 Git 色点（可选设置） |
| **v1.2** | FSEvents 驱动增量 refresh |
| **v2** | 外部 diff 工具调用（`git difftool`） |
| **v2** | 多窗口间 Git 状态隔离（每窗口 `cwd` 独立 `GitStatusStore` 实例） |

---

## 十一、分阶段实施计划

### 总览

| 阶段 | 范围 | 估时 | 可交付 |
|------|------|------|--------|
| **Phase A** | Git 服务层 + 状态解析 + 单元测试 | 2–3 天 | 无 UI，可 CLI 验证 |
| **Phase B** | 布局状态 + 右侧 Git 面板壳 + 菜单/快捷键 | 2–3 天 | 空面板可开关 |
| **Phase C** | 状态卡 UI + 刷新 + 路径栏 Chip | 2–3 天 | 只读状态完整 |
| **Phase D** | 提交/拉取/推送 + Job 集成 + 主 CTA 链路 | 3–4 天 | **MVP 闭环** |
| **Phase E** | 选区联动 + 规则提交说明 + 设置项 + i18n 测试 | 2 天 | 体验打磨 |
| **Phase F** | 验收、边界（无 upstream、detached HEAD、大仓库） | 1–2 天 | 可发布 |

**合计约 12–17 人天**（单人顺序开发）；Phase A 与 B 可部分并行（模型稳定后 UI 壳先行）。

---

### Phase A — Git 服务层（无 UI）

**目标**：`GitStatusStore` 能对任意 `cwd` 产出 `GitWorkspaceSnapshot`。

| # | 任务 | 产出 |
|---|------|------|
| A1 | `GitRepositoryDetector`：`findRepoRoot(from:)` 向上遍历 | `GitRepositoryDetector.swift` |
| A2 | `GitCLI`：`run(args:cwd:)` → `Result<String, GitCLIError>`，UTF-8，超时 60s | `GitCLI.swift` |
| A3 | `GitPorcelainParser`：解析 `-z` porcelain | 纯函数 + 测试 |
| A4 | `GitWorkspaceSnapshot` + `GitWorkspacePhase` 推导 | `GitWorkspaceSnapshot.swift` |
| A5 | `GitStatusStore`：`refresh(cwd:)` async，debounce | `GitStatusStore.swift` |
| A6 | 单元测试：parser、phase 判定、detector（fixture 目录） | `Git*Tests.swift` |

**验收**：在 `~/pro/macquickfinder` 跑单元测试；手动 `refresh` 打印 snapshot 正确。

---

### Phase B — 布局与面板壳

**目标**：右侧出现可折叠 Git 面板，尚未接真实数据。

| # | 任务 | 产出 |
|---|------|------|
| B1 | `AppPreferences` + `ExplorerWindowLayoutState` 增加 `showGit`、`gitPanelHeight`、`isGitContentCollapsed` | 偏好持久化 |
| B2 | 扩展 `RightPanelHeightCalculator` 支持 Git 固定高度段 | 计算器 + 测试更新 |
| B3 | `RightPanelStackView` 挂载 `GitPanelView`（顶栏 + 占位内容） | 视图 |
| B4 | `ContentView` 传入 `path`/`selection`/`items`/`onRevealPath` | 接线 |
| B5 | `ExplorerApp.commands` + `ExplorerKeyboardShortcuts.toggleGit` | `Cmd+Shift+G` |
| B6 | `RightPanel` 显示条件：`showPreview \|\| showSnippets \|\| showGit` | `ContentView` |

**验收**：开关 Git 面板，拖拽 Git 高度，折叠/关闭不影响预览与 Snippets。

---

### Phase C — 只读状态 UI

**目标**：状态卡、变更列表、Chip 只读展示。

| # | 任务 | 产出 |
|---|------|------|
| C1 | `GitPanelView` 顶栏 + 状态条 + 四种状态卡 | UI |
| C2 | `GitChangeRowView` + 点击跳转主列表 | 与 `ContentView` 回调 |
| C3 | `GitPathBarChip` 嵌入 `PathBarView` | Chip |
| C4 | 面板 `onAppear` / ⟳ / 路径变化 → `GitStatusStore.refresh` | 刷新接线 |
| C5 | 非仓库空状态 | UI |
| C6 | i18n：Phase C 涉及键写入 `xcstrings` + `L10n.Git` | 本地化 |

**验收**：浏览仓库目录，Chip 与面板数字一致；点击变更文件主列表选中。

---

### Phase D — 写操作与主 CTA（MVP 核心）

**目标**：「提交并同步」端到端可用。

| # | 任务 | 产出 |
|---|------|------|
| D1 | `JobSource.gitOperation` + `GitJobRunner` | Job 集成 |
| D2 | `GitService.pull` / `commit` / `push` / `commitAndSync` | 服务方法 |
| D3 | 主 CTA 状态机：按 `GitWorkspacePhase` 切换文案与 action | 面板逻辑 |
| D4 | 次要按钮：拉取更新、仅提交 | UI |
| D5 | 错误处理：失败摘要、`autoShowOutput` | 与输出面板联动 |
| D6 | 大提交确认、dirty 时禁用拉取 | 安全闸 |
| D7 | `git init` 空状态按钮 | 初始化 |

**验收**：在测试仓库修改文件 → 提交并同步 → 远程可见；冲突/无 upstream 有明确提示。

---

### Phase E — 体验打磨

| # | 任务 | 产出 |
|---|------|------|
| E1 | `GitCommitScope` + 选区过滤 + 设置项 | 选区联动 |
| E2 | `RuleBasedGitCommitMessageGenerator` | 自动说明 |
| E3 | 提交框 + ✨ 占位按钮 | UI |
| E4 | `Cmd+Return` 提交快捷键 | 键盘 |
| E5 | `L10nTests` 补齐；中英切换目测 | i18n |
| E6 | `GitSettings`（4 项）放入 `SettingsView` 折叠区 | 设置 |

**验收**：选区模式、空说明自动填充、设置生效。

---

### Phase F — 验收与边界

| # | 任务 |
|---|------|
| F1 | detached HEAD：仅显示分支名为 `(detached)`，不崩溃 |
| F2 | 无 `origin` / 无 upstream：隐藏 ahead/behind，push 给出提示 |
| F3 | 超大 `git status`（>2000 文件）：列表截断 + 性能目测 |
| F4 | 多窗口：各窗口 `cwd` 独立 store（`GitStatusStore` 按 `hostWindowID` 或实例挂 `ContentView`） |
| F5 | 走查 §十二验收清单 |

---

## 十二、验收清单

### 布局

- [ ] 预览 / Snippets / Git 三段可独立折叠与关闭
- [ ] Git 默认关闭；打开后高度可拖拽且持久化
- [ ] 三者都关闭时右侧列隐藏

### 状态

- [ ] 仓库内路径栏 Chip 显示分支与变更数
- [ ] 非仓库无 Chip，面板空状态正确
- [ ] 四种状态卡文案与主 CTA 匹配
- [ ] 变更列表点击可定位主列表

### 操作

- [ ] 「提交并同步」：add → commit → pull --rebase → push 成功
- [ ] 「仅提交」不 push
- [ ] 「拉取更新」在 dirty 时禁用
- [ ] 操作输出在 Job / 输出面板可查看
- [ ] 失败时面板显示一行错误摘要

### 设置与 i18n

- [ ] 仅提交选区、自动弹出输出、大提交阈值可配置
- [ ] 中英文界面无键名泄露

### 非功能

- [ ] Git 面板关闭后无周期性 git 进程（Chip 低频除外）
- [ ] 不修改 `FileList` 图标渲染

---

## 附录 A：Porcelain 状态 → UI 色点

| Porcelain | 含义 | 色点 |
|-----------|------|------|
| ` M` / `M` | 修改 | 橙色 |
| `A` / `??` | 新增/未跟踪 | 绿色 |
| `D` | 删除 | 红色 |
| `R` | 重命名 | 蓝色 |
| `U` / `AA` / `DD` | 冲突 | 红色加粗 |

---

## 附录 B：`commitAndSync` 伪代码

```swift
func commitAndSync(scope: GitCommitScope, message: String) async throws {
    let root = snapshot.repoRoot
    if snapshot.changeCount > 0 {
        try await gitAdd(scope: scope, root: root)
        let msg = message.isEmpty ? try await messageGenerator.generate(...) : message
        try await gitJob.run(["commit", "-m", msg], cwd: root)
    }
    if snapshot.behindCount > 0 || snapshot.hasUpstream {
        try await gitJob.run(pullRebase ? ["pull", "--rebase"] : ["pull"], cwd: root)
    }
    if snapshot.aheadCount > 0 || snapshot.changeCount > 0 {
        try await gitJob.run(["push"], cwd: root)
    }
    await statusStore.refresh(cwd: root)
}
```

---

## 附录 C：文件清单（新建/修改）

**新建**

- `Sources/Explorer/Git/*.swift`（§4.1）
- `Tests/ExplorerTests/GitRepositoryDetectorTests.swift`
- `Tests/ExplorerTests/GitPorcelainParserTests.swift`
- `Tests/ExplorerTests/GitWorkspacePhaseTests.swift`
- `Tests/ExplorerTests/GitCommitMessageGeneratorTests.swift`

**修改**

- `Sources/Explorer/RightPanel/RightPanelStackView.swift`
- `Sources/Explorer/RightPanel/RightPanelHeightCalculator.swift`
- `Sources/Explorer/ExplorerWindowLayoutState.swift`
- `Sources/Explorer/Preferences/AppPreferences.swift`
- `Sources/Explorer/ContentView.swift`
- `Sources/Explorer/PathBarView.swift`
- `Sources/Explorer/AppModule.swift`
- `Sources/Explorer/ExplorerKeyboardShortcuts.swift`
- `Sources/Explorer/ScriptRuntime/JobModels.swift`
- `Sources/Explorer/Resources/Localizable.xcstrings`
- `Sources/Explorer/L10n.swift`
- `Tests/ExplorerTests/L10nTests.swift`
- `Tests/ExplorerTests/RightPanelHeightCalculatorTests.swift`

---

*文档版本：1.0 · 2026-07-03*

**Phase A 实施（2026-07-03）**：`Sources/Explorer/Git/` 服务层与 `ExplorerGitTests` 测试目标已落地。

**Phase B 实施（2026-07-03）**：`GitPanelView` 壳、`showGit` 布局状态、右侧栈三段、`Cmd+Shift+G` 菜单、高度计算器扩展。

**Phase C 实施（2026-07-03）**：状态卡、变更列表、路径栏 Git Chip、`GitStatusStore` 刷新联动、非仓库空状态。

```bash
swift build --target Explorer
swift test --filter 'GitRepositoryDetectorTests|GitPorcelainParserTests|GitWorkspacePhaseTests|GitWorkspaceReaderTests|GitStatusStoreTests|RightPanelHeightCalculatorGitTests|GitL10nTests|GitStatusPresentationTests'
```
