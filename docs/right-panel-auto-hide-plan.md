# 右侧面板「固定显示 / 自动隐藏」升级方案

## 1. 需求确认

- 新增设置 `右侧面板模式`：`固定显示（pinned）` / `自动隐藏（auto）`，默认 `自动隐藏`。
- 自动隐藏：未选中任何文件/文件夹时，右侧面板整体不显示（预览 / Snippets / Git 都不显示）；选中后按「上次显隐组合」恢复显示。
- 固定显示：保持现有行为，上次打开右侧面板下次还打开，与是否有选中无关。
- 预览 / Snippets / Git 各自的显隐组合要记忆上次状态（持久化）。

## 2. 现状评估

- 状态位置：`Sources/Explorer/ExplorerWindowLayoutState.swift`
  - `showPreview / showSnippets / showGit` 三个 `@Published Bool`，各自 `didSet` 直接写 `UserDefaults`（`AppPreferences.Layout.*`），启动时 `loadSnapshot` 恢复。
  - `isRightPanelVisible = showPreview || showSnippets || showGit`；`toggleRightPanel()` 全关 / 开预览+片段。
  - `previewPanelWidth / previewSnippetsSplitRatio / gitPanelHeight / 各折叠态` 均已持久化，不受本次影响。
- 挂载位置：`Sources/Explorer/ContentView.swift`
  - `explorerRightPanelColumn`：`if layout.showPreview || showSnippets || showGit` 才挂右侧列。
  - `RightPanelStackView` 内部再按 `layout.showPreview / showSnippets / showGit` 分段渲染，可独立开关。
  - 内容搜索选中、双击目录、Reveal 等多处直接写 `layout.showPreview = true`。
  - `WindowLayoutCommands` 把三开关暴露给菜单/快捷键/命令面板。
- 设置位置：`Sources/Explorer/Settings/SettingsView.swift` 的 `GeneralSettingsTab` + `L10n.Settings.General` + `AppPreferences.General/Layout`。
- 选中模型：`ContentView.selection: Set<FileItem.ID>`，含 `..` 父目录虚拟项（`isParentDirectoryEntry`），自动隐藏的「有选中」必须排除该虚拟项。

## 3. 设计决策

### 3.1 语义：期望状态 vs 生效状态

- `showPreview / showSnippets / showGit` 重定义为「期望显隐」（用户上次手动开关的组合），**始终持久化**，切换模式/清空选中都不改写它们。
- 新增 `rightPanelMode: pinned | auto`（持久化 `AppPreferences.Layout.rightPanelMode`，默认 `auto`）。
- 生效状态由纯函数计算：

```swift
effective = pinned ? desired : (hasRealSelection ? desired : 全部隐藏)
```

- 这样「前一次的显示组合」天然就是 `desired`，无需第二份存储，也避免自动隐藏时误清用户偏好。

### 3.2 `hasRealSelection` 定义

- `selection` 中至少有一个对应 `items` 里 `!isParentDirectoryEntry` 的项。
- 目录切换 `loadItems(clearingSelection:)`、删除、增量剔除都会清空/收缩 `selection`，自动隐藏会跟随，无需额外监听。
- 内容搜索结果点击会先 `selection = [match]` 再 `showPreview = true`，在 auto 下能正确点亮。

### 3.3 固定/自动切换时的行为

- pinned → auto：立即按当前选中重算；无选中则面板收起，但 `desired` 保留，设置页文案说明。
- auto → pinned：立即恢复 `desired` 组合（即「上次打开的还要打开」）。
- auto + 无选中时用户点工具栏 Preview/Snippets/Git 开关：只改 `desired`（面板仍隐藏，选中后生效），并给一个瞬时提示，避免「点了没反应」的困惑。

### 3.4 触点清单

| 触点 | 改动 |
|---|---|
| `AppPreferences.Layout` | 新增 `rightPanelMode` 键 |
| `ExplorerWindowLayoutState` | 新增 `RightPanelMode` 枚举 + `rightPanelModeRaw/desired` 发布 + `effectiveRightPanelVisibility(hasSelection:)` + 感知选中的 `toggle*` 守卫 + 快照读写 |
| `RightPanelStackView` | 新增 `hasSelection` 入参，内部用 `effective` 代替 `layout.show*` 做分段渲染与高度计算 |
| `ContentView` | 计算 `hasRealSelection`，右侧列挂载条件与 `explorerRightPanelColumn` 传参改生效状态；`WindowLayoutCommands` 开关走 layout 守卫方法；工具栏环境不变 |
| `SettingsView` | 通用页新增「右侧面板」Section：Picker（固定/自动）+ footer 说明 |
| `L10n` + 中英文 `.strings` | 新增 5 个 key |
| 测试 | 新增 `RightPanelModeTests`：无选中 auto 全隐、有选中恢复 desired、pinned 透传、toggle 守卫、快照默认 auto |

## 4. 补充交互（需求之外的完善）

1. 设置页 footer 明确写出两模式差异，auto 下注明「无选中时手动开关只记住偏好，选中后生效」。
2. auto + 无选中时工具栏开关置灰或点击后 toast：「已记住，选中文件后生效」（本次采用 toast，不改工具栏可用态，避免快捷键失效）。
3. 状态栏/面板空白区：auto + 无选中时右侧列完全移除，中间文件列表自动撑满（现有 `HStack` 条件挂载已支持，无需占位图）。
4. 快捷键（`togglePreview/Snippets/Git/RightPanel`）在 auto 无选中下同样只改 `desired`，行为与鼠标一致。
5. 不新增 `UserDefaults` 迁移：老用户只有 `show*` 三键，`rightPanelMode` 缺省即 `auto`，符合「默认为自动隐藏」。

## 5. 落地步骤（已执行）

1. 落盘本方案 `docs/right-panel-auto-hide-plan.md`。
2. `AppPreferences` 加键 → `ExplorerWindowLayoutState` 加模式与生效函数 → `RightPanelStackView` 接 `hasSelection`。
3. `ContentView` 接线 + `SettingsView/L10n/strings`。
4. 新增单测并 `swift test --filter RightPanelModeTests`，全量编译验证。
