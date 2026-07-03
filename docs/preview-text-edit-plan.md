# 预览区文本编辑 — 方案 A 开发计划

> 依据：[preview-text-edit-design.md](./preview-text-edit-design.md)  
> 目标：在预览区实现**轻量文本就地编辑**（进入编辑 → 修改 → 保存/放弃 → 切换拦截）。  
> 预估：**6 个 Issue · 3–5 天 · 新增 ~900 行 / 改动 ~300 行**。

---

## 总览

| Phase | 主题 | Issue | 预估 | 用户可见 |
|-------|------|-------|------|----------|
| **P1** |  eligibility + 写盘 + 状态 | PT-01 ~ PT-02 | 1 天 | 否 |
| **P2** | 编辑视图 + 工具栏 + 保存 | PT-03 ~ PT-04 | 1.5–2 天 | 是 |
| **P3** | 切换拦截 + 快捷键 + 测试 | PT-05 ~ PT-06 | 1–1.5 天 | 是 |

原则：

- 每步完成后 `swift build` 通过；P2 起可手动验证编辑闭环。
- **禁止**方案 B 范围（全文件加载、实时高亮、外部监听）。
- 新增 UI 文案遵守 `.cursor/rules/i18n-ui-strings.mdc`。

---

## P1：基础设施

### PT-01：编辑 eligibility 与写盘

**类型**：feat  
**依赖**：无  
**文件**：

- `Sources/Explorer/Preview/PreviewTextEditEligibility.swift`（新建）
- `Sources/Explorer/Preview/PreviewTextEditWriter.swift`（新建）
- `Tests/ExplorerTests/PreviewTextEditEligibilityTests.swift`（新建）
- `Tests/ExplorerTests/PreviewTextEditWriterTests.swift`（新建）

**任务**：

- [ ] `PreviewTextEditEligibility.canEdit(file:session:)` 实现设计文档 §3.1 全部条件
- [ ] 截断检测：复用 `TextFilePreviewReader.truncationMarker` 常量（从 reader 抽取 `"[Content truncated...]"` 避免魔法字符串散落）
- [ ] `PreviewTextEditWriter.write(_:to:)` UTF-8 + `.atomic`
- [ ] `PreviewTextEditError`：`notUTF8Encodable`、`notWritable` 等
- [ ] 单元测试：各扩展名、Markdown/HTML 模式、截断、只读 URL

**验收**：

- `swift test --filter PreviewTextEdit` 通过
- 纯函数无副作用，可在 Tests 中用临时目录写盘

---

### PT-02：Session 文本编辑状态

**类型**：feat  
**依赖**：PT-01  
**文件**：

- `Sources/Explorer/Preview/PreviewSessionNestedState.swift`（`PreviewSessionTextState` 扩展）
- `Sources/Explorer/Preview/Views/PreviewActionTypes.swift`（扩展 `TextPreviewAction`）
- `Sources/Explorer/Preview/PreviewSession+TextEdit.swift`（新建）
- `Sources/Explorer/Preview/PreviewSessionStateReset.swift`
- `Sources/Explorer/Preview/PreviewSession+Loading.swift`（load 完成时快照）
- `Tests/ExplorerTests/PreviewSessionTextEditTests.swift`（新建）

**任务**：

- [ ] `PreviewSessionTextState` 增加：
  - `displayMode: PreviewTextDisplayMode`（viewing / editing）
  - `originalContent: String`
  - `hasUnsavedChanges: Bool`
- [ ] `TextPreviewAction` 增加：`beginEdit`、`save`、`revert`
- [ ] `PreviewSession+TextEdit.swift`：
  - `func enterTextEditMode()`
  - `func revertTextEdits()`（含 confirm）
  - `func saveEditedText() async`（参照 `saveEditedImage`）
  - `func confirmDiscardTextEditsIfNeeded() async -> Bool`（true = 可继续导航）
- [ ] `content.textSaveErrorMessage` 或在 `PreviewSessionContentState` 增加同名字段（与 image 对称）
- [ ] 文本 load 成功 → 设置 `originalContent`；重置 dirty / viewing
- [ ] `resetTextToolbar` 增加 `displayMode = .viewing`（在 confirm 后调用）

**验收**：

- Session 层测试：dirty 比较、confirm 三分支逻辑（mock alert 或抽 pure helper）
- load 新文件后 editing 状态被清除

---

## P2：UI 闭环

### PT-03：TextFilePreview 编辑模式

**类型**：feat  
**依赖**：PT-02  
**文件**：

- `Sources/Explorer/Preview/Views/TextFilePreview.swift`
- `Sources/Explorer/Preview/PreviewCodeTextView.swift`
- `Sources/Explorer/Preview/FileContentView.swift`

**任务**：

- [ ] `TextFilePreview` 新增 bindings：`displayMode`、`hasUnsavedChanges`
- [ ] `editing`：`isEditable = true`；不调用 `applyHighlight`；监听 `NSTextView.didChangeNotification` 更新 dirty
- [ ] `viewing`：保持现有行为
- [ ] **关键**：`updateNSView` 在 editing 时勿用 `text != textView.string` 覆盖用户输入；仅 viewing / revert 时同步
- [ ] editing 时跳过搜索高亮分支（或 guard displayMode）
- [ ] `PreviewCodeTextView`：editing 时启用 `cut`/`paste`（调用 super 或 pasteboard）
- [ ] `FileContentView` 接线 bindings；`onChange(of: text.previewAction)` 分发 beginEdit / save / revert

**验收**：

- 手动：进入编辑 → 输入 → 工具栏 dirty → 放弃恢复
- viewing 模式行为与改动前一致（高亮、搜索、复制）
- Markdown **源码**模式可编辑；**预览**模式无编辑按钮

---

### PT-04：工具栏 + i18n + 保存 Alert

**类型**：feat  
**依赖**：PT-03  
**文件**：

- `Sources/Explorer/Preview/PreviewSession+ToolbarText.swift`
- `Sources/Explorer/Resources/Localizable.xcstrings`
- `Sources/Explorer/L10n.swift`
- `Sources/Explorer/Preview/FileContentView.swift`（save failed alert）
- `Tests/ExplorerTests/L10nTests.swift`

**任务**：

- [ ] `previewTextToolbarItems`：canEdit 时追加编辑/保存/放弃
- [ ] editing 时隐藏或 disable：复制全部、跳转顶/底（可选保留跳转）
- [ ] editing 时 disable 预览内搜索控件（`PreviewSession+ToolbarSearch` 配合）
- [ ] i18n 键见设计文档 §7；`L10n.Preview.TextEdit.*`
- [ ] `L10nTests` 断言新键
- [ ] 保存失败 alert 复用 `L10n.Preview.saveFailedTitle` 或专用文案
- [ ] 截断/不可写时编辑按钮 disabled + tooltip

**验收**：

- 中英文界面无键名泄露
- 保存成功后内容持久化，回到 viewing 并重载（`beginLoadTask`）
- 保存失败有 alert

---

## P3：导航拦截与收尾

### PT-05：文件切换未保存拦截

**类型**：feat  
**依赖**：PT-04  
**文件**：

- `Sources/Explorer/Preview/Browser/PreviewBrowserStripView.swift`
- `Sources/Explorer/Preview/Browser/PreviewBrowserController.swift`
- `Sources/Explorer/Preview/PreviewSession+TextEdit.swift`
- `Sources/Explorer/AppModule.swift` 或 `FilePreviewSessionHost`（侧栏选中变化）

**任务**：

- [ ] 抽取 `PreviewSession.performBrowseNavigation(_:)` 或在各入口 `await confirmDiscardTextEditsIfNeeded()`
- [ ] 胶片条 `onSelect`：confirm 后再 `switchBrowseTarget`
- [ ] 键盘 ←/→：同上
- [ ] 侧栏选中文件变化：若 session 有 editing + dirty，confirm 后再换 session / load
- [ ] Alert 三按钮：保存 / 不保存 / 取消
- [ ] 取消 → 保持当前文件与编辑状态

**验收**：

- 独立窗口胶片条：编辑中切换 → 弹窗；取消 → 留原文件
- 侧栏换选：同上
- 无 dirty 时切换零摩擦

---

### PT-06：快捷键 + 测试 + 文档

**类型**：feat / test / docs  
**依赖**：PT-05  
**文件**：

- `Sources/Explorer/ExplorerKeyboardShortcuts.swift` 或 `PreviewDetachCommands.swift`
- `Sources/Explorer/TextEditingSupport.swift`（如需 `previewTextEditActive` FocusedValue）
- `Tests/ExplorerTests/PreviewSessionTextEditTests.swift`（补全）
- `docs/preview-toolbar-rollout.md`（追加文本编辑条目）

**任务**：

- [ ] editing 且可编辑时 ⌘S → `saveEditedText()`
- [ ] `@FocusedValue` 桥接（预览文本 editing 获焦）
- [ ] 补单元测试覆盖 confirm helper、toolbar item 可见性（可测静态方法）
- [ ] 更新 `preview-toolbar-rollout.md`
- [ ] 完成手动回归清单

**验收**：

- `swift test` 全通过
- 手动清单全部勾选

---

## 推荐 PR 顺序

```
PT-01 → PT-02          (PR-1：纯逻辑，无 UI 回归风险)
PT-03 → PT-04          (PR-2：用户可见 MVP)
PT-05 → PT-06          (PR-3：拦截 + polish)
```

| PR | Issue | 说明 |
|----|-------|------|
| PR-1 | PT-01 ~ PT-02 | 可先合，无行为变化 |
| PR-2 | PT-03 ~ PT-04 | **核心功能**；需充分手动测 viewing 无回归 |
| PR-3 | PT-05 ~ PT-06 | 防数据丢失；含快捷键 |

---

## 手动回归清单

### 只读回归（确保无破坏）

- [ ] `.swift` / `.json` / `.txt` 预览：语法高亮、搜索、换行、行号正常
- [ ] Markdown 预览模式：渲染正常；切源码可编辑
- [ ] HTML 预览 / 源码切换正常
- [ ] 图片 / PDF / 视频 / Office / 压缩包：无编辑按钮

### 编辑闭环

- [ ] 小 `.txt`：编辑 → 保存 → 磁盘内容更新 → 回到只读
- [ ] 编辑 → 放弃 → 内容恢复
- [ ] ⌘S 保存
- [ ] ⌘Z 撤销输入
- [ ] 截断大文件：编辑 disabled + tooltip
- [ ] 只读卷文件：编辑 disabled

### 切换拦截

- [ ] 独立窗口胶片条：dirty 时切换 → 三按钮 alert
- [ ] 取消切换：留原文件、编辑保留
- [ ] 不保存切换：丢弃修改并加载新文件
- [ ] 保存并切换：写盘成功后加载新文件
- [ ] 侧栏换选文件：同上

### 独立窗口

- [ ] 弹出窗口内编辑保存正常
- [ ] 与侧栏 inline 行为一致

---

## 方案 B  backlog（勿在方案 A PR 引入）

- [ ] PT-B1：编辑模式全文件读取（≤2MB）
- [ ] PT-B2：窗口关闭未保存拦截
- [ ] PT-B3：FSEvents 外部变更提示
- [ ] PT-B4：编辑时 debounce 增量高亮

---

## Agent 执行备注

- 实现顺序**必须** PT-01 → PT-06，勿跳步。
- 每个 Issue 完成：`swift build` + 相关 `swift test`。
- 提交信息使用简体中文（`.cursor/rules/git-commit-message-zh.mdc`）。
- 详细约束见 `.cursor/rules/preview-text-edit-plan.mdc`。
