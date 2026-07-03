# 预览区文本编辑 — 方案 A 设计

> 目标：在右侧预览 / 独立预览窗口中，为**纯文本与代码类文件**提供**轻量就地编辑**能力（改几行配置、小脚本），而非 IDE 级编辑器。  
> 开发计划见 [preview-text-edit-plan.md](./preview-text-edit-plan.md)。  
> 前置：预览 Session、工具栏、独立窗口、胶片条浏览已落地（`PreviewSession`、`FileContentView`、`PreviewBrowserStrip`）。

---

## 一、现状

### 1.1 文本预览链路

```
选中文件
  → FileContentView.task(id: contentLoadTaskID)
  → PreviewSession.beginLoadTask
  → PreviewContentLoader.loadText
  → TextFilePreviewReader.readPreview（上限 20_000 字符，超出截断）
  → TextFilePreview（NSTextView，isEditable = false）
  → TextSyntaxHighlighter 异步全量高亮（>18k 字符 / >1200 行跳过高亮）
```

| 组件 | 职责 | 关键约束 |
|------|------|----------|
| `TextFilePreviewReader` | 读取文本 | `maxCharacters = 20_000`，超出追加 `[Content truncated...]` |
| `TextFilePreview` | 只读展示 | `PreviewCodeTextView`，支持选区、复制、搜索高亮 |
| `TextSyntaxHighlighter` | 语法着色 | 后台线程生成 `NSAttributedString`，主线程**整段替换** `textStorage` |
| `PreviewSessionTextState` | 工具栏状态 | 换行、搜索、Markdown/HTML 模式切换 |
| `TextEditingKeyMonitor` | 键盘转发 | 预览获焦时 ⌘A/C/V/X 转发给 `NSTextView` |

### 1.2 可借鉴的编辑模式

图片预览已实现完整「编辑 → 保存 → 覆盖确认 → 重载」闭环：

- `PreviewSessionImageState.hasEdits` / `editUndoStack`
- `PreviewSession.saveEditedImage()` — `NSAlert` 确认 + 后台写盘 + 失败 alert
- 工具栏「保存」按钮：`isDisabled: !image.hasEdits`

文本编辑应**复用同一产品模式**，但状态更简单（字符串 diff，无像素变换栈）。

### 1.3 核心矛盾

| 矛盾 | 说明 | 方案 A 决策 |
|------|------|-------------|
| 语法高亮 vs 编辑 | 高亮流程整段替换 `textStorage`，会破坏光标、Undo、IME | **编辑模式关闭高亮**，纯 monospace 文本 |
| 20k 预览上限 vs 编辑 | 预览截断后保存会**写坏文件** | 编辑模式**禁止进入**（或文件已截断时禁用编辑按钮并提示） |
| 搜索高亮 vs 编辑 | 搜索在 `textStorage` 上叠加背景色属性 | 编辑模式**禁用预览内搜索**（工具栏搜索项隐藏或 disabled） |
| 文件切换 vs 脏状态 | 胶片条 / 侧栏切换会 `resetControls` + 重载 | 切换前**拦截并询问**保存 |

---

## 二、设计目标与非目标

### 2.1 目标（方案 A）

1. **默认只读**：与现有一致，用户主动进入编辑模式。
2. **可保存**：⌘S 与工具栏「保存」，覆盖原文件前确认。
3. **可放弃**：「放弃修改」恢复磁盘内容。
4. **脏状态可见**：工具栏指示未保存；切换文件前拦截。
5. **范围可控**：仅 `TextFilePreview` 路径（纯文本 / 代码 / Markdown 源码 / HTML 源码）；不碰 Office 转换文本、压缩包列表。
6. **零新依赖**：继续 `NSTextView` + 现有 Session 架构。

### 2.2 非目标（方案 A 不做，留方案 B）

- 编辑时实时语法高亮
- 解除 20k 字符限制 / 大文件虚拟滚动
- 多编码选择（仅 UTF-8；失败则不可编辑并提示）
- 外部进程修改文件后的自动 reload 提示
- Markdown 渲染模式下的 WYSIWYG 编辑
- Git 脏文件角标联动
- 插件化 Editor Provider

---

## 三、适用范围

### 3.1 可编辑（`PreviewTextEditEligibility.canEdit(file:session:)`）

同时满足：

1. `PreviewTypeClassifier.isTextFile(ext)` 或自定义规则 mode == `.text`
2. 当前展示路径为 **`TextFilePreview`**（非 Markdown 渲染、非 HTML WebView、非 Office 富文本）
3. `content.textContent` 已加载成功，且**未截断**（不含 `[Content truncated...]` 后缀）
4. `content.loadPhase == .loaded`
5. 文件可写（`FileManager.isWritableFile`；只读卷 / 权限不足 → 禁用编辑）

### 3.2 不可编辑（明确排除）

| 场景 | 原因 |
|------|------|
| Markdown **预览**模式（`markdownMode == .preview`） | 渲染视图非文本 |
| HTML **预览**模式（`htmlMode == .preview`） | WKWebView |
| Office 表格/文档文本模式 | 内容为转换结果，非源文件 |
| 压缩包条目列表 | 非单文件文本 |
| 内容截断 | 保存会破坏文件 |
| QuickLook / 自定义脚本预览 | 非内置文本视图 |

### 3.3 侧栏 vs 独立窗口

两种宿主**共用** `PreviewSession` + `FileContentView` + 工具栏扩展，行为一致。  
胶片条切换文件时同样走脏状态拦截（`switchBrowseTarget` / `browsePrevious` / `browseNext`）。

---

## 四、交互设计

### 4.1 模式状态机

```
                    ┌─────────────┐
         进入编辑   │   viewing   │  默认
        ──────────► │  (只读预览)  │
        ◄────────── └──────┬──────┘
        放弃修改           │ 编辑
                           ▼
                    ┌─────────────┐
                    │   editing   │
                    │ (纯文本编辑) │
                    └──────┬──────┘
                           │ 保存成功
                           ▼
                    回到 viewing，content 刷新
```

| 状态 | 文本视图 | 语法高亮 | 搜索 | 行号 | 换行 |
|------|----------|----------|------|------|------|
| viewing | 只读 | 开（现有逻辑） | 开 | 开 | 开 |
| editing | 可编辑 | **关** | **关** | 开 | 开 |

### 4.2 工具栏（文本类型追加项）

在 `previewTextToolbarItems` 末尾追加（仅 `canEdit == true` 时）：

| 控件 | viewing | editing | 说明 |
|------|---------|---------|------|
| 编辑 | 显示 | — | `pencil` → 进入 editing |
| 保存 | — | 显示，disabled 当 `!hasUnsavedChanges` | `square.and.arrow.down`，等同 ⌘S |
| 放弃修改 | — | 显示，disabled 当 `!hasUnsavedChanges` | `arrow.uturn.backward` |
| 完成编辑 | — | 可选：与「放弃」合并或单独「完成」只读退出 | 有脏数据时先走拦截 |

**脏指示**：保存按钮 enabled 即暗示有修改；可选在标题旁 `•`（首版可省略，以按钮 disabled 为准）。

### 4.3 保存流程

对齐 `saveEditedImage()`：

1. 无修改 → 直接返回
2. `NSAlert`：标题「保存修改」；正文「将覆盖原文件「{文件名}」。」；按钮「保存」「取消」
3. 后台 `Task.detached`：`textView.string` 写 `browseTarget.url`（UTF-8，`atomic: true`）
4. 成功：`originalContent = saved`；`hasUnsavedChanges = false`；退出 editing 或保持 editing（**默认回到 viewing 并重载**）
5. 失败：`content.textSaveErrorMessage` + alert（复用 `L10n.Preview.saveFailedTitle` 模式）

### 4.4 放弃修改

1. 若有脏数据：`NSAlert` 确认
2. 确认后：`content.textContent = originalContent`；`hasUnsavedChanges = false`；回到 viewing

### 4.5 切换文件拦截

触发点（统一走 `PreviewSession.confirmDiscardTextEditsIfNeeded()`）：

| 入口 | 调用时机 |
|------|----------|
| 侧栏选中变化 | `FilePreviewSessionHost` / session 文件 id 变化前 |
| 胶片条点击 | `PreviewBrowserStripView.onSelect` 内，`switchBrowseTarget` 前 |
| 键盘 ← / → | `PreviewBrowserController` 内，`browsePrevious/Next` 前 |
| 退出编辑模式（无脏） | 直接退出 |

Alert 三按钮：**保存** / **不保存** / **取消**（取消则 abort 导航）。

> 方案 A **不**拦截主窗口关闭、独立窗口关闭（留 B）；但在 editing 且有脏数据时，关闭独立窗口应至少 `NSAlert`（列入 PT-06 可选增强）。

### 4.6 快捷键

| 快捷键 | viewing | editing |
|--------|---------|---------|
| ⌘S | — | 保存（仅 editing 且可编辑时注册） |
| ⌘Z / ⇧⌘Z | — | 系统 Undo（NSTextView 内置，不额外做工具栏） |
| ⌘A/C/V/X | 复制/全选 | 剪切/复制/粘贴/全选（已有 `TextEditingKeyMonitor`） |

通过 `@FocusedValue(\.previewTextEditActive)` 或扩展现有 `previewTextSelectionActive` 注册菜单命令。

---

## 五、架构

### 5.1 新增类型

```
Sources/Explorer/Preview/
├── PreviewTextEditEligibility.swift      # 可否编辑判定
├── PreviewTextEditWriter.swift           # UTF-8 原子写盘 + 错误类型
├── PreviewSession+TextEdit.swift         # save / revert / 拦截确认
└── PreviewSession+ToolbarText.swift      # 已有，追加工具栏项
```

### 5.2 状态扩展（`PreviewSessionTextState`）

```swift
enum PreviewTextDisplayMode: Equatable {
    case viewing
    case editing
}

@Published var displayMode: PreviewTextDisplayMode = .viewing
@Published var originalContent: String = ""      // 进入 editing 或 load 完成时快照
@Published var hasUnsavedChanges: Bool = false
@Published var previewAction: TextPreviewAction?   // 扩展 save / revert / beginEdit
```

`hasUnsavedChanges` 由 `TextFilePreview` 在 editing 模式下监听 `NSTextView.didChangeNotification` 与 `originalContent` 比较（normalize 换行可选：统一 `\n` 再比）。

### 5.3 视图层（`TextFilePreview`）

- 新增 `@Binding var displayMode`
- 新增 `@Binding var hasUnsavedChanges`
- `displayMode == .editing` → `isEditable = true`；跳过高亮 `applyHighlight`
- `displayMode == .viewing` → 保持现有只读 + 高亮逻辑
- `updateNSView` 中 **禁止**在 editing 时用外部 `text` prop 覆盖用户输入（仅 viewing 或 revert 时同步）

### 5.4 加载与 originalContent

在 `PreviewSession` 文本 load 完成时：

```swift
text.originalContent = content.textContent
text.hasUnsavedChanges = false
if text.displayMode == .editing { text.displayMode = .viewing } // 新文件强制只读
```

`resetControls()` / `prepareToolbarForLoad` 时重置 `displayMode` 与脏状态（在 confirm 之后）。

### 5.5 写盘

```swift
enum PreviewTextEditWriter {
    static func write(_ text: String, to url: URL) throws {
        guard let data = text.data(using: .utf8) else {
            throw PreviewTextEditError.notUTF8Encodable
        }
        try data.write(to: url, options: .atomic)
    }
}
```

不写 BOM；保持 Unix `\n`（`NSTextView.string` 默认）。

---

## 六、边界与错误

| 情况 | 行为 |
|------|------|
| 文件 > 20k 被截断 | 「编辑」disabled；tooltip 说明「文件过大，请用外部编辑器」 |
| 非 UTF-8 文件 | 加载失败已有 error；若部分可读但不完整，disabled 编辑 |
| 只读文件系统 | 「编辑」disabled |
| 保存时文件被删 | 写盘失败 → alert |
| 保存时无写权限 | `CocoaError.fileWriteNoPermission` → alert |
| editing 中外部修改 | 方案 A 不检测；用户保存会覆盖 |
| Markdown 源码模式 | **允许**编辑（走 TextFilePreview） |
| HTML 源码模式 | **允许**编辑 |

---

## 七、i18n

所有新 UI 文案写入 `Sources/Explorer/Resources/Localizable.xcstrings`（`en` + `zh-Hans`），并在 `L10n.swift` 暴露：

| 键（示例） | 中文 |
|------------|------|
| `preview.text_edit.edit` | 编辑 |
| `preview.text_edit.save` | 保存 |
| `preview.text_edit.revert` | 放弃修改 |
| `preview.text_edit.save_confirm_title` | 保存修改 |
| `preview.text_edit.save_confirm_message` | 将覆盖原文件「%@」。 |
| `preview.text_edit.discard_confirm_title` | 放弃修改？ |
| `preview.text_edit.unsaved_title` | 未保存的修改 |
| `preview.text_edit.unsaved_message` | 「%@」有未保存的修改。 |
| `preview.text_edit.too_large` | 文件过大，无法在预览中编辑 |
| `preview.text_edit.not_writable` | 文件不可写 |

---

## 八、测试策略

| 层级 | 文件 | 覆盖 |
|------|------|------|
| 单元 | `PreviewTextEditEligibilityTests` | 扩展名、截断、模式、可写 |
| 单元 | `PreviewTextEditWriterTests` | 写盘、原子替换、UTF-8 |
| 单元 | `PreviewSessionTextEditTests` | dirty 检测、original 快照 |
| L10n | `L10nTests` | 新键非键名 |
| 手动 | 计划文档清单 | 保存/放弃/切换/独立窗口 |

---

## 九、资源与性能

| 项 | 方案 A 影响 |
|----|-------------|
| 内存 | 与现预览相同（≤20k 字符） |
| CPU | editing 无高亮，比 viewing 更轻 |
| 包体积 | +0（无新依赖） |
| 磁盘 | 保存时一次原子写入 |

---

## 十、后续方案 B（不在本文实现）

1. 编辑模式全文件读取（上限 1–2 MB）
2. 外部文件变更提示
3. 独立/主窗口关闭拦截
4. 增量语法高亮（TextKit 2）
5. 标题栏脏点 / Git 状态

---

## 十一、参考代码位置

| 用途 | 文件 |
|------|------|
| 只读文本视图 | `Sources/Explorer/Preview/Views/TextFilePreview.swift` |
| 文本读取上限 | `Sources/Explorer/Preview/TextFilePreviewReader.swift` |
| 图片保存模板 | `Sources/Explorer/Preview/PreviewSession+Loading.swift` → `saveEditedImage()` |
| 工具栏 | `Sources/Explorer/Preview/PreviewSession+ToolbarText.swift` |
| 键盘转发 | `Sources/Explorer/TextEditingSupport.swift` |
| 浏览切换 | `Sources/Explorer/Preview/Browser/PreviewBrowserStripView.swift` |
| 内容加载 task | `Sources/Explorer/Preview/FileContentView.swift` |
