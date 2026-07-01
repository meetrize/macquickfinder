# 操作录制 → Shell Snippet — 交互与架构设计

> 目标：在 Explorer 顶部工具栏提供 **操作录制** 能力——用户在本应用内执行文件操作时自动记录步骤，停止录制后将过程 **解析为 Shell 脚本**，并弹出 Snippets 新建弹窗供用户修改后保存。  
> 本文档基于 2026-07 代码库现状编写；开发计划见 [operation-recording-plan.md](./operation-recording-plan.md)。

---

## 一、可行性评估

### 1.1 结论：**可行，且与现有架构高度契合**

| 维度 | 评估 | 说明 |
|------|------|------|
| 技术路线 | ✅ 推荐 | 在应用层记录 **语义化操作事件**（非屏幕录制、非 FSEvents 反推），与 Snippets 变量体系天然对齐 |
| 现有基础设施 | ✅ 已具备 | `FileOperations` 集中文件 mutation；`SnippetEditorSheet` 可预填内容；`SnippetExpander` 已有 `%p`/`%d`/`%P` 等变量；工具栏支持新增 `ToolbarBuiltinID` |
| 用户价值 | ✅ 高 | 降低「把重复文件整理流程写成 Snippet」的门槛，与 Snippets 面板形成闭环 |
| 实现复杂度 | ⚠️ 中等 | 首版可覆盖 80% 常见场景；完整 1:1 还原 Finder 行为（废纸篓还原、清空废纸篓等）需分阶段 |
| 风险 | ⚠️ 可控 | 录制脚本 **不保证** 在任意目录重放；需在 UI 中明确「模板化 Snippet」定位，而非宏回放 |

**不推荐的做法**：

- **FSEvents / 文件系统监听**：无法区分「用户在本应用内的操作」与外部进程改动，也无法还原 copy/cut 语义。
- **屏幕/输入事件录制**：与 Snippet 变量模型无关，维护成本极高，且无法生成可读的 Shell。
- **事后从磁盘 diff 反推**：丢失选中项、剪贴板状态、用户意图（复制 vs 移动）。

**推荐做法**：在 `FileOperations` 及少量 ContentView 入口（新建文件/文件夹）的成功回调处，向 `OperationRecorder` 投递结构化事件；停止录制时由 `OperationShellTranslator` 合并、泛化并生成脚本。

### 1.2 与 Snippets 的关系

| 能力 | Snippets（现状） | 操作录制（本方案） |
|------|------------------|-------------------|
| 创建方式 | 用户手写脚本 | 从操作 **半自动生成** |
| 执行时机 | 用户手动触发 | 仅用于 **生成草稿** |
| 变量 | 手动插入 `%p` 等 | 翻译器 **自动泛化** 路径为变量 |
| 作用域 | 用户配置 | 根据录制期间选中模式 **建议默认值** |

录制功能是 Snippets 的 **创作助手**，不是新的执行引擎。

### 1.3 首版可录制 vs 延后

#### 首版（Phase 1）— 已实现 ✅

| 用户操作 | 录制事件 | Shell 近似 | 状态 |
|----------|----------|------------|------|
| 复制 → 粘贴 | `copy` + `paste(copy:)` | `cp -R` | ✅ |
| 剪切 → 粘贴 | `cut` + `paste(move:)` | `mv` | ✅ |
| 拖拽（同应用内） | `transferItems`（经 `moveItems`） | `cp` / `mv` | ✅ |
| 删除到废纸篓 | `trash` | `osascript` 移入 Trash | ✅ |
| 立即删除 | `deleteImmediately` | `rm` | ✅ |
| 重命名 | `rename` | `mv` | ✅ |
| 新建文件夹 | `createDirectory` | `mkdir -p` | ✅ |
| 新建文件 | `createFile` | `touch` 或 `: >` | ✅ |
| 压缩 | `compress` | 复用 `ArchiveCommandBuilder` | ✅ |
| 解压 | `extract` | 同上 | ✅ |

#### Phase 2 — 可选扩展

| 用户操作 | 难点 |
|----------|------|
| 用指定应用打开 | 需记录 bundle id / `open -a` |
| 侧边栏收藏夹拖放 | 目标路径为收藏路径，可录制但作用域偏窄 |
| 导航（进入文件夹） | 非文件 mutation；可生成注释 `# browse: …` 或 `%d` 说明 |
| 多窗口 / 多 Tab | 需明确录制作用域（见 §3.2） |

#### 首版明确不支持（或录制时跳过）

| 操作 | 原因 |
|------|------|
| 清空废纸篓 / 还原 | 走 Finder AppleScript，Shell 等价物不稳定 |
| 执行已有 Snippet | 避免递归与混合语义；录制期间执行 Snippet **不会**被记录（见设置 → Snippets → 操作录制说明） |
| 仅 UI 状态变更 | 排序、显示隐藏文件、切换列表/缩略图 — 非文件操作 |
| 预览面板内只读操作 | 刷新、复制清单等 |
| 失败或被用户取消的操作 | 只记录 **已成功** 的 mutation |
| 外部应用内操作 | 超出本应用范围 |

---

## 二、最佳交互设计（推荐）

### 2.1 设计原则

1. **默认可发现、轻量打扰**：工具栏一键开始/停止，录制中仅轻量指示，不阻断正常操作。
2. **生成的是 Snippet 草稿，不是宏**：强调用户必须审阅、命名、配置作用域后再保存。
3. **先审阅、再入库**：停止录制后先展示步骤与脚本预览，再进入 `SnippetEditorSheet`——避免不可撤销的误保存。
4. **与 Snippets 按钮相邻**：心智上「录制 → 生成 Snippet」形成邻接关系。

### 2.2 工具栏入口

在 `ToolbarBuiltinID` 新增 `recordOperations`（默认放在 `.snippets` 与 `.outputPanel` 之间，可通过现有工具栏自定义拖移）。

| 状态 | 图标建议 | Tooltip |
|------|----------|---------|
| 未录制 | `circle`（Lucide） | 「录制操作用于生成 Snippet」 |
| 录制中 | `circle` + 红色填充 / 脉冲 | 「正在录制 — 点击停止」 |

**交互**：单击 **切换** 录制状态（非按住）。再次单击 = 停止。

**快捷键**（Phase 2 可选）：⌃⌘R 切换录制；录制中 Esc 停止并进入审阅（需防与列表 Esc 冲突，首版可不做）。

### 2.3 录制中反馈

```
┌─ 工具栏 ─────────────────────────────────────────────────────┐
│  …  [Snippets] [● Record] [Output] …                          │  ← Record 为红色激活态
└───────────────────────────────────────────────────────────────┘
┌─ 录制指示条（主内容区顶部，高 28pt，可收起）──────────────────┐
│  🔴 正在录制操作 · 已记录 3 步          [停止并生成] [放弃]    │
└───────────────────────────────────────────────────────────────┘
```

| 元素 | 行为 |
|------|------|
| 指示条 | 录制开始时滑入；**不**拦截文件列表点击 |
| 步数 | 实时更新 `OperationRecorder.stepCount` |
| 停止并生成 | 等同点击工具栏停止 → 进入审阅 Sheet |
| 放弃 | 二次确认后丢弃缓冲区，不打开 Sheet |

**为何加指示条？** 仅工具栏变红不够明显；用户可能忘记正在录制。指示条可设置「不再显示」(@AppStorage)。

### 2.4 停止录制 → 审阅 → Snippet 编辑器

#### 2.4.1 零步数

Toast / 轻提示：「未记录到文件操作」，不弹 Sheet。

#### 2.4.2 有步骤 — `OperationRecordingReviewSheet`（新建）

```
┌─ 从录制生成 Snippet ─────────────────────────────────────────┐
│  已记录 4 步 · 录制于 14:32                                    │
│                                                                │
│  ☑ 1. 新建文件夹 backup                                        │
│  ☑ 2. 移动 2 个项目 → backup/                                  │
│  ☑ 3. 压缩 backup → backup.zip                                 │
│  ☐ 4. 删除 backup/                    ← 可取消勾选以排除     │
│                                                                │
│  [✓] 将路径泛化为 Snippet 变量 (%p %P %d)                      │
│                                                                │
│  预览脚本 ─────────────────────────────────────────────────    │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ mkdir -p backup                                          │ │
│  │ mv "$1" "$2" backup/        # 泛化后示例                 │ │
│  │ ditto -c -k --sequesterRsrc backup backup.zip            │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│              [取消]  [复制脚本]  [创建 Snippet…]               │
└────────────────────────────────────────────────────────────────┘
```

| 控件 | 说明 |
|------|------|
| 步骤列表 | 人类可读摘要；可勾选/取消单步 |
| 泛化开关 | 开：翻译器用 `%p`/`%P`/`%d`/`%f`；关：保留录制时的字面路径（便于一次性脚本） |
| 创建 Snippet | 打开 `SnippetEditorSheet`，预填 `content`、建议 `name` 与 `scope` |

#### 2.4.3 `SnippetEditorSheet` 预填规则

| 字段 | 预填策略 |
|------|----------|
| `name` | `录制 · 移动并压缩`（由步骤摘要拼接，用户可改） |
| `scriptType` | `.shell` |
| `scope` | 推断：若所有 mutation 都作用于「当前选中项」→ `global` 或 `singleSelection`；若涉及扩展名一致 → `fileExtensions` |
| `content` | 审阅 Sheet 最终脚本 |
| `interpreter` | 默认 zsh（与 `SnippetDefaults` 一致） |
| `useSystemTerminal` | `false`（与现有 Snippet 默认一致） |

**扩展 `SnippetEditorSheet`**：增加可选 `draft: SnippetRecordingDraft?` 参数，不改变现有新建/编辑流程。

### 2.5 录制作用域（推荐：单窗口）

| 策略 | 说明 |
|------|------|
| **推荐** | 每个 `ContentView` / Explorer 窗口 **独立** `OperationRecorder` 实例（或 recorder 带 `windowID`，只接受匹配来源事件） |
| 原因 | 多窗口同时打开时，全局录制会把两个窗口的操作混成一条脚本，难以泛化 |
| 窗口关闭 | 若正在录制，弹窗：停止并保存 / 放弃 / 取消关闭 |

### 2.6 边界与提示文案

| 场景 | UX |
|------|-----|
| 录制中包含不可翻译步骤 | 步骤标记 ⚠️，审阅 Sheet 脚注说明 |
| 路径含空格 / 特殊字符 | 翻译器统一 `ShellQuoting.singleQuote`（与 `SnippetExpander` 一致） |
| 粘贴时自动重命名 (`foo 2`) | 录制 **实际目标路径**；泛化模式下中间步骤可能需用户手动改 |
| 在废纸篓中操作 | 允许录制；建议 scope 为 `anytime` 并加注释 |
| 再次开始录制 | 清空缓冲区；若上次未保存，可选提示 |

---

## 三、架构设计

### 3.1 模块总览

```
┌─────────────────────────────────────────────────────────────────┐
│ ContentView / FileListView / SidebarView / ArchiveOperations    │
│         │ success callback                                      │
│         ▼                                                       │
│  OperationRecorder (@MainActor, per-window)                       │
│         │ [RecordedOperation]                                   │
│         ▼ stop + review                                         │
│  OperationShellTranslator                                       │
│         │ String (+ SnippetRecordingDraft metadata)             │
│         ▼                                                       │
│  OperationRecordingReviewSheet → SnippetEditorSheet → SnippetStore│
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 核心类型

建议新建目录 `Sources/Explorer/OperationRecording/`。

```swift
/// 单次已成功执行的可录制操作
enum RecordedOperation: Equatable {
    case copy(sources: [URL])
    case cut(sources: [URL])
    case paste(sources: [URL], destination: URL, mode: PasteMode) // .copy | .move
    case move(sources: [URL], destination: URL)
    case copyItems(sources: [URL], destination: URL)
    case trash(urls: [URL])
    case deleteImmediately(urls: [URL])
    case rename(source: URL, destination: URL)
    case createDirectory(url: URL)
    case createFile(url: URL)
    case compress(sources: [URL], archive: URL, command: String) // 存 builder 产物
    case extract(archive: URL, destination: URL, command: String)
    case openWith(appPath: String, items: [URL]) // Phase 2
}

enum PasteMode: String, Codable { case copy, move }

struct RecordedOperationStep: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let operation: RecordedOperation
    var isIncluded: Bool // 审阅 Sheet 勾选
}

struct SnippetRecordingDraft {
    var suggestedName: String
    var suggestedScope: SnippetScope
    var script: String
    var steps: [RecordedOperationStep]
}
```

```swift
@MainActor
final class OperationRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var steps: [RecordedOperationStep] = []
    var windowID: UUID

    func start()
    func stop() -> [RecordedOperationStep]
    func discard()
    func append(_ operation: RecordedOperation) // no-op when !isRecording
}
```

### 3.3 埋点位置（与现有代码对齐）

| 位置 | 事件 |
|------|------|
| `FileOperations.copy` / `cut` | `copy` / `cut`（记录源 URL；paste 时合并） |
| `FileOperations.paste` 成功 | `paste` |
| `FileOperations.moveItems` 成功 | `move` / `copyItems` |
| `FileOperations.trashItems` / `delete` | `trash` |
| `FileOperations.deleteImmediately` | `deleteImmediately` |
| `FileOperations.moveItem`（重命名） | `rename` |
| `ContentView.createNewFolder` / `createNewFile` 成功 | `createDirectory` / `createFile` |
| `ArchiveOperations` 成功回调 | `compress` / `extract`（携带 `ArchiveCommandBuilder` 命令） |
| `SidebarView` / `FavoritesSidebarDropHandler` 拖放 | 同 `moveItems` |

**实现方式（推荐）**：

```swift
enum OperationRecordingHub {
    @MainActor static weak var activeRecorder: OperationRecorder?
    @MainActor static func record(_ operation: RecordedOperation) {
        activeRecorder?.append(operation)
    }
}
```

在 `FileOperations` 各方法 **成功分支** 末尾调用 `OperationRecordingHub.record(...)`，避免失败/取消污染。

**Copy/Cut + Paste 合并**：翻译阶段检测 `copy`/`cut` 后紧跟 `paste`，输出单条 `cp`/`mv` 而非两条事件（见 §3.4）。

### 3.4 `OperationShellTranslator`

职责：

1. 过滤 `isIncluded == false` 的步骤  
2. 合并 copy/cut + paste  
3. 可选 **路径泛化**（`TranslationOptions.generalizePaths`）  
4. 输出 Shell 字符串 + 元数据

#### 泛化规则（Phase 1）

| 模式 | 替换 |
|------|------|
| 录制开始时 cwd | 注释 `# cwd: …`；命令中 cwd 路径 → `%d` |
| 某步操作前的单选路径（多次出现） | → `%p` 或 `%q` |
| 某步操作前的多选路径 | → `%P` 或 `%Q` |
| 仅文件的单选 | → `%f` |
| 跨目录移动且文件名不变 | → `'{目标目录}/%n'` |
| 仅改扩展名 | → `'{目录}/%b.{新扩展名}'` |
| 用户新建的名称（固定字符串） | 保留字面量（如 `backup`、`Archive.zip`） |

**注意**：泛化是 **启发式**，审阅 Sheet 必须让用户预览。无法安全泛化时保留字面路径并加 `# TODO: 替换为变量`。

#### 命令映射示例

| RecordedOperation | Shell（字面路径模式） |
|-------------------|----------------------|
| paste(copy) | `/bin/cp -R 'src' 'dst/'` |
| paste(move) | `/bin/mv 'src' 'dst/'` |
| rename | `/bin/mv 'old' 'new'` |
| createDirectory | `/bin/mkdir -p 'path'` |
| createFile | `/usr/bin/touch 'path'` |
| trash | 见下 |
| compress/extract | 直接使用录制的 `command` 字段 |

**废纸篓**：macOS 无稳定内置 `trash` 命令。首版推荐：

```bash
# 移入废纸篓（需 Finder 语义）
/usr/bin/osascript -e 'tell application "Finder" to delete POSIX file "/path/to/item"'
```

或在 Snippet 中加注释，建议用户改用 `%p` + 自行选择 `rm` / `osascript`。

### 3.5 UI 集成点

| 组件 | 变更 |
|------|------|
| `ToolbarBuiltinID` | 新增 `recordOperations` |
| `ExplorerToolbarItemViews` | 录制按钮 + 激活态样式 |
| `ExplorerToolbarEnvironment` | 可选：`toggleOperationRecording` |
| `ContentView` | 持有 `OperationRecorder`；挂载 Review Sheet；工具栏环境注入 |
| `SnippetEditorSheet` | 可选 `draft: SnippetRecordingDraft?` 预填 |
| `Localizable.xcstrings` + `L10n` | 录制相关文案（中英） |

### 3.6 持久化

| 数据 | 策略 |
|------|------|
| 录制缓冲区 | **仅内存**；停止或放弃后清空 |
| 用户偏好 | `@AppStorage`：`showRecordingBanner`、`recordingGeneralizePathsDefault` |
| Snippet | 现有 `SnippetStore` |

不持久化未完成录制，避免崩溃后恢复导致路径失效。

### 3.7 测试策略

| 层级 | 内容 |
|------|------|
| 单元测试 | `OperationShellTranslatorTests`：copy+paste→cp、cut+paste→mv、rename→mv、泛化规则 |
| 单元测试 | `OperationRecorderTests`：start/stop/discard、未录制时不 append |
| UI 测试 | 可选；首版以单元测试为主 |

---

## 四、非目标与限制（需在 UI 中向用户说明）

1. **不是 Automator / 宏回放**：录制脚本依赖 Snippet 作用域与变量，在其它目录需重新选中文件再执行。  
2. **不保证与 Finder 100% 等价**：尤其废纸篓、权限、网络卷、同名冲突处理。  
3. **不录制键盘快捷键本身**：只录制最终生效的文件 mutation（例如用户按 ⌘C 再 ⌘V，录制为 copy+paste 合并结果）。  
4. **不包含 Snippet 执行输出**：若用户录制期间运行了 Snippet，该执行不计入（可在 Phase 2 加设置「同时录制 Snippet 命令文本」仅供高级用户）。  

---

## 五、与现有文档的关系

| 文档 | 关系 |
|------|------|
| [snippets-panel-design.md](./snippets-panel-design.md) | Snippet 模型、变量、编辑器 — 录制产出物直接进入此体系 |
| [toolbar-customization-design.md](./toolbar-customization-design.md) | 新增 `recordOperations` 内置项，纳入自定义工具栏 |
| [archive-compress-extract-design.md](./archive-compress-extract-design.md) | 压缩/解压命令复用 `ArchiveCommandBuilder` |

---

## 六、总结

| 问题 | 答案 |
|------|------|
| 想法是否可行？ | **可行**；应用内文件操作已集中，且 Snippets 基础设施完备 |
| 最佳交互？ | 工具栏 toggle + 轻量指示条 + **审阅 Sheet** + 预填 Snippet 编辑器 |
| 核心架构？ | 语义事件录制 → Shell 翻译（可泛化）→ Snippet 草稿 |
| 最大风险？ | 用户误以为「录制的脚本能原样重放」— 需文案与泛化审阅环节 |

下一步见 [operation-recording-plan.md](./operation-recording-plan.md)。
