# 单窗口模式（Single Window Mode）— 交互设计与开发计划

> 状态：**已实现（待手测；含 path=nil 壳落地崩溃修复）**  
> 日期：2026-09-09  
> 关联：外部 Reveal（`ExternalFolderOpenCenter` / `ExplorerWindowTabCenter`）、[external-reveal-tabs-design.md](./external-reveal-tabs-design.md)
>
> 决策确认：同窗已有 targetDir → **切标签（A）**；背后独立窗 → **只动前台（A）**；默认开关 → **关**。
>
> **回归修复（2026-09-09）：** 单窗口模式曾把 `tabGroup.selectedWindow`（常为 path=nil 的 odoc 壳）当作落地窗；`deferred-orphan` 随即关掉同一窗 → 跳转失败 / `NSWindowStackController` SIGABRT。现改为只落在已登记 path 的浏览标签，并禁止关闭 pending 投递目标窗。

---

## 0. 需求原话（用户意图）

启用后：

1. **外部入口**（「在访达中显示」、`open -R`、系统/其它 App 把目录交给 MeoFind）**不再新建窗口或标签**。
2. **手动** ⌘N / ⌘T / 菜单「新窗口」「新标签」**仍允许**多窗多标签。
3. 外部打开的目录应在某个「主」浏览上下文中 **跳转并替换** 当前目录（可带选中项）。

---

## 1. 对原交互的评估

### 1.1 合理之处

| 点 | 评价 |
|----|------|
| 只约束「外部打开」，不锁死手动多窗 | ✅ 符合 Finder 替代品 / 编辑器通行做法 |
| 外部 Reveal 希望「立刻看到目标」而不是叠一堆标签 | ✅ 痛点真实（本仓库已有大量多余标签竞态文档） |
| 用设置开关控制，而不是硬改默认 | ✅ 默认可保留现有「新开标签」习惯 |

### 1.2 不合理点（不建议原样做）

| 原设想 | 问题 | 通行做法 |
|--------|------|----------|
| 用户**指定**主窗口 / 主标签 | 认知负担高；关窗后主锚点失效；多显示器下难理解 | **隐式锚点**：始终用「当前前台浏览窗的选中标签」 |
| 「单进程」表述 | 易误解为禁止第二进程 / 禁止多开 App | 产品名用 **单窗口模式**；说明写「外部打开」 |
| 无条件「替换原来的目录」 | 若用户前台停在 A，同目录目标已在同窗的另一标签 B，强行改 A 会弄丢 A 的浏览位置 | **同窗内先复用同目录标签**；没有才在当前选中标签导航 |
| 未定义「无浏览窗 / 仅预览窗 / 全最小化」 | 会静默失败或误开设置窗 | 明确冷启动与回退：必要时仍可创建 **唯一** 浏览窗 |

结论：**方向对，锚点策略与同目录复用需改成更符合通行交互的自动规则。**

---

## 2. 推荐交互（修订版）

### 2.1 产品定义（一句话）

**单窗口模式：外部打开目录时，在前台浏览窗口内完成定位（优先切到已有同目录标签，否则在当前标签导航），不新建窗口或标签；手动新建不受影响。**

### 2.2 设置项

| 项 | 内容 |
|----|------|
| 位置 | 设置 → 通用，与「窗口贴边」同组或紧邻 |
| 标题 | **单窗口模式** / `Single Window Mode` |
| 控件 | 单一 `Toggle`（默认 **关**，保持现有外部 Reveal 行为） |
| Footer | 开启后，从其它应用打开目录时，在当前前台窗口的标签中跳转，不新建窗口或标签。手动新建窗口/标签不受影响。 |

不提供「指定主窗口」UI（v1）。若日后强需求，再做成高级项「固定接收窗口」，默认仍为自动前台。

### 2.3 模式对照

记：外部请求解析为 `targetDir` + 可选 `selection`。

| 场景 | 关闭（当前默认） | 开启（单窗口模式） |
|------|------------------|-------------------|
| 冷启动、无浏览窗 | 创建一窗，导航到目标 | **同左** |
| 温启动、已有浏览窗 | 在锚点 **新开标签**（现状 `warm-new-tab ALWAYS`） | **禁止**外部新标签 / 新窗口 |
| 前台标签已是 `targetDir` | （现状仍常新标签） | 激活前台窗 + 只更新选中 |
| 前台窗的**其它标签**已是 `targetDir` | 新标签 | **切到该标签** + 选中（不改其它标签路径） |
| 前台窗内无 `targetDir` 标签 | 新标签 | **当前选中标签导航**到 `targetDir` + 选中（写入前进/后退历史） |
| 另有独立窗也显示 `targetDir` | 视复用/合并逻辑 | **不**跳到背后独立窗；只在前台锚点窗处理（避免「焦点跑到后台窗」） |
| 手动 ⌘N / ⌘T | 允许 | **允许** |
| 预览独立窗 / 设置 / 帮助 | 非浏览锚点 | **同左**，不作为落地目标 |

### 2.4 锚点选择（隐式「主窗口」）

优先级（只考虑已登记的 `main` / `folder` 浏览窗）：

1. **当前 key 浏览窗**（若存在）  
2. 否则 **orderedWindows 中最靠前的可见、非最小化浏览窗**  
3. 否则 **任意已登记浏览窗**（含最小化：deminiaturize）  
4. 否则 **新建唯一浏览窗**（等价冷启动）

锚点窗内的落地标签：

1. 若该窗 `tabGroup` 内已有 path == `targetDir` 的标签 → **选中该标签**（reuse）  
2. 否则 → **该窗当前 `selectedWindow`（选中标签）** 上执行导航替换  

不引入持久化 `primaryWindowID`。

### 2.5 用户可感知行为细则

1. **置前**：落地后 `activate` + `makeKeyAndOrderFront`，MeoFind 抢前台（与现有 Reveal 一致）。  
2. **历史**：导航替换须走现有 `navigation` 路径，支持 ⌘[ / ⌘] 回到被替换前的目录。  
3. **选中**：列表未就绪时沿用现有 `scheduleExternalSelectionRetry` / Unicode 匹配。  
4. **不关其它窗**：开启模式 **不**自动关闭用户已开的其它窗口/标签；只约束外部入口的创建行为。  
5. **去重**：短时重复 Reveal（同 path）继续走现有 dedupe，避免连跳两次。  
6. **抑制系统壳窗**：沿用 / 强化 `external-open suppression`，防止 AppKit 在 activate 时偷偷加标签。

### 2.6 明确非目标（v1）

- 不禁止第二进程、不实现真正的「单实例锁」（除非另行产品需求）。  
- 不合并或强制关闭已有多窗。  
- 不改变应用内「在新标签打开」「在新窗口打开」等显式命令。  
- 不改变预览独立窗 / 外部多图策略（`PreviewOpenPreferences`）。  
- 不要求用户标记「主标签」。

### 2.7 交互示意

```text
外部 Reveal(targetDir, selection)
        │
        ▼
  单窗口模式？
   ├─ 否 → 现有 warm-new-tab / cold-pending
   └─ 是 → 解析锚点窗
              │
              ├─ 无浏览窗 → 创建一窗 + 导航 + 选中
              └─ 有锚点窗
                    │
                    ├─ tabGroup 内已有 targetDir → 切标签 + 选中 + 置前
                    └─ 否则 → 当前选中标签 navigate(targetDir) + 选中 + 置前
```

---

## 3. 技术方案（概要）

### 3.1 偏好键

```text
AppPreferences.General.singleWindowMode = "singleWindowMode"  // Bool, default false
```

设置页：`GeneralSettingsTab` 增加 Toggle + footer；`L10n` + `Localizable.xcstrings` + `compile_localizations.sh`。

### 3.2 路由分支（核心）

在 `ExternalFolderOpenCenter.requestOpen` 温启动分支：

```text
if AppPreferences singleWindowMode {
  guard let anchor = preferredExplorerAnchorWindow() ?? fallbackBrowser else {
    openFolderWindow(request) // 唯一回退
    return
  }
  if let sameDirTab = tabs.windowShowingDirectory(targetDir, inTabGroupOf: anchor) {
    deliverReuseSelection(..., window: sameDirTab)
  } else {
    deliverNavigateInPlace(request, window: anchor.selectedOrSelf)
  }
  return
}
// else: 现有 warm-new-tab ALWAYS
```

新增 `deliverNavigateInPlace`：

- 设定 `pendingDeliveryWindowID`  
- `pendingRequest` 带 `directoryPath` + `selectionPath`  
- ContentView 消费时：若本窗 path ≠ directory → `navigation.navigate`（或等价 API）再选中；若已相等 → 只选中  
- **禁止**调用 `openNewTab` / `openMainWindow` / `openFolderWindow`（无窗回退除外）

### 3.3 ContentView / TabCenter

- 放宽消费条件：单窗口模式下允许「path 将变为 targetDir」的窗消费（不能只认 path 已匹配）。  
- `beginExternalDocumentOpenSuppression` 在 navigate-in-place 路径同样开启，避免系统加页。  
- 诊断日志增加：`warm-navigate-in-place` / `warm-reuse-tab (single-window)`。

### 3.4 测试

单元 / 集成（ExplorerTests）：

1. 开关关：温启动仍走新标签路径（可 mock handler 调用次数）。  
2. 开关开 + 前台 path≠target → 不调用 openNewTab，只 deliver navigate。  
3. 开关开 + 同组已有 targetDir 标签 → reuse 该窗，不 navigate 错标签。  
4. 无浏览窗 → 允许一次 openFolderWindow。  
5. 手动 openNewTab API 不受偏好影响。

---

## 4. 开发计划（分阶段）

### 阶段 SW-0：对齐与文档（0.5d）

- [x] 产品确认本文件 §2 交互（尤其「同窗复用优先于替换」）
- [x] 确认默认关闭
- [x] 本文件状态改为「已确认 / 实现中」

### 阶段 SW-1：设置与偏好（0.5d）

- [x] `AppPreferences.General.singleWindowMode`
- [x] `GeneralSettingsTab` Toggle + footer
- [x] i18n：`en` / `zh-Hans` → `L10n` → `compile_localizations.sh`
- [x] `L10nTests` 断言非键名

### 阶段 SW-2：路由与落地（1–1.5d）

- [x] `ExternalFolderOpenCenter`：单窗口分支；`deliverNavigateInPlace`
- [x] 锚点与「同 tabGroup 同目录」查找 API（`windowShowingDirectory(_:inTabGroupOf:)`）
- [x] ContentView：消费 navigate-in-place pending（含历史；同组 owner 门闩）
- [x] 诊断日志分支名

### 阶段 SW-3：竞态与抑制（0.5–1d）

- [x] 外部 suppression 覆盖 navigate 路径
- [x] 禁止本路径触发新标签（不调用 `openNewTab` / `openExternalRevealTab`）
- [x] 置前 / 选中重试与现有 Reveal 对齐
- [ ] 手测对照 `/tmp/meofind-external-open.log`

### 阶段 SW-4：测试与验收（0.5d）

- [x] 自动化测试 §3.4（决策 + 偏好 + 无锚点回退）
- [ ] 手测清单 §5
- [ ] 帮助速查表补一行（可选，随帮助文档迭代）

**合计预估：约 3–4 人日。**（代码已落地，待手测）

---

## 5. 手测验收清单

| # | 步骤 | 期望 |
|---|------|------|
| 1 | 开关关；单窗在 Desktop；Reveal SSD 上 app | 新标签打开 SSD 父目录并选中（现有行为） |
| 2 | 开关开；同上 | **仍一标签**，Desktop → 变为 SSD 父目录并选中；可用后退回 Desktop |
| 3 | 开关开；已有标签 Desktop \| SSD；前台 Desktop；再 Reveal SSD 项 | 切到 SSD 标签并选中，**不**改 Desktop 路径，**不**第三标签 |
| 4 | 开关开；两独立窗 A/B，B 在前台；Reveal | 只动 B（或 B 所在组），A 路径不变 |
| 5 | 开关开；⌘T 新标签后外部 Reveal | 允许已有多标签；外部只影响锚点规则，不删标签 |
| 6 | 开关开；退出 App 后冷启动 Reveal | 单窗正确目录 + 选中 |
| 7 | 开关开；仅预览独立窗、无浏览窗 | 创建一浏览窗并落地，不静默失败 |
| 8 | 中/英设置文案 | 显示译文，不显示键名 |

---

## 6. 默认值建议

| 用户画像 | 建议 |
|----------|------|
| 把 MeoFind 当默认「在访达中显示」接收方、常被 MeoLaunch/微信等唤起 | 倾向开启 |
| 喜欢每个外部 Reveal 留一条标签当历史 | 保持关闭 |

**产品默认：关闭**，避免改变现有用户对「Reveal → 新标签」的预期；在设置 footer / 首次设为默认查看器成功提示中可一句引导。

---

## 7. 决策记录

| 决策 | 选项 | 结论 |
|------|------|------|
| 同窗已有 targetDir 标签时 | A 切标签 / B 仍改当前标签 | **A（已确认）** |
| 背后独立窗已显示 targetDir | A 仍只动前台 / B 跳到背后窗 | **A（已确认）** |
| 默认开关 | 开 / 关 | **关（已确认）** |
