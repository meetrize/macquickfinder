# 外部 Reveal 标签策略（MeoLaunch ↔ MeoFind）

> 状态：**已实现（待手测确认）**  
> 日期：2026-09-08  
> 关联：MeoLaunch Overlay「在访达中显示」→ `open -R` → MeoFind `ExternalFolderOpenCenter`

## 1. 现象（用户复现）

1. 冷/温启动 Reveal `/Volumes/SSD4T/app/Microsoft Excel.app`：进入父目录并选中 — **正常**。
2. 再 Reveal 同目录 `/Volumes/SSD4T/app/汽水音乐.app`：不应新开标签，应在当前 `/Volumes/SSD4T/app` 标签内改选中。
3. 跨目录 Reveal（如 `/System/Applications/…`）：应 **新开标签**，落到正确父目录并选中；新标签须 **立即选中并激活**（成为 key / selectedWindow）。
4. 失败时曾出现：误开标签、落到错误目录（如本应选中汽水音乐却停在 `/System/Applications`）、新标签未激活需手动点。

诊断日志（`/tmp/meofind-external-open.log`）表明：同目录二次 Reveal 多数已走 `warm-same-dir`，问题更常出在 **投递后未落到正确标签 / 未激活 / 选中被 isKeyWindow 门闩丢掉**；跨目录 `warm-new-tab` 则存在 **合并后未稳定激活**。

## 2. 责任边界

| 组件 | 职责 | 本期是否改 |
|------|------|------------|
| MeoLaunch `revealAppInFinderAtPath:` | 单次 `open -R <app>`，先收 Overlay | 否（已正确） |
| MeoFind `ExternalOpenRouter` / Resolver | `.app` → 父目录 + selectionPath | 仅增强诊断 |
| MeoFind `ExternalFolderOpenCenter` | 冷/温/同目录/跨目录路由 | **是** |
| MeoFind `ExplorerWindowTabCenter` | 新标签合并、选中、激活 | **是** |
| MeoFind `ContentView` | 消费 pending、选中重试 | **是** |

## 3. 目标行为（不变量）

记 `targetDir` = 待 Reveal 项的父目录，`selection` = 该项完整路径。

| # | 条件 | 行为 |
|---|------|------|
| I1 | 冷启动（会话未建立） | **仅一个**浏览标签；导航到 `targetDir` 并选中；禁止第二标签 |
| I2 | 已有标签的注册 path == `targetDir` | **不** `openNewTab`；切到该标签并激活；只更新选中 |
| I3 | 无标签已显示 `targetDir` | 在锚点窗 **新开标签** → `targetDir` + 选中；新标签为 selected + key |
| I4 | 选中 | 列表未就绪时延迟重试；Unicode（NFC/NFD）可匹配 |
| I5 | MeoLaunch 夺焦后回前台 | pending 不得因「当时不是 key」永久丢失 |

## 4. 根因归纳

1. **锚点只认 key 窗 path**：同目录决策未「全标签搜索已显示 targetDir 的窗」，跨组/错 key 时误判。
2. **`applyExternalOpenRequestIfNeeded` 强依赖 `isKeyWindow`**：`makeKeyAndOrderFront` 与 `openRequestGeneration` 同拍时窗尚未成为 key → pending 被吞或未消费，选中丢失。
3. **新标签合并后 `suppressOrderFront` + 仅 `makeKey()`**：外部 Reveal 场景下新标签可保持「未选中/未激活」；用户看到后台标签或错误前台内容。
4. **主场景 `openMainWindow()` 不带 path**：完全依赖 `pendingNewTab` / `pendingMainTabNavigations`；若合并与 onAppear 竞态，会回落到 `restoredLaunchPath`（如上次的 `/System/Applications`）。

## 5. 方案

### 5.1 路由（`ExternalFolderOpenCenter.requestOpen`）

```text
resolve(url) → (targetDir, selection)
if !sessionReady → cold pending（单窗）+ coalesce
else:
  if let tab = findRegisteredWindow(directory: targetDir):
      activate(tab)          // selectedWindow + makeKeyAndOrderFront
      deliverPending(tab)    // 同目录选中
  else if let anchor = preferredAnchor:
      openNewTab(targetDir, selection, from: anchor, activate: true)
  else:
      openFolderWindow(request)
```

### 5.2 投递与消费（`ContentView`）

- 按 **本窗 path 是否匹配 pending.directory** 或 **本窗是否为 tabGroup.selectedWindow** 消费，不再唯一依赖 `isKeyWindow`。
- `deliver` 后主线程 `async` / 短延迟再 `applyExternalOpenRequestIfNeeded`（覆盖激活竞态）。
- 保留列表就绪后的选中重试（已有 `scheduleExternalSelectionRetry`）。

### 5.3 新标签激活（`ExplorerWindowTabCenter.mergeNewTabWindow`）

- 合并后：`selectedWindow = newTab`，`makeKeyAndOrderFront`，必要时再 `orderFrontRegardless`。
- 外部 Reveal / 显式 `activate: true`：**不要**用 `suppressOrderFront` 吞掉置前；⌘T 内部新建可保留防闪策略。
- 下一拍再确认 `selectedWindow === newTab` 且为 key。

### 5.4 新标签路径保底

- `openNewTab` 写入 pending 后，ContentView init / `hostWindow` onChange / onAppear 三路径都能落到 `navigation.path`。
- 若 `bootstrappedFromPendingNewTab` 但 path 仍像首页/上次路径，强制 `applyPendingExternalNavigationForNewTab`。

### 5.5 非目标

- 不改 MeoLaunch 菜单项与 `open -R` 调用方式。
- 不引入第三方库；不改 MeoFind 预览独立开窗策略。

## 6. 验收

1. 退出 MeoFind → Reveal Excel（SSD）→ 单标签 + 选中。
2. 再 Reveal 汽水音乐 → **仍一标签**，选中切换；无新标签。
3. Reveal `/System/Applications/Photos.app` → **新标签**，路径为 `/System/Applications`，Photos 选中，**新标签立刻成为前台**。
4. 再 Reveal SSD 下另一 app → 切回（或停留）SSD 标签并选中，不把 System 标签路径改错。
5. `/tmp/meofind-external-open.log` 可见 `warm-reuse-tab` / `warm-new-tab` / `cold-pending` 分支。

## 7. 实现清单

- [x] `ExplorerWindowTabCenter`：按目录查找窗；合并后强制激活 API
- [x] `ExternalFolderOpenCenter`：I2/I3 路由；投递后 deferred apply
- [x] `ContentView`：放宽/修正 pending 消费条件 + 重试
- [x] 构建安装 MeoFind；按 §6 手测（待用户确认）

> 状态：**已实现（待手测确认）**
