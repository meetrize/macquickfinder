# 外部 Reveal 多余标签（Desktop 第三页）— 机制分析与开发计划

> 状态：**R4-1～R4-3 已实现（待手测）**  
> 日期：2026-09-08  
> 前置：[external-reveal-tabs-design.md](./external-reveal-tabs-design.md)  
> 复现：MeoFind 单窗浏览 `/Users/meetrice/Desktop`（无标签栏）→ MeoLaunch「在访达中显示」汽水音乐 → 期望 2 标签，实际常出现 3 标签

### 实现进度

| 卡 | 状态 |
|----|------|
| R4-0 诊断 | done（bootstrap / tab-generation / openExternalRevealTab 日志） |
| R4-1 世代门闩 | done |
| R4-2 folder WindowValue | done（`openExternalRevealTab`） |
| R4-3 generation coalesce | done |
| R4-4 手测 | pending |

---

## 1. 现象（精确描述）

| 时刻 | 期望 | 实际 |
|------|------|------|
| 初始 | 1 个浏览窗，路径 Desktop，无标签栏 | 同左 |
| Reveal `/Volumes/SSD4T/app/汽水音乐.app` | **恰好 2** 个标签：Desktop \| SSD/app（选中汽水音乐，且激活） | Desktop + SSD/app + **又一个 Desktop** |
| 之后 | — | coalesce 有时关掉「同路径多余页」，但第三页是 **Desktop 复本**，不在 SSD coalesce 目标内 → **有时留下 3 标签** |

日志典型一行：

```text
requestOpen warm-new-tab from=/Users/meetrice/Desktop to=/Volumes/SSD4T/app
```

说明路由决策正确（跨目录 → 新标签）；多余页不是「又一次 requestOpen」，而是 **开标签实现层多造了一个窗**。

---

## 2. 底层机制：为什么会多出「第三个 Desktop」

### 2.1 当前开标签路径（主场景）

```text
ExternalFolderOpenCenter.deliverOpenRequestInNewTab
  → ExplorerWindowTabCenter.openNewTab(path: SSD, selection: 汽水音乐)
       ├─ pendingNewTab = { path:SSD, selection, anchor:Desktop窗 }
       └─ openMainWindow()   // SwiftUI openWindow(id: main) —— 不带路径参数
            → 新建一个 WindowGroup(.main) 的 NSWindow + ContentView
            → attemptTabMerge / interceptOrderFront
            → anchor.addTabbedWindow(new, .above)   // 合并进 Desktop 的 tabGroup
```

要点：**主场景新标签不走 `WindowGroup(for: FolderValue)`**，路径全靠进程内 `pendingNewTab` 旁路传递。

### 2.2 AppKit 标签模型叠床架屋

macOS 上「加标签」会触发两套创建路径：

1. **我们主动的** `openWindow(id: main)` → 完整 ContentView 窗  
2. **系统为「+ / 新标签」预创建的壳** → 调用 AppDelegate `newWindowForTab:`  

`addTabbedWindow` / `tabbingMode = .preferred` 会让系统认为「用户在加标签」，于是再抛壳窗。

已有抑制：

- `pendingNewTab != nil` 时忽略再次 `openNewTab`
- `ignoreSystemNewWindowForTabUntil`（约 1s）内 `newWindowForTab` 只 `close()` 壳

仍不够的原因：

| 竞态 | 结果 |
|------|------|
| A. 壳窗在 `close` 前已挂上 ContentView，`onAppear` 跑完 | 按 `restoredLaunchPath()` → **Desktop**（刚记过的 lastOpened）注册进 tabGroup → **第三标签 = Desktop 复本** |
| B. 抑制窗 1s 过后，迟到的 `newWindowForTab` | `openNewTab(path: path(for: anchor))`；若 key 仍是原 Desktop 或回落逻辑取到 Desktop → 再开 Desktop 标签 |
| C. `openMainWindow` 偶发双实例 / 合并失败的游离窗 | 第二个 ContentView 无 pending → 同样落到 Desktop |
| D. coalesce 只收 **目标目录 SSD** 的重复标签 | Desktop 复本 **永远不会被 SSD coalesce 关掉** → 「有时关有时不关」其实是：关的是 SSD 双开，留下的是 Desktop 第三页 |

因此：第三页路径是 **Desktop 而不是 SSD**，与「pending 被覆盖成无 selection 的 SSD」是不同症状；本复现对应 **A/B/C + D**。

### 2.3 为何「事后 coalesce」治标不治本

```text
tabsOnly coalesce(expected: /Volumes/SSD4T/app)
  → 只合并/关闭 path==SSD 的多余标签
  → Desktop 复本不匹配 → 留下 3 标签
```

依赖延迟关闭 = 闪一下 + 竞态（有时壳已不可关 / 有时关得掉 SSD 双开），**不能从机制上禁止第三页诞生**。

---

## 3. 修改方案（从机制上禁止多余标签）

### 原则

1. **外部 Reveal 跨目录新标签：只允许「一次」窗创建入口**  
2. **新标签路径用类型化 Window 值传递，不依赖易丢的 pending 旁路**  
3. **系统 `newWindowForTab` 在程序化开标签世代内硬拒绝，不只是 close 壳**  
4. **coalesce 降级为断言式兜底，不作为主路径**

### 方案 A（推荐）：Reveal 新标签走 `folder` 场景，不再 `openMainWindow`

```text
deliverOpenRequestInNewTab
  → openNewTab / 或直接 openFolderWindow(
        ExplorerFolderWindowValue(path: targetDir, selectionPath: selection)
     )
  → 合并进 anchor 的 tabGroup（已有 attemptTabMerge / pendingOpen 逻辑可复用）
```

优点：

- SwiftUI `WindowGroup(id:folder, for: Value)` **天然带 path+selection**，无 pending 竞态  
- ContentView `initialPath` / `initialSelectionPath` 首帧就正确  
- 与主场景 `openMainWindow` 解耦，减少「无参主窗 + restoredLaunchPath」双开  

注意：合并后标签场景 kind 可能是 `.folder`；需确认工具栏/会话监视对 `.folder` 与 `.main` 一致（现状多数已同等对待）。

### 方案 B：保留 main，但引入「开标签世代 token」硬门闩

```text
beginProgrammaticTabGeneration(id, expectedFinalTabCount = anchor.tabs + 1)
openMainWindow()
on ContentView.appear / willClose:
  if generation.active && window 不是「唯一合法新窗」→ 禁止 register / 立即 close，禁止落到 restoredLaunchPath
newWindowForTab:
  if generation.active → close shell, return（延长 generation 到 merge 后 1.5～2s，且 merge 成功后再刷新）
endGeneration when: tabCount == expected || timeout
```

优点：改动面小于换 folder 场景。  
缺点：仍与 SwiftUI 无参 WindowGroup 搏斗，要维护世代状态机。

### 方案 C（辅助）：单窗时原地导航，不新开标签（产品可选）

若「仅一个浏览窗且无标签栏」时，外部 Reveal **直接改当前窗 path+selection**，不 `openNewTab`。

- 永远不会出现第三标签  
- 与用户当前「跨目录要新标签」需求冲突 → **仅作可选项 / 设置项**，不做默认，除非产品确认

### 推荐组合

| 优先级 | 项 |
|--------|-----|
| P0 | **方案 A**：Reveal 跨目录用 folder WindowValue 开标签并合并 |
| P0 | **世代门闩**（方案 B 精简版）：程序化开标签期间拒绝一切 `newWindowForTab` / 无名 main 窗的 Desktop 回落 |
| P1 | ContentView：无 pending 且 `isProgrammaticTabGeneration` 时 **禁止** `restoredLaunchPath()`，改为 close self |
| P1 | coalesce：扩展为「同 tabGroup 内，非 keeper 且创建于 generation 窗口的窗一律关」，不只比 SSD path |
| P2 | 诊断：log `newWindowForTab` / `openMainWindow` / ContentView bootstrap 来源（pending / restored / initial） |

---

## 4. 开发计划（任务卡）

### R4-0 诊断加固（0.5h）

- [x] `ExternalOpenDiagnostic`：记录  
  - `openNewTab` / `openMainWindow` / `newWindowForTab` / `merge` / ContentView bootstrap 分支（`pending` \| `restored` \| `initial` \| `launch`）  
  - 每个新窗的 `ObjectIdentifier` 与 register path  
- [ ] 手测一次 Desktop→汽水音乐，用日志确认第三页是 `restored` 还是 `newWindowForTab(Desktop)`

### R4-1 程序化开标签世代门闩（P0，1–2h）

- [x] `ExplorerWindowTabCenter.begin/endProgrammaticTabGeneration`  
- [x] `newWindowForTab`：generation 活跃则只关壳、打日志  
- [x] `ContentView` 主场景 onAppear：若 generation 活跃且本窗不是 pending/folder 目标 → `window.close()`，禁止 `restoredLaunchPath`  
- [x] generation 在 merge 成功后延长 ≥1.5s；超时强制 end  
- [ ] 验收：Desktop 单窗 Reveal → **稳定恰好 2 标签**，连续 10 次无第三页

### R4-2 Reveal 改走 folder WindowValue（P0，2–3h）

- [x] `deliverOpenRequestInNewTab` → `openExternalRevealTab` / folder WindowValue  
- [x] merge 对 folder 新窗写入 selection、激活  
- [ ] 回归：同目录 reuse、冷启动单标签、System/Applications 跨目录  
- [ ] 验收：同上 + 选中汽水音乐 + 新标签激活

### R4-3 coalesce 降级为 generation 兜底（P1，1h）

- [x] `tabsOnly` coalesce 关闭 generation-spurious 窗  
- [x] 不再仅依赖「path == targetDir」才能关 Desktop 复本  
- [ ] 验收：人为制造双开时 0.5s 内收束到 2 标签，且不关原 Desktop 业务标签（keeper = 带 selection 的新标签 + 原 anchor）

### R4-4 文档与回归清单（0.5h）

- [x] 更新本计划实现进度  
- [ ] 手测矩阵：冷启动 / Desktop→SSD / SSD→SSD / SSD→System / 连续 Reveal

---

## 5. 验收标准（本复现）

1. MeoFind 打开 Desktop，无标签栏。  
2. MeoLaunch Reveal 汽水音乐。  
3. **稳定**出现且仅出现 2 个标签：`Desktop` | `/Volumes/SSD4T/app`。  
4. 右侧（或新）标签为 SSD，**已激活**，选中 `汽水音乐.app`。  
5. 连续操作 10 次，无第三标签闪现（允许 &lt;1 帧中间态，最终不得残留）。  
6. `/tmp/meofind-external-open.log` 可见 generation 门闩忽略记录，无连续两次成功 `openNewTab` 指向不同意图。

---

## 6. 非目标

- 不改 MeoLaunch `open -R` 语义。  
- 不默认改为「单窗原地导航」（除非产品单独拍板方案 C）。  
- 不引入第三方库。

---

## 7. 实施顺序建议

```text
R4-0 诊断 → R4-1 世代门闩（最快止血）→ R4-2 folder 传参（机制正解）→ R4-3 兜底 → R4-4 文档
```

若只先做 R4-1，多数 Desktop 第三页可消失；R4-2 从根上去掉「无参 main + restoredLaunchPath」失败模式，建议同一迭代做完 R4-1+R4-2。
