# 文件属性窗（可编辑标签/注释）— UI 与实现规划

> 目标：在右键菜单「显示信息/属性」打开的窗口中，提供友好的交互与美观的布局，并且允许用户**直接修改 Finder 标签（tags）与注释（comment/备注）**。  
> 当前仓库里原「显示信息」是一个 `NSAlert` 文本弹窗；本设计将替换为可编辑的属性窗（SwiftUI + AppKit 承载）。

---

## 1. 用户体验目标（UI/交互）

### 1.1 需要实现的关键能力

1. **可编辑：标签（Tags）**
   - 已有标签以圆角胶囊展示（可移除）。
   - 支持新增标签（输入后回车/提交）。
   - 支持多选文件：如果多文件当前标签不一致，界面显示「当前值不同」，但编辑仍可直接覆盖应用到所有选中项目。

2. **可编辑：注释（Comment/备注）**
   - 多行文本输入框（带占位提示）。
   - 支持多选文件：若注释不一致，显示混合状态提示；编辑后覆盖应用到所有选中项目。

3. **展示信息：大小/时间/路径/权限等**
   - 右侧为“信息概览”，以键值对形式整齐展示（只读）。
   - 对多选场景，至少展示“已选中 N 个项目”，其余展示取第一个项目或摘要。

### 1.2 界面结构（建议布局）

- 顶部：Header
  - 左侧：文件图标 + 文件名（只读即可，后续可扩展为可重命名）
  - 右侧：路径摘要（单行省略，悬停/点击可复制完整路径）
- 中部：主编辑区
  - 左列：可编辑区域（标签 + 注释）
  - 右列：关键信息概览（类型、大小、创建/修改时间、位置等）
- 底部：操作/状态反馈（可选）
  - 保存状态文本（如「已保存」「保存失败」）
  - 本期可先做“编辑即保存”（或提供一个“应用/完成”按钮，避免丢失）

### 1.3 标签胶囊视觉规范

- 每个标签为一枚胶囊：浅色背景/填充色（颜色可由标签名 hash 生成，保证稳定性与区分度）。
- 悬停（或 hover）出现移除按钮 `×`。
- 标签添加输入框采用系统风格（`TextField` + 提示文字）。

### 1.4 注释编辑视觉规范

- `TextEditor` 多行框：圆角 + 浅边框。
- 内容为空时显示占位提示（如“添加一些备注，方便日后搜索与识别…”）。
- 提供轻量保存状态反馈。

---

## 2. SwiftUI 视图结构（组件拆分）

### 2.1 视图层级（建议）

- `FilePropertiesWindowController`
  - 负责创建 `NSWindow`，并将 SwiftUI 根视图挂载到 `NSHostingView`
  - 提供静态入口：`show(items: [FileItem])`

- `FilePropertiesWindowView`（根 SwiftUI View）
  - 接收 `FilePropertiesWindowViewModel`
  - 布局：
    - `PropertyHeaderView`
    - 主体 `HStack`：
      - `TagEditorView`
      - `CommentEditorView`
      - `BasicInfoView`（键值对，只读）
    - 底部 `StatusBarView`（显示保存状态）

- `TagEditorView`
  - `FlowLayout`（胶囊自动换行）
  - `Chip` 子组件（含移除按钮）
  - 新增标签输入框

- `CommentEditorView`
  - `TextEditor`
  - 占位提示与保存触发（debounce）

### 2.2 ViewModel 状态模型（建议）

- 输入：
  - `items: [FileItem]`
  - 只读信息用于展示（size/date/location/path）

- 可编辑状态：
  - `tags: [String]`（当前界面显示的标签）
  - `comment: String`（当前界面显示的注释）

- 混合标识（多选时）：
  - `isMixedTags: Bool`（多选时 tags 是否一致）
  - `isMixedComment: Bool`

- 用户是否真正编辑过（避免混合状态误写）：
  - `didEditTags: Bool`
  - `didEditComment: Bool`

- 保存状态：
  - `saveState: enum { idle, saving, success, error }`
  - `saveMessage: String`

---

## 3. 数据持久化策略（Finder tags / 注释）

### 3.1 Finder 标签（tags）

- 读取：已有代码使用 `URLResourceKey.tagNamesKey`（`values.tagNames`）。
- 写入：使用 `URLResourceValues.tagNames` 并调用 `url.setResourceValues(...)`。
- 若 tags 为空：将 `tagNames` 设置为 `[]`（或清空为 nil，取决于 API 可写行为）。

### 3.2 Finder 注释（Finder comment）

- 读取：已有代码使用 `MDItemCopyAttribute(..., kMDItemFinderComment)`，失败回退读取 xattr：  
  `com.apple.metadata:kMDItemFinderComment`（plist 序列化）。
- 写入（建议）：
  - 将注释内容做 `PropertyListSerialization`（存 string 或 `[String]`）
  - 写入 xattr：`setxattr(path, "com.apple.metadata:kMDItemFinderComment", ...)`
  - 清空注释时：调用 `removexattr`

> 注：本期实现以“写入与刷新展示”为优先；后续可进一步对齐 Finder 的底层格式细节（如 Finder 可能存储二进制 plist 或其它变体）。

---

## 4. 与右键菜单 / 入口的集成方式

### 4.1 当前现状

- 右键菜单「显示信息」最终调用：`FileOperations.showInfo(_:)`
- 目前 `showInfo` 只是展示 `NSAlert`，不支持编辑 tags/comment。

### 4.2 本期集成方案

- 将 `FileOperations.showInfo` 改为：打开 `FilePropertiesWindowController.show(items:)`
- `FilePropertiesWindowController` 内部创建 ViewModel，并挂载 SwiftUI UI
- 编辑 tags/comment 后写入 Finder 元数据，并触发目录列表刷新：
  - 对每个被修改 URL 的 `url.deletingLastPathComponent()` 调用 `DirectoryMetadataScheduler.invalidate(paths:)`

---

## 5. 实现 Plan（分阶段）

1. **阶段 1：写入能力（FinderMetadataWriter）**
   - 新增 `FinderMetadataWriter`
     - `setTags(for: URL, tags: [String])`
     - `setFinderComment(for: URL, comment: String)`
   - 处理异常与输入清洗（trim、过滤空字符串等）

2. **阶段 2：属性窗骨架**
   - 新增 `FilePropertiesWindowController`
   - 新增 `FilePropertiesWindowViewModel`
   - 新增 `FilePropertiesWindowView`（Header + TagEditor + CommentEditor + BasicInfoView + Status）

3. **阶段 3：替换入口**
   - 修改 `FileOperations.showInfo(_:)`
     - 用新的属性窗代替 NSAlert

4. **阶段 4：交互完善**
   - tags 的胶囊移除/新增与实时保存（可带 debounce）
   - comment 文本的 debounce 保存
   - 多选混合状态提示（避免“混合但未编辑却误写”为 0 值）

5. **阶段 5：手工验证**
   - 单文件：修改 tags/comment 后，右侧文件列表 comment/tags 列可刷新
   - 多文件：混合初始值时编辑应覆盖所有选中项

