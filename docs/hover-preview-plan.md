# 悬停预览（Hover Preview）— 开发计划

> 依据：[hover-preview-design.md](./hover-preview-design.md)  
> 目标：HP-01 ~ HP-12 落地「浏览设置 → 悬停预览」开关 + 轻量只读浮动预览；**速度与内存优先**，不复用完整 `PreviewSession`。

---

## 总览

| Phase | 主题 | Issue | 预估 | 用户可见 |
|-------|------|-------|------|----------|
| **P0** | 开关、文案、接线骨架 | HP-01 ~ HP-03 | 0.5–1 天 | 菜单有开关（尚无预览） |
| **P1** | 面板 + 图/PDF/文本快路径 | HP-04 ~ HP-08 | 2–3 天 | 主路径可用 |
| **P2** | 缓存、降级、缩略图模式、打磨 | HP-09 ~ HP-12 | 1–2 天 | 性能达标 |

原则：每完成一 Issue 勾选；P1 未完成前不引入 AVPlayer / 完整 Office / 3D。

---

## P0：开关与骨架

### HP-01：偏好键 + Toolbar 菜单项 + i18n

**类型**：feat  
**依赖**：无  
**文件**：

- `Sources/Explorer/Preferences/AppPreferences.swift`（`Preview.hoverPreviewEnabled`）
- `Sources/Explorer/Toolbar/ExplorerToolbarEnvironment.swift`
- `Sources/Explorer/Toolbar/ExplorerToolbarItemViews.swift`（`browseSettingsMenuActions`）
- `Sources/Explorer/Resources/Localizable.xcstrings` + `L10n.swift`
- 运行 `bash Scripts/compile_localizations.sh`
- `Tests/ExplorerTests/L10nTests.swift`

**任务**：

- [x] 新增 `AppPreferences.Preview.hoverPreviewEnabled`（默认 `false`）
- [x] Environment：`hoverPreviewEnabled` + `toggleHoverPreview`
- [x] 齿轮菜单第三项：`L10n.Toolbar.hoverPreview`（en: Hover Preview / zh-Hans: 悬停预览）
- [x] i18n 全流程（xcstrings → compile → `.lproj` → L10nTests）

**验收**：

- 菜单可见 toggle，重启后状态保持
- 界面显示「悬停预览」而非键名

---

### HP-02：HoverPreviewMetrics + Payload / Eligibility 纯逻辑

**类型**：feat  
**依赖**：无（可与 HP-01 并行）  
**文件**：

- `Sources/Explorer/Preview/Hover/HoverPreviewMetrics.swift`（新建）
- `Sources/Explorer/Preview/Hover/HoverPreviewPayload.swift`（新建）
- `Sources/Explorer/Preview/Hover/HoverPreviewEligibility.swift`（新建）
- `Tests/ExplorerTests/HoverPreviewEligibilityTests.swift`

**任务**：

- [x] 落地设计文档中的常量（delay、尺寸、字节、缓存预算、超时）
- [x] `HoverPreviewPayload` 枚举（image / pdfPage / text / meta / placeholder）
- [x] `HoverPreviewEligibility.shouldShow(for:rightPanelVisible:rightPanelURL:)`：目录/`..` 排除；`canLoadPreview`；侧栏同文件跳过

**验收**：

- 单测覆盖：目录 false、未知扩展 false、可预览 true、同 URL + 侧栏可见 → false

---

### HP-03：FileList 悬停回调钩子（无 UI）

**类型**：feat  
**依赖**：无  
**文件**：

- `Sources/FileList/FileListTableController+RowHover.swift`（及对外 API）
- `Sources/FileList/Thumbnail/…`（缩略图同源回调）
- Explorer 组装处（ContentView / FileList host）预留 `onHoverItemChange`

**任务**：

- [x] 行悬停解析出 `FileItem?` 时回调（含 `nil` 清除）
- [x] 缩略图模式同等回调
- [x] 开关关闭时 Explorer 不订阅或 no-op（零额外工作）

**验收**：

- 调试日志/测试桩可观察到 enter/leave；不影响现有行高亮

---

## P1：轻量面板与主路径加载

### HP-04：HoverPreviewPanel（单一 NSPanel）

**类型**：feat  
**依赖**：HP-02  
**文件**：

- `Sources/Explorer/Preview/Hover/HoverPreviewPanel.swift`（新建）
- `Sources/Explorer/Preview/Hover/HoverPreviewContentView.swift`（新建）

**任务**：

- [x] 参考 `RailTooltipPanel`：`nonactivatingPanel`、`ignoresMouseEvents`、floating、避边
- [x] `present(payload:anchor:fileName:)` / `dismiss()`
- [x] 内容：只读 Image / 文本 Scroll（只读）/ Meta 卡片；**无**工具栏按钮
- [x] 右键 / `NSMenu.didBeginTracking` 时 dismiss（可复用 tooltip 抑制思路）

**验收**：

- 面板不抢焦点；鼠标可穿透；菜单弹出时消失

---

### HP-05：HoverPreviewLoader（可取消）+ 图片 Tier A/A′

**类型**：feat  
**依赖**：HP-02  
**文件**：

- `Sources/Explorer/Preview/Hover/HoverPreviewLoader.swift`（新建）
- `Tests/ExplorerTests/HoverPreviewLoaderTests.swift`

**任务**：

- [x] `load(item:generation:) async -> Payload?`；generation 过期丢弃
- [x] 图片：限边长解码；超 `maxSourceBytes` 走 `QLThumbnailGenerator`
- [x] 超时 `loadTimeout` → nil 或 placeholder
- [x] **禁止**调用 `PreviewSession`

**验收**：

- 快速连续 load 10 次仅最后一次结果生效
- 大图不炸内存（边长受限）

---

### HP-06：HoverPreviewController 串联

**类型**：feat  
**依赖**：HP-01, HP-03, HP-04, HP-05  
**文件**：

- `Sources/Explorer/Preview/Hover/HoverPreviewController.swift`（新建）
- 窗口 / ContentView 生命周期挂载

**任务**：

- [x] debounce `showDelay` 后 load → present
- [x] 目标变更 / leave → cancel + dismiss
- [x] 开关 off → `shutdown()`
- [x] 传入侧栏可见性与当前预览 URL 供 Eligibility

**验收**：

- 扫过目录无明显卡顿；停稳后出预览；关开关无残留

---

### HP-07：PDF 第一页 + 文本头 Tier B/C

**类型**：feat  
**依赖**：HP-05  
**文件**：

- `HoverPreviewLoader.swift` 扩展
- 测试：截断长度、PDF 首页

**任务**：

- [x] PDF：仅渲染第 1 页到限尺寸位图（PDFKit 短生命周期，用完释放）
- [x] 文本：读前 `textPreviewMaxBytes`，UTF-8 容错；纯文本展示
- [x] 超大文本不读全文件（`FileHandle` / 限长 read）

**验收**：

- 打开大日志文件悬停：内存增量有界、UI 不卡死

---

### HP-08：媒体 / 重类型 Meta 降级（Tier D/E）

**类型**：feat  
**依赖**：HP-05  
**文件**：

- `HoverPreviewLoader.swift`、`HoverPreviewPayload.meta`

**任务**：

- [x] 音视频：不创建 `AVPlayer`；图标 + 文件名 + 大小（时长若廉价可得可加）
- [x] Office / 压缩包 / 3D / 字体等：Meta 或单帧 QL 缩略（失败则 Meta）
- [x] 自定义规则：仅映射到轻量路径，否则 Meta

**验收**：

- 悬停 mp4/docx 不出现持续解码占用；面板有可读信息

---

## P2：缓存与打磨

### HP-09：HoverPreviewCache（LRU + 预算）

**类型**：perf  
**依赖**：HP-05  
**文件**：

- `Sources/Explorer/Preview/Hover/HoverPreviewCache.swift`（新建）
- `Tests/ExplorerTests/HoverPreviewCacheTests.swift`

**任务**：

- [x] 键：`path + mtime + size`
- [x] 字节预算 + max entries；超限淘汰
- [x] Loader 先查缓存；命中跳过 IO

**验收**：

- 来回悬停同一批图：第二次显著更快；预算测试通过

---

### HP-10：缩略图模式锚点与占位升级

**类型**：feat  
**依赖**：HP-06  
**文件**：

- Thumbnail hover 锚点 view
- Controller：若列表已有缩略图像素，可先 present 再升级高清

**任务**：

- [x] 缩略图视图模式位置正确
- [ ] 可选：低清占位 → 高清替换（同 generation）（首版用 placeholder ProgressView，未做缩略图像素升级）

**验收**：

- 列表/缩略图两种模式体验一致

---

### HP-11：与 InstantHoverTooltip 互斥 + 滚动/拖拽 dismiss

**类型**：fix  
**依赖**：HP-06  
**文件**：

- Hover 控制器与 tooltip presenter 协调
- 滚动 / 拖拽开始时 dismiss

**任务**：

- [x] 悬停预览显示时隐藏同锚点名字 tooltip
- [x] `scrollWheel` / 右键菜单 → dismiss + cancel（拖拽 dismiss 钩子已预留 `notifyDragOrScrollBegan`，可后续接到 drag session）

**验收**：

- 无双浮层；拖拽文件时面板不粘住

---

### HP-12：性能自检清单与文档收尾

**类型**：chore  
**依赖**：P1+P2 主路径  
**文件**：

- 更新 `hover-preview-design.md` 若有偏差
- 勾选本计划；必要时 Settings 页同步开关（可选，标记 wontfix 若不做）

**任务**：

- [ ] Instruments 抽查：开启后空闲内存接近关闭态；扫过目录无 unbounded growth（需本机手动）
- [x] 确认无 `PreviewSession` 引用从 Hover 目录发出
- [x] 单元测试已添加 Eligibility / Cache；CLI 环境无完整 Xcode，`swift test` 不可用

**验收**：

- 设计红线全部满足；本计划 Issue 勾选完毕

---

## 依赖关系（简图）

```
HP-01 ─┐
HP-02 ─┼─→ HP-04 ─┐
HP-03 ─┘          ├─→ HP-06 ─→ HP-10 / HP-11 ─→ HP-12
HP-05 ────────────┘       ↑
         HP-07 / HP-08 ───┘
         HP-09（可与 HP-07 并行，在 HP-05 后）
```

---

## 非目标（本计划明确排除）

- 悬停编辑、侧栏工具栏镜像
- 空格键 Quick Look 系统面板替代
- 多文件 Contact Sheet 悬停
- 强制把所有类型做到与侧栏同画质

---

## 完成定义（DoD）

1. 浏览设置中「悬停预览」可开关，默认关。  
2. 开启后悬停可预览文件出现只读浮层；关闭后零残留。  
3. 实现位于 `Preview/Hover/`，**不**经 `PreviewSession`。  
4. i18n 已 compile；相关单测通过。  
5. 快速扫目录不明显卡顿；缓存有预算。  
