# 文件复制 / 移动进度条 — 设计与开发计划

> 状态：FTP-01 / FTP-02 / FTP-03（加权）已落地；FTP-04 仍可选  
> 关联：`docs/performance-responsiveness-mermaid-paste.md` Phase 13.3（粘贴进度已落地）  
> 目标：拖放与粘贴统一的轻量、实时、低代码量进度体验；不引入新依赖、不明显增大包体。

---

## 0. 现状（基于当前代码）

| 路径 | 实现 | 进度 UI | 线程 |
|------|------|---------|------|
| ⌘V / 菜单 Paste | `FileOperations.paste` → `performFilePaste` | ✅ `PasteOperationCenter` + 底部 `PasteProgressBannerOverlay` | 已 `Task.detached` |
| 列表 / 侧栏拖放 copy·move | `FileOperations.moveItems` | ❌ 无 | **主线程同步** `copyItem`/`moveItem` |
| 重命名 `moveItem(_:toNewName:)` | 单次 rename | 不需要 | 同步即可 |

已有可复用资产（应扩展，勿重造）：

- `Sources/Explorer/Domain/PasteOperationCenter.swift` — 会话 + `@Published` 进度
- `Sources/Explorer/ContentViewObserverIsolation.swift` — `PasteProgressBannerOverlay`（观察隔离，避免刷整棵 ContentView）
- `FileOperations.cancelActivePaste()` + `onChange(of: path)` — 切换目录取消
- 粘贴收尾 `finishPaste` → `insertListingItems` 增量列表

**结论**：用户感知的「从目录 copy/move 多个文件」卡顿，主因是 **拖放仍走同步 `moveItems`**；粘贴已有文件级进度。最优方案是 **统一传输管道 + 复用底部 banner**，而不是再做一套 Finder 式进度窗。

---

## 1. 推荐方案（最优平衡）

### 1.1 一句话

把 `PasteOperationCenter` 升级为通用 **`FileTransferCenter`**，让 `paste` 与 `moveItems` 共用同一套后台 I/O + 文件级（可选按体积加权）进度；UI 继续用现有底部 material banner，仅加取消按钮与 copy/move 文案。

### 1.2 为什么这是本项目最优解

| 候选 | 优点 | 缺点 | 判定 |
|------|------|------|------|
| **A. 扩展现有 Paste 进度（推荐）** | 零新依赖；UI/观察隔离已验证；改动面小 | 单文件大拷贝中途粒度粗（见 1.4） | ✅ |
| B. 自研分块 `FileHandle` 拷贝 | 字节级进度 | 丢 APFS clone、xattr/ACL/资源叉复杂；代码量大；易踩坑 | ❌ |
| C. `copyfile` + `COPYFILE_PROGRESS` | 系统原生、可字节进度 | C 桥接 + 取消语义；同卷 clone 时进度无意义；包体/维护成本上升 | ⏳ Phase 2 可选 |
| D. 调起 Finder / `NSWorkspace` 复制 | 系统进度窗 | 体验割裂、难增量刷新列表、难录制脚本 | ❌ |
| E. 独立进度窗口 / HUD | 像 Finder | 交互重、多窗口状态难、代码多 | ❌ |

### 1.3 进度模型（高效且足够「实时」）

**主模型：按「项」推进（已验证）**

```
completedItems / totalItems + currentFileName
→ 确定进度条（total > 1）或 indeterminate（单文件 / 剪贴板创建）
```

成本：每完成一个 `copyItem`/`moveItem` 一次 `MainActor` 更新；节流可选（见下）。

**增强（低成本，强烈建议一起做）：按体积加权**

1. 开始前对源 URL 做 **浅层** `resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])`（目录先用 0 或仅计直接子项总大小，**不做全树递归**，避免「显示进度前先卡 2 秒」）。
2. `fraction = transferredBytesEstimate / max(estimatedTotal, 1)`。
3. 每完成一项加上该项已知 size；未知 size（目录）按「项数」均分剩余权重。

这样多文件大+小混排时进度更平滑，**仍不需要改 I/O API**。

**刻意不做（Phase 1）**：单个 `copyItem` 内部的字节回调。原因：

- `FileManager.copyItem` 同卷常走 APFS clone，瞬间完成，字节进度无意义；
- 真字节进度要换拷贝实现，复杂度和体积陡增；
- 多文件场景「项进度」已覆盖用户最痛的「卡死感」。

### 1.4 何时显示进度（避免闪一下）

| 条件 | 行为 |
|------|------|
| 同卷 **move**（非 copy），且项数 ≤ 20 | 多数是 rename；可 **不显示 banner**，仅后台化防万一跨目录慢盘 |
| 预估总大小 &lt; 2 MiB 且项数 ≤ 3 | 不显示或仅 &gt;300 ms 后才显示（延迟出现，防闪烁） |
| copy，或跨卷 move，或多文件 | 立即显示 banner |
| 剪贴板创建文件 | 保持现有 indeterminate |

同卷判定：比较 `volumeIdentifier` / `resourceValues(.volumeIdentifierKey)`，失败则按「可能跨卷」处理（偏安全，多显示一次进度）。

### 1.5 线程与取消

```
UI 入口（拖放 / 粘贴）
  → MainActor: begin session + 可选延迟 show
  → Task.detached(priority: .userInitiated) { performTransfer(...) }
       每项：Task.isCancelled? → 停
       onProgress → MainActor 更新 FileTransferCenter（可 50ms 节流）
  → MainActor: finish → Alert(若有错) → recordOperation → completion(增量路径)
```

取消来源（统一 `cancelActiveTransfer()`）：

1. 切换当前路径（已有 `onChange(of: path)`）
2. Banner 上的「取消」按钮（对齐 `OperationRecordingBanner`）
3. 新的传输开始时取消上一次（已有 paste 语义）

**取消粒度**：文件边界（与现 paste 一致）。已完成项保留；未完成项不写半成品（`copyItem` 失败/取消时由系统保证原子性或由我们在 catch 里清理 unique 目标——保持现逻辑即可）。

### 1.6 UI

继续挂在 `ContentView` 底部 overlay，观察隔离不变：

- 文案：`正在复制…` / `正在移动…` / 现有粘贴文案
- 线性 `ProgressView` + 可选「取消」
- 不弹模态、不抢焦点、不挡拖放目标高亮

### 1.7 列表刷新

拖放 `completion` 今日会 `resetTreeState` + `onItemsChanged`（可能偏重）。Phase 1 **先保持现有 completion 契约**，只把 I/O 挪出主线程；Phase 1.5 再对齐粘贴的 `insertListingItems` / invalidation 路径，避免大目录拖放后全量 reload。

---

## 2. 架构改动（最小集合）

```
FileOperations
  ├── paste(...)                    // 改为调用 transfer
  ├── moveItems(..., copy:)         // 改为异步 transfer
  ├── cancelActiveTransfer()        // 原 cancelActivePaste
  └── performTransfer(...)          // 合并 performFilePaste + moveItems 循环

FileTransferCenter (原 PasteOperationCenter)
  └── Kind: creatingFromClipboard | transferring(mode: copy|move, …)

PasteProgressBannerOverlay
  → FileTransferProgressBanner（同文件可 rename）
```

调用方几乎不动签名语义：

- `moveItems(..., completion:)` 改为「启动后台任务，完成后主线程 completion」；
- `FileListView` / `SidebarView` / `FavoritesSidebarDropHandler` **无需改拖放协议**，只需接受「松手后异步完成」。

---

## 3. 明确不做什么（控体积 / 控复杂度）

- 不引入第三方文件传输库  
- 不实现完整 Finder 冲突面板（「停止 / 替换 / 保留两者」逐文件向导）——继续 `uniqueDestinationURL`  
- 不做全树预扫描总字节数  
- Phase 1 不做 `copyfile` 字节进度  
- 不为 trash / emptyTrash 做进度（需求外；模式可复用）

---

## 4. 开发计划（建议 3 个小步）

### FTP-01：统一传输核心 + 拖放后台化（P0，约 0.5–1d）

**做什么**

1. 抽取 `performTransfer(urls:to:mode:onProgress:)`（mode = copy | move）。
2. `moveItems` 改为与 `paste` 相同的 `Task.detached` + `activeTransferTask`。
3. `PasteOperationCenter` 泛化为 `FileTransferCenter`（或保留类名、扩展 Kind，减少 diff 亦可）。
4. 切换目录取消覆盖拖放任务。

**验收**

- 拖放复制 20 个文件 / 单文件约 200 MB：UI 不冻结，列表可滚动。
- 粘贴回归：进度与增量插入行为不变。
- 单元测试：mock 短路径下 progress 回调次数 = 成功项数；cancel 后不再 `completion` 成功收尾（或 completion 带已完成子集，与 paste 一致）。

**触及文件**

- `Sources/Explorer/Domain/FileOperations.swift`
- `Sources/Explorer/Domain/PasteOperationCenter.swift`（rename/扩展）
- `Tests/ExplorerTests/` 新增或扩展传输测试

---

### FTP-02：进度 UI 文案 + 取消 + 显示策略（P0，约 0.5d）

**做什么**

1. i18n：`file.transfer_copy_progress` / `file.transfer_move_progress`（及带文件名变体）；走 xcstrings → `compile_localizations.sh` → L10n + L10nTests。
2. Banner 增加「取消」→ `FileOperations.cancelActiveTransfer()`。
3. 实现 §1.4 延迟显示 / 同卷 move 免打扰。
4. 可选：进度更新 50 ms 节流，避免极多小文件时 SwiftUI 刷新过密。

**验收**

- 中/英界面无键名；取消后 banner 消失且不再写入后续文件。
- 同卷拖移少量小文件不闪 banner（或仅延迟后出现）。

**触及文件**

- `ContentViewObserverIsolation.swift`
- `Localizable.xcstrings` / `L10n.swift` / `L10nTests`
- `ContentView.swift`（cancel 命名对齐）

---

### FTP-03：体积加权进度 + 拖放增量刷新（P1，约 0.5–1d）

**做什么**

1. 浅层 size 预估 + 加权 `progressFraction`。
2. 拖放成功后尽量走与 `finishPaste` 类似的增量插入 / 定向 invalidation，减少大目录全量 reload。
3. 文档：更新本文件状态；在 `performance-responsiveness-mermaid-paste.md` 加一条「拖放传输进度」交叉引用。

**验收**

- 大小不一的多文件拷贝时进度条非匀速「跳文件」感减轻。
- 大目录拖入 1 个文件不触发整表 `isLoading` 闪烁（与粘贴体验对齐）。

---

### FTP-04（可选 Phase 2）：超大单文件字节进度

仅当实测「单文件 &gt; N MB 且跨卷 / 非 clone」仍抱怨无反馈时：

- 对**单文件**且 size &gt; 阈值走 `copyfile` + progress callback；
- 目录与多文件仍用项进度；
- 同卷且 `clonefile` 可用则跳过字节 UI。

默认 **不做**，除非 FTP-01~03 验收后仍不够。

---

## 5. 实施顺序与依赖

```
FTP-01（后台化 + 统一 I/O） ──► FTP-02（UI/取消/i18n）──► FTP-03（加权 + 增量列表）
                                                              │
                                                         FTP-04 可选
```

建议一次 PR 合 FTP-01+02（用户立刻感到「有进度且不卡」）；FTP-03 可跟进。

---

## 6. 风险与对策

| 风险 | 对策 |
|------|------|
| 拖放松手后目标高亮消失、用户以为失败 | Banner 明确「正在复制/移动」；完成后选中新项（若现有 API 支持） |
| 异步 move 期间源列表仍显示已拖文件 | move 成功后依赖现有 `onItemsChanged` / FSEvents；必要时对源 path 立刻从 UI 移除（FTP-03） |
| 错误 Alert 在后台线程 | 所有 `NSAlert` 仅 `@MainActor`（与 paste 一致） |
| 操作录制 | 成功分支仍 `recordOperation(.transferItems)`；取消/部分完成策略与 paste 对齐并写清 |
| 并发两次拖放 | 新任务开始前 `cancelActiveTransfer()`，与粘贴一致 |

---

## 7. 成功标准（产品向）

1. **响应**：任意 copy/move 入口松手或 ⌘V 后 &lt;16 ms 回到可交互（主线程不再跑 `copyItem` 循环）。  
2. **反馈**：超过阈值的操作出现底部进度；可取消。  
3. **体量**：无新 SPM 依赖；新增代码预计 &lt; ~250 行净增（含测试与文案）。  
4. **一致**：粘贴与拖放共用一套 Center + Banner，无第二套进度系统。

---

## 8. 小结

本仓库 **粘贴进度已经做对了方向**（后台 Task + 隔离 Banner + 文件级进度）。最大缺口是 **拖放 `moveItems` 仍同步**。最优解不是重做拷贝引擎，而是 **把拖放接入同一传输管道**，再用浅层体积加权改善观感；真字节进度留作可选 Phase 2。这样实时性、响应、代码量与包体之间最均衡。
