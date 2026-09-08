# 外部 Reveal 日志分析（2026-09-08 `/tmp/meofind-external-open.log`）

## 用户现象

1. 会开出「新标签」，但**未立刻激活**，前台仍停在旧标签（如 `/tmp`、Desktop）。
2. 新标签路径不对（仍是旧目录 `/tmp` 等），且出现**多个**同类标签。
3. 独立新窗口已基本消失（较前一轮好转）。

## 日志时间线（节选）

### A. 跨目录本应新标签（Desktop → SSD）— 早期一次成功合并

```text
windowShowingDirectory miss … paths=[/Users/meetrice/Desktop]
requestOpen warm-new-tab from=Desktop to=/Volumes/SSD4T/app
tab-generation begin preexisting=2 paths=[Desktop, nil]   ← 已有多余壳
openExternalRevealTab folder-value …
ContentView bootstrap=initial path=/Volumes/SSD4T/app …  ← 正确
tab-generation merged …
coalesce close generation-spurious path=nil
```

说明：路由正确；但世代开始前已有 `nil` 壳，系统仍爱叠页。

### B. 同目录复用（正常）

```text
requestOpen warm-reuse-tab dir=/Volumes/SSD4T/app selection=…DbGate.app
ContentView apply external selection …
```

### C. 故障主形态（09:26–09:28）— 与用户描述一致

```text
ContentView bootstrap=restored path=/Users/meetrice/Desktop   ← ×2，在 application(open:) 之前
ContentView bootstrap=restored path=/tmp                      ← ×2
application(open:) …DbGate.app / Excel.app
requestOpen warm-reuse-tab dir=/Volumes/SSD4T/app
close detached duplicate window path=/Volumes/SSD4T/app
ContentView apply external selection …
```

要点：

| 观察 | 含义 |
|------|------|
| `bootstrap=restored` **早于** `application(open:)` | AppKit/SwiftUI 在投递 URL 前又造了 **无参 main 窗**，落到 `restoredLaunchPath`（Desktop/`/tmp`） |
| 成对出现（×2） | 双开 main，或两个标签几乎同时 onAppear |
| 无 `bootstrap=rejected-restored` | `shouldRejectSurplusRestoredMainWindow` **未拦住**（见根因 1） |
| 前台是 Desktop/`/tmp` 却走 `warm-reuse-tab` | 注册表里仍有 SSD 窗（常为 **另一标签组 / `.disallowed` 幽灵窗**） |
| `close detached duplicate window path=SSD` | 复用到「错误 keeper」后，可能把**正确标签组里的 SSD 标签**当成游离复本关掉 |
| `apply external selection` 有日志 | 选中打到 keeper 的 ContentView，但用户眼睛仍在 **restored 出来的旧目录标签** 上 →「没激活 / 没跳目录」 |

## 根因归纳

### 根因 1 — 多余 `restored` 主窗未被拒绝

`shouldRejectSurplusRestoredMainWindow` 在 `pendingNewTab != nil || pendingOpen != nil` 时 **直接 return false**，允许 `restoredLaunchPath` 落地。  
遗留的 ⌘N `pendingOpen`、或开标签瞬间的 `pendingNewTab`，都会放行 Desktop/`/tmp` 复本。  
这些复本成为「新标签 / 多标签」，且常保持选中，造成现象 1+2。

### 根因 2 — `warm-reuse` 锚点偏好错误

`windowShowingDirectory` 未优先「当前前台标签组」。  
若 SSD 只存在于背后独立窗，会 reuse 该窗并 `closeDetached*`；在 `external-open suppression` 下还可能误伤前台 `/tmp` 组，或反过来关掉组内真 SSD、留下 restored 页。

### 根因 3 — 激活未钉在「用户正在看的窗口」

即便 `apply selection` 成功，若 selected/key 仍是 restored 的 `/tmp` 标签，用户只会看到旧目录。  
合并/复用后缺少「以锚点标签组为准」的强制 `selectedWindow` + 关掉同拍 surplus。

## 修复策略（对应实现）

1. **诊断**：`requestOpen` / bootstrap / activate 打窗口快照（path、tabGroup、selected、key、tabbingMode）。
2. **拒绝 restored**：会话已建立或已有可见浏览窗时，无 `initialPath`/`pending` 的 bootstrap **一律 reject+close**；去掉 `pendingOpen` 放行。
3. **复用范围**：只 reuse **当前前台锚点所在 tabGroup** 内的同目录标签；其它组的同路径窗视为 orphan → 关闭后在锚点 **新开标签**（I3），避免背后幽灵窗。
4. **激活**：reuse/new-tab 后反复确认 `tabGroup.selectedWindow` + `makeKeyAndOrderFront`，并 coalesce 掉 restored 复本。

## 验收

1. 单窗停在 `/tmp` → Reveal SSD 应用 → **恰好多 1 个** SSD 标签且 **立刻选中**，列表为 `/Volumes/SSD4T/app` 并选中 app。  
2. 再 Reveal 同目录另一 app → **不**新标签，仅改选中。  
3. 日志应出现 `bootstrap=rejected-restored` 或不再出现成对的 `bootstrap=restored` 抢在 `application(open:)` 前；跨组应出现 `orphan-elsewhere → warm-new-tab`。
