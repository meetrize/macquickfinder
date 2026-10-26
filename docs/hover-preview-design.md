# 悬停预览（Hover Preview）— 交互与架构设计

> 目标：在顶部工具栏「浏览设置」齿轮菜单中增加开关；开启后，鼠标移到文件列表/缩略图项上时，以**轻量、只读、视觉向**的浮动预览展示文件内容，**不**复用侧栏预览的编辑/工具栏/搜索等交互，优先保证响应速度与内存占用。  
> 开发计划见 [hover-preview-plan.md](./hover-preview-plan.md)。  
> 正交于：侧栏 `PreviewSession`、文本编辑、胶片条、独立预览窗（见 `preview-*-design.md`）。

---

## 一、命名

### 1.1 推荐文案

| 场景 | 文案 | 说明 |
|------|------|------|
| **中文（菜单项）** | **悬停预览** | 与「鼠标移上去」语义一致，短、好扫读；避免夹杂 mouseover |
| **英文（菜单项）** | **Hover Preview** | 与 Finder / 业界「hover」习惯一致 |
| 偏好键 / 类型名 | `hoverPreview` / `HoverPreview` | 代码标识 |

### 1.2 备选（不采用默认）

| 文案 | 评价 |
|------|------|
| 悬停即览 | 强调「快、一眼看」，偏产品感；稍不如「悬停预览」直白 |
| 快速悬停预览 | 过长，齿轮菜单不宜 |
| Peek on Hover / Quick Peek | 英文可作副标题或设置说明，主菜单偏生 |
| 鼠标悬停预览 | 正确但啰嗦；「悬停」已含鼠标语境 |

**结论**：UI 用 **悬停预览 / Hover Preview**；文档与类型统一称 **Hover Preview**。

---

## 二、现状与问题

### 2.1 现状

| 能力 | 现状 |
|------|------|
| 列表悬停 | 仅有行高亮（`rowHoverHighlight`），**不**驱动内容预览 |
| 侧栏预览 | 选中驱动 → `FilePreviewSessionHost` → 完整 `PreviewSession` + 编辑/工具栏/搜索/弹出等 |
| 浏览设置菜单 | 仅「自动计算文件夹大小」「使用图标预览」两项 |
| 轻量浮层先例 | `InstantHoverTooltip` / `RailTooltipPresenter`（文字 tooltip，`ignoresMouseEvents`） |

### 2.2 核心约束（本功能必须满足）

1. **速度优先**：悬停切换时，旧加载必须可取消；首帧尽量 < 100–200ms（小图/缓存命中）。
2. **内存可控**：默认关闭；开启后全局**至多一个**悬停预览宿主；有硬上限的解码尺寸与缓存预算。
3. **只读视觉**：无编辑、无预览工具栏、无内容搜索、无弹出/胶片条；面板不抢焦点、不吃鼠标（或仅极窄「固定」例外，首版不做）。
4. **不污染侧栏会话**：悬停**不得**改写当前 `PreviewSession` / 选中态；与右侧面板可同时存在。
5. **与现有悬停共存**：行高亮可继续；与名字 tooltip 冲突时**悬停预览优先**（同文件不叠两层浮层）。

---

## 三、产品交互

### 3.1 入口

- 位置：顶部工具栏最右侧 **浏览设置**（`ToolbarBuiltinID.browseSettingsMenu`）齿轮下拉。
- 形式：与现有两项相同的 **toggle**（`ExplorerToolbarMenuAction` + `isOn`）。
- 默认：**关闭**（零成本；开启才安装/启用悬停预览管线）。
- 可选（Phase 后置）：设置窗口「预览」页同步同一开关；首版仅齿轮菜单即可。

### 3.2 触发与消失

```
鼠标进入可预览文件行/缩略图
  → debounce（默认 180ms，可常量配置）
  → 资格判定（见 §4）
  → 展示/更新 HoverPreview 面板
鼠标移出列表、换到不可预览项、滚轮大幅滚动、开始拖拽、右键菜单、失焦
  → 立即隐藏并 cancel 进行中的加载
选中变化
  → 不强制隐藏（用户可一边悬停一边点选）；换目录则隐藏
```

| 行为 | 约定 |
|------|------|
| Debounce | 防扫过目录时狂加载；常量 `HoverPreviewMetrics.showDelay` |
| 快速划过 | 未到 delay 不发起 IO；已发起则 cancel |
| 目录 / `..` | 不展示内容预览（可后续做「子项计数」轻卡片，首版不做） |
| 不可预览类型 | 不弹层（避免空壳闪烁） |
| 与侧栏同文件 | 仍可弹轻量层（侧栏可能折叠）；或若侧栏已可见且同 URL，可跳过以省内存（**建议首版：侧栏可见且同文件则跳过**） |
| 键盘导航 | **不**跟焦点预览（避免与悬停语义混淆）；仅鼠标悬停 |

### 3.3 面板形态

| 项 | 约定 |
|------|------|
| 载体 | 单个共享 `NSPanel`（参考 `RailTooltipPanel`）：`nonactivatingPanel`、`ignoresMouseEvents = true`、level ≈ floating |
| 位置 | 锚定当前悬停行/缩略图：优先右侧空隙，否则左侧/下方；避开屏幕边缘 |
| 尺寸 | 类型相关上限（见 `HoverPreviewMetrics`）；不跟窗口拖拽缩放（首版固定上限） |
| Chrome | 极简：可选文件名条 + 内容区；**无**工具按钮 |
| 焦点 | 不激活应用、不抢 key window |

---

## 四、适用范围与分级加载

能力门槛与侧栏对齐：`PreviewCapability.canLoadPreview(for:)`。  
**但加载路径必须独立**：走 `HoverPreviewLoader`，**禁止**为悬停新建完整 `PreviewSession`。

### 4.1 分级策略（性能核心）

| Tier | 类型 | 悬停行为 | 说明 |
|------|------|----------|------|
| **A 快路径** | 常见图片（jpg/png/heic/webp/gif/tiff/bmp） | 限尺寸解码 / 复用缩略图管线 | 首选；可走现有 `ThumbnailGenerator` / 限边长 `NSImage` |
| **A′** | QL 图（psd/ai/svg/eps/dxf） | `QLThumbnailGenerator` 单次请求 | 有超时；失败则隐藏或类型占位 |
| **B** | PDF | 仅第 1 页、限分辨率光栅 | 不嵌完整 PDFKit 交互视图 |
| **C** | 文本/代码 | 前 N 字符（如 8–16KB）只读纯文本/轻量 attributed | 无语法高亮（或极简）、无编辑、无搜索 |
| **D** | 音视频 | 静态封面/波形占位 + 时长文案；**不**自动播放、不建 `AVPlayer` | 避免解码器常驻 |
| **E** | Office / EPUB / 压缩包 / 3D / 字体等 | 首版：**元数据卡片**（类型、大小、页数/条目数若廉价可得）或 QL 一帧缩略图 | 禁止完整 Office/3D 会话 |
| **F** | 自定义规则 | 仅当规则模式可映射到 A–C 的轻量路径时预览；否则元数据卡片 | 不跑自定义 script 预览 |

### 4.2 硬性上限（建议常量）

放在 `HoverPreviewMetrics`（新建）：

| 常量 | 建议初值 | 目的 |
|------|----------|------|
| `showDelay` | 180ms | 防扫过 |
| `maxPixelEdge` | 720pt（@2x 按 screen scale） | 解码上限 |
| `maxSourceBytesForFullDecode` | 25MB（图）/ 8MB（文本读入） | 超限走 QL 缩略或截断 |
| `textPreviewMaxBytes` | 16_384 | 文本只读头 |
| `cacheBudgetBytes` | 32–48MB | LRU 解码缓存总预算 |
| `cacheMaxEntries` | 24 | 条目上限 |
| `loadTimeout` | 2.0s | 超时取消并隐藏或占位 |
| `panelMaxSize` | 480×360（逻辑点） | 面板上限 |

超限策略：**降级**（更小缩略图 / 仅图标+元数据），**不**阻塞 UI。

---

## 五、架构

### 5.1 总览

```
FileList hover (table / thumbnail)
  → HoverPreviewController  (debounce / cancel / eligibility)
       → HoverPreviewLoader   (分级、后台 IO、超时)
       → HoverPreviewCache    (URL + mtime/size → 载荷 LRU)
       → HoverPreviewPanel    (单一 NSPanel + 只读 SwiftUI/AppKit 内容)
```

与侧栏关系：

```
选中 → PreviewSession（完整，可编辑）     ← 不变
悬停 → HoverPreview*（轻量，只读）       ← 新增，进程内单例/每窗口一个
```

**每 Explorer 窗口一个 `HoverPreviewController`**（随窗口生命周期），共享可选进程级 `HoverPreviewCache`（带预算）。

### 5.2 关键类型（建议）

| 类型 | 职责 |
|------|------|
| `HoverPreviewController` | 开关、debounce、订阅 hover 行变更、cancel token、呼出/隐藏面板 |
| `HoverPreviewEligibility` | 封装 `canLoadPreview` + 侧栏同文件跳过 + 目录排除 |
| `HoverPreviewLoader` | 按 `PreviewLoadRoute` **子集**映射到 Tier 载荷；`Task` 可取消 |
| `HoverPreviewPayload` | `.image(NSImage)` / `.pdfPage(NSImage)` / `.text(String)` / `.meta(HoverPreviewMeta)` / `.placeholder` |
| `HoverPreviewCache` | LRU + 字节预算；键含 `path + contentModificationDate + fileSize` |
| `HoverPreviewPanel` | NSPanel 宿主；内容用轻量 SwiftUI `HoverPreviewContentView` |
| `HoverPreviewMetrics` | 全部阈值常量 |

### 5.3 与 FileList 的接线

复用现有悬停管道，**不**另造全局鼠标监控：

- 列表：`FileListTableController+RowHover` 的 `updateRowHover` 成功解析行后，回调 `onHoverItemChange: ((FileItem?) -> Void)?`
- 缩略图：`FileListThumbnailController` / cell `mouseEntered` 同源回调
- 清除悬停时传 `nil`

Explorer 侧在组装 FileList 时注入；开关关闭时回调 no-op 或不注册，避免无谓开销。

### 5.4 明确不做（首版）

- 悬停预览内编辑、裁剪、保存、搜索、语法高亮全量
- 悬停自动播放音视频
- 悬停打开完整 PDF/Office/3D 引擎
- 修改当前选中或侧栏 `PreviewSession`
- 多面板同时显示多个悬停预览
- 触控板 Force Touch / 空格 Quick Look 替代（可后续对齐）

---

## 六、偏好与 i18n

### 6.1 偏好

```swift
// AppPreferences.Preview
static let hoverPreviewEnabled = "preview.hoverPreviewEnabled"  // 默认 false
```

- `@AppStorage` + `ExplorerToolbarEnvironment` 增加 `hoverPreviewEnabled` / `toggleHoverPreview`
- `browseSettingsMenuActions` 增加第三项 toggle
- 关闭瞬间：`HoverPreviewController.shutdown()`（隐藏面板、取消 Task、可不清缓存）

### 6.2 文案键（须走 i18n 全流程）

| Key | en | zh-Hans |
|-----|----|---------|
| `toolbar.hover_preview` | Hover Preview | 悬停预览 |

写入 `Localizable.xcstrings` → `L10n.Toolbar.hoverPreview` → **必须** `bash Scripts/compile_localizations.sh`。

---

## 七、性能与内存守则（实现红线）

1. **默认关**：关时零面板、零 hover 回调副作用、零缓存增长。
2. **单面板**：全局每窗最多一个 `HoverPreviewPanel` 实例。
3. **可取消**：每次目标变更 `loadGeneration += 1`；过期结果丢弃。
4. **主线程只做组装**：解码/读文件在后台；主线程仅赋值 `NSImage` / 字符串。
5. **禁止**悬停路径调用 `PreviewSession.beginLoad` / `FilePreviewSessionHost`。
6. **媒体不建 Player**；Office/3D 不走完整 loader。
7. **缓存有预算**：超预算 LRU 淘汰；目录切换可 `cache.trimToHalf()`（可选）。
8. **与图标预览分工**：`useIconPreview` 管列表缩略图；悬停预览管「放大只读 peek」，可复用缩略图像素作占位再升级。

---

## 八、测试要点

| 类型 | 用例 |
|------|------|
| 单元 | Eligibility、Cache LRU/预算、Loader 截断/超限降级、cancel 丢弃过期结果 |
| 单元 | 偏好默认 false；toggle 写入 UserDefaults |
| 手动 | 快速扫过 100 文件：CPU/内存无明显爬升；松手停在一文件后快速出图 |
| 手动 | 开侧栏预览同文件：按设计跳过或仍轻量（与 §3.2 一致） |
| 手动 | 开关关闭后无面板残留、无泄漏 Task |
| 手动 | 列表 + 缩略图模式均可用；右键菜单时面板消失 |

---

## 九、风险与缓解

| 风险 | 缓解 |
|------|------|
| 复用 `PreviewSession` 导致内存爆 | 架构红线：独立 Loader；Code Review 拒 PR |
| HEIC/大图主线程卡顿 | 限边长 + 后台 + 超时 |
| 与 tooltip 叠层 | 同锚点互斥；预览显示时隐藏名字 tooltip |
| QL 首次慢 | Tier 占位图标 → 异步替换；超时降级 meta |
| 用户期望「和侧栏一模一样」 | 文案/设置说明可后续加副标题「仅视觉预览」；功能上坚持轻量 |

---

## 十、文档与规则索引

| 文档 | 用途 |
|------|------|
| 本文 | 交互与架构 |
| [hover-preview-plan.md](./hover-preview-plan.md) | 分阶段 Issue |
| `.cursor/rules/hover-preview-plan.mdc` | 实现时约束索引 |
| [toolbar-customization-design.md](./toolbar-customization-design.md) | 齿轮菜单位置 |
| [preview-tier1-plan.md](./preview-tier1-plan.md) | 侧栏七层管线（勿混用） |
