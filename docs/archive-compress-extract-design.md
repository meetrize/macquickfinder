# 压缩 / 解压 — 交互与实现设计方案

> 目标：为 MeoFind（macquickfinder）补齐 **压缩** 与 **解压** 能力，交互对齐 Finder 心智模型，并发挥本应用 **归档预览 + 输出面板** 的差异化优势。  
> 本文档基于 2026-06 代码库现状编写，可直接拆分为开发 Plan。

---

## 一、背景与产品定位

### 1.1 现状

| 能力 | 现状 | 相关文件 |
|------|------|----------|
| 归档预览（只读） | 支持 `zip` / `tar` / `tar.gz` / `tgz` 列目录；`bsdtar` + `ShellProcessRunner` | `ArchivePreviewLoader.swift`、`ArchiveListPreview.swift` |
| 预览工具栏 | 刷新目录、展开/折叠、复制清单 | `PreviewSession+ToolbarArchive.swift` |
| 文件操作 | 剪切/复制/粘贴/删除/重命名/属性 | `FileOperations.swift`、`FileContextActions.swift` |
| 长任务执行 | 输出面板 + `JobStore` 流式 stdout/stderr、可取消 | `JobStore.swift`、`ShellRunner.swift` |
| 网络卷策略 | 非本地卷跳过重 I/O、预览预取克制 | `DirectorySizeVolumeFilter.swift` |
| 压缩/解压操作 | **尚未实现** | — |

### 1.2 设计原则

1. **Finder 优先**：默认路径零对话框、零选项，用户右键即可完成最常见操作。
2. **预览增强**：用户已在右侧看到归档内容时，应能 **一键解压**，不必回到列表再找右键。
3. **重活走输出面板**：大文件/慢盘/网络卷操作自动落到输出面板，可查看日志、可取消——这是相对 Finder Archive Utility 的明确优势。
4. **不内置第三方解析库**：首版统一走系统 `tar`（`bsdtar`）与 `ditto`；`rar`/`7z` 仅做「有工具则支持」的探测扩展。
5. **主线程不阻塞**：与 `preview-toolbar-rollout.md` 性能红线一致，所有归档读写走后台任务。

### 1.3 非目标（首版）

- 压缩包内单文件 **预览内容**（已有 roadmap 明确不做）
- 加密 ZIP 创建 / 密码解压
- 分卷压缩（`.zip.001`）
- 内置 `7z`/`unrar` 二进制
- 将归档当作虚拟文件系统浏览（不实现 FUSE / 挂载层）

---

## 二、用户场景与入口设计

### 2.1 场景矩阵

| 场景 | 用户意图 | 最优入口 | 默认行为 |
|------|----------|----------|----------|
| 选中 1 个文件/文件夹 | 打成 zip 分享 | 右键 **压缩「xxx」** | 同目录生成 `xxx.zip` |
| 选中多个项目 | 打包发送 | 右键 **压缩 N 个项目** | 同目录生成 `Archive.zip` |
| 选中 1 个 zip/tar/tgz | 解包到当前文件夹 | 右键 **解压到此处** | 解压到归档所在目录 |
| 选中归档，想指定目录 | 解包到其他位置 | 右键 **解压到…** | `NSOpenPanel` 选文件夹 |
| 预览区已打开归档 | 边看边解 | 预览工具栏 **解压** | 同「解压到此处」 |
| 大归档 / 网络卷 | 需要进度与取消 | 自动打开输出面板 | 流式日志 + 终止按钮 |
| 废纸篓内 | — | **禁用** 压缩与解压 | — |

### 2.2 入口总览

```
┌─ 文件列表右键（主入口）────────────────────────────────────────┐
│  打开 / 打开方式 / …                                              │
│  剪切 / 复制                                                      │
│  ─────────                                                       │
│  [压缩「foo」]  或  [压缩 3 个项目]     ← 选中含非归档文件时显示   │
│  [解压 ▶] 解压到此处 / 解压到… / 解压到「下载」  ← 选中归档时显示   │
│  ─────────                                                       │
│  删除 / 重命名 / …                                                │
└──────────────────────────────────────────────────────────────────┘

┌─ 归档预览工具栏（差异化入口）────────────────────────────────────┐
│  [刷新] [展开] [复制清单] | [解压] [解压到…]                      │
└──────────────────────────────────────────────────────────────────┘

┌─ 应用菜单（可选 Phase 2）─────────────────────────────────────────┐
│  文件 ▸ 压缩所选项目        ⌃⌘C（待定，设置可改）                  │
│  文件 ▸ 解压                  （仅当选中归档时启用）                 │
└──────────────────────────────────────────────────────────────────┘
```

**为何不在空白处右键加入口？** 压缩/解压的对象必须是「选中项」，与 Finder 一致；空白菜单保持轻量（粘贴 / 新建）。

**为何不放进 Snippets 首版？** Snippets 适合高级用户自定义；核心文件操作应零配置可用。Phase 2 可提供内置 Snippet 模板（`tar -czf %o %F` 等）。

---

## 三、交互细节

### 3.1 压缩

#### 3.1.1 菜单文案（i18n 键建议）

| 条件 | 中文 | 英文 |
|------|------|------|
| 单选 | 压缩「%@」 | Compress "%@" |
| 多选 | 压缩 %d 个项目 | Compress %d Items |

#### 3.1.2 输出命名（对齐 Finder）

| 选中 | 默认归档名 | 冲突处理 |
|------|------------|----------|
| 1 项 `readme.txt` | `readme.txt.zip` | `readme.txt 2.zip` … |
| 1 项文件夹 `Project` | `Project.zip` | `Project 2.zip` … |
| N 项（N≥2） | `Archive.zip` | `Archive 2.zip` … |

复用 `FileOperations.uniqueDestinationURL` 的「递增序号」策略。

#### 3.1.3 格式与命令（首版）

| 格式 | 创建 | 说明 |
|------|------|------|
| **ZIP** | 默认且唯一 | `ditto -c -k --keepParent <items...> <dest.zip>` |

**为何用 `ditto` 而非 `zip`？**

- macOS 自带，Unicode / 资源分叉 / 包内容处理与 Finder 更接近。
- 多选时：`ditto -c -k --keepParent item1 item2 … Archive.zip`。
- 单文件夹：`--keepParent` 保留顶层目录名（与 Finder「压缩文件夹」一致）。

**Phase 2 可选格式**（放入「压缩选项…」Sheet）：

| 格式 | 命令草图 |
|------|----------|
| `.tar.gz` | `tar -czf out.tgz -C parent item` |
| `.tar` | `tar -cf out.tar …` |

首版 **不提供** 格式选择 UI，避免选择疲劳。

#### 3.1.4 压缩过程 UX

```
用户点击「压缩」
    │
    ├─ 估算体量 < 32 MB 且本地卷 ──► 后台 Task，列表顶部状态条「正在压缩…」
    │                                 完成后刷新目录、选中新建的 .zip
    │
    └─ 否则 ──► 自动展开输出面板，创建 Job「压缩 xxx」
                流式输出 ditto stderr（若有）
                成功：✓ + 刷新 + 选中结果；失败：✗ + NSAlert
```

阈值 `32 MB` 写入 `AppPreferences`，可后续在设置中调整。

#### 3.1.5 禁用条件

- 当前路径在废纸篓（`TrashLoader.isTrashPath`）
- 选中项包含「返回上层」伪项
- 选中项任一路径不可读 / 正在执行同类任务
- 网络卷：**不禁止**，但强制走输出面板并显示「网络卷操作可能较慢」提示（与远程设计方案一致）

---

### 3.2 解压

#### 3.2.1 右键子菜单

```
解压 ▶
  解压到此处          ← 默认项，无对话框
  解压到…             ← NSOpenPanel（仅文件夹、可创建）
  解压到「下载」       ← ~/Downloads，固定快捷项
```

**「解压到此处」目标路径规则：**

- 归档在 `/path/to/foo.zip` → 解压到 `/path/to/`
- 若已存在同名文件夹 `foo/`（去掉 `.zip` 后的 stem），则解压到 `foo 2/`、`foo 3/` …（与 Finder 行为一致，避免覆盖）

**多选归档：** 依次解压，每个归档各自生成目标目录；全部放入 **一个** 输出面板 Job（日志分段）。

#### 3.2.2 支持格式（首版）

| 扩展名 | 解压命令 | 备注 |
|--------|----------|------|
| `.zip` | `tar -xf 'archive.zip' -C 'dest'` | 与预览共用 `bsdtar` |
| `.tar` | 同上 | |
| `.tar.gz` / `.tgz` | 同上 | |
| `.gz`（单文件） | Phase 2 | 非 tar 包裹的裸 gzip |
| `.rar` / `.7z` | Phase 2：`unar` 探测 | 与预览 roadmap 一致 |

**加密归档：** 首版检测失败后提示「不支持加密压缩包」；不做密码框。

#### 3.2.3 预览工具栏扩展

在现有 `previewArchiveToolbarItems()` 末尾增加：

| 按钮 | 行为 |
|------|------|
| 解压 | 对 **当前预览的归档文件** 执行「解压到此处」 |
| 解压到… | 打开文件夹选择面板 |

**上下文绑定：** `PreviewSession` 已持有当前 `FileItem` URL，无需列表再选中。

**Phase 2 增强（差异化）：**

- 归档列表支持多选（⌘ 点击）
- 工具栏「解压选中项」→ `tar -xf archive.zip -C dest path1 path2 …`
- 选中项高亮与 `ArchiveListPreview` 联动

首版预览区 **不做行级多选**，仅「整包解压」。

#### 3.2.4 解压后导航（可选增强）

设置项「解压完成后」：

| 选项 | 行为 |
|------|------|
| 保持当前目录（默认） | 仅刷新列表 |
| 进入解压目录 | `path` 切换到新文件夹 |
| 在列表中选中解压目录 | 不跳转，但 `selection` 指向新目录 |

首版实现 **保持当前目录 + 刷新 + 选中解压产物** 即可。

---

### 3.3 与现有能力的衔接

| 模块 | 衔接方式 |
|------|----------|
| **归档预览** | 解压后若预览仍打开同一 zip，工具栏「刷新目录」可提示「文件已变更」并自动 reload |
| **输出面板** | `JobSource.archiveOperation`；显示友好命令摘要而非完整 shell |
| **FSEvents** | 本地卷解压完成后目录监听自动刷新；网络卷靠手动刷新 |
| **帮助速查** | `help.entry.compress` / `help.entry.extract` 写入 HelpCheatSheet |
| **缩略图类型** | 已有 `.archive` tint，无需改动 |
| **系统服务菜单** | 保留 `FileServicesMenuSupport`；不拦截系统「压缩」服务 |

---

## 四、架构设计

### 4.1 模块划分

```
┌─────────────────────────────────────────────────────────────┐
│ UI 层                                                        │
│  FileListRowContextMenuBuilder  ──► 压缩/解压菜单项          │
│  PreviewSession+ToolbarArchive    ──► 预览工具栏按钮          │
│  ArchiveExtractPanel              ──► 「解压到…」NSOpenPanel  │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│  ArchiveOperations（新建，Domain 层）                          │
│  - canCompress(items:) / canExtract(items:)                  │
│  - compress(items:, destinationDirectory:)                   │
│  - extract(archives:, destinationDirectory:, mode:)          │
│  - defaultArchiveName(for:) / defaultExtractDirectory(for:)  │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│  ArchiveCommandBuilder（新建）                                 │
│  - makeCompressCommand(items:dest:) → String                 │
│  - makeExtractCommand(archive:dest:members:) → String        │
│  复用 ShellQuoting.singleQuote                               │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│  ArchiveTaskRunner（新建）                                     │
│  - 小任务：async Task + MainActor 完成回调                    │
│  - 大任务：JobStore.createJob + Process 流式输出              │
│  - 取消：process.terminate()                                 │
│  参考 ShellRunner / ShellProcessRunner                       │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 核心 API 草图

```swift
enum ArchiveExtractMode: Equatable {
    case here              // 归档同目录
    case destination(URL)  // 用户指定
    case downloads         // ~/Downloads
}

enum ArchiveOperations {
    static func isArchive(_ item: FileItem) -> Bool
    static func canCompress(_ items: [FileItem], inTrash: Bool) -> Bool
    static func canExtract(_ items: [FileItem], inTrash: Bool) -> Bool

    static func compress(
        items: [FileItem],
        in directory: URL,
        onComplete: @escaping (Result<URL, Error>) -> Void
    )

    static func extract(
        archives: [FileItem],
        mode: ArchiveExtractMode,
        onComplete: @escaping (Result<[URL], Error>) -> Void
    )
}
```

### 4.3 `FileContextActions` 扩展

```swift
struct FileContextActions {
    // … 现有字段 …
    var compress: ([FileItem]) -> Void = { _ in }
    var extractHere: ([FileItem]) -> Void = { _ in }
    var extractTo: ([FileItem]) -> Void = { _ in }
    var extractToDownloads: ([FileItem]) -> Void = { _ in }
    var canCompress: ([FileItem]) -> Bool = { _ in false }
    var canExtract: ([FileItem]) -> Bool = { _ in false }
}
```

菜单构建逻辑：

- `canCompress` 且选中项 **不全是** 归档 → 显示压缩
- `canExtract` 且选中项 **全是** 归档 → 显示解压子菜单
- 混合选中（文件 + 归档）：**仅显示压缩**（将归档当作普通文件打入 zip）；不解压——避免歧义

### 4.4 命令示例

**压缩（多选）：**

```bash
/usr/bin/ditto -c -k --keepParent \
  '/path/a' '/path/b.txt' \
  '/path/Archive.zip'
```

**解压到此处（含重名目录避让）：**

```bash
mkdir -p '/path/to/foo 2' && \
/usr/bin/tar -xf '/path/to/foo.zip' -C '/path/to/foo 2'
```

> 实现时：先计算 `destinationDirectory`（`uniqueExtractDirectory`），再 `mkdir -p` + `tar -xf`。

**路径转义：** 统一 `ShellQuoting.singleQuote`，与 `ArchivePreviewLoader` / `SnippetExpander` 一致。

### 4.5 Job 与进度

| 字段 | 值 |
|------|-----|
| `JobSource` | 新增 `.archiveOperation` |
| `snippetName` | `L10n.Archive.jobCompress` / `jobExtract` |
| `displayCommand` | `压缩 foo.zip` / `解压 bar.tar.gz → /dest` |
| `workingDirectory` | 归档所在父目录 |

**进程选择：**

- 小任务可用 `ShellProcessRunner`（简单、有超时）
- 大任务用 `Process` + `ProcessOutputStreamer`（与 `ShellRunner` 相同管道），**不设短超时**

**完成回调：**

```swift
onComplete: {
    loadItems(invalidatingPaths: ...)
    selection = [newItem.id]
}
```

---

## 五、错误处理

| 情况 | 用户可见反馈 |
|------|--------------|
| 磁盘空间不足 | NSAlert + 输出面板 stderr |
| 归档损坏 | 「无法解压：文件已损坏或格式不受支持」 |
| 加密 zip | 「不支持加密压缩包」 |
| 权限拒绝 | 系统错误描述 + 提示完全磁盘访问（若相关） |
| 任务取消 | 输出面板「已取消」；已写出部分文件保留（与 tar 行为一致），列表刷新 |
| 网络卷中断 | 「连接中断，解压可能不完整」 |

错误文案写入 `Localizable.xcstrings`（`en` + `zh-Hans`），经 `L10n.Archive.*` 暴露。

---

## 六、分期实施

### Phase 1 — MVP（建议 3–5 天）

**范围：**

- [ ] `ArchiveOperations` + `ArchiveCommandBuilder` + `ArchiveTaskRunner`
- [ ] 列表右键：压缩（zip）、解压子菜单（到此处 / 到… / 到下载）
- [ ] 预览工具栏：解压、解压到…
- [ ] 本地卷小任务静默执行；大任务走输出面板
- [ ] 完成后刷新列表并选中产物
- [ ] i18n + `L10nTests` 关键键
- [ ] 废纸篓 / 混合选中 禁用规则
- [ ] 单元测试：命名、命令拼接、`uniqueExtractDirectory`

**验收：**

- 中文文件名 zip 压缩/解压往返正确
- 含子目录文件夹压缩后结构正确
- 10 GB 级 zip 可取消、不卡 UI
- 网络卷操作不崩溃，输出面板有日志

### Phase 2 — 体验增强

- [ ] 预览列表多选 → 解压选中项
- [ ] 「压缩选项…」Sheet：tar.gz、压缩级别
- [ ] `unar` 探测 → rar/7z 解压
- [ ] 应用菜单快捷键
- [ ] 设置：解压后行为、体量阈值
- [ ] 内置 Snippets：「压缩选中为 tar.gz」等模板

### Phase 3 — 可选

- [ ] 压缩包密码（依赖安全存储与 UI 复杂度评估）
- [ ] 拖拽到归档图标上添加文件（Finder 支持，优先级低）
- [ ] 工具栏可自定义按钮「压缩所选」

---

## 七、i18n 键规划（Phase 1）

| 键 | 中文 | 英文 |
|----|------|------|
| `action.compress_one` | 压缩「%@」 | Compress "%@" |
| `action.compress_many` | 压缩 %d 个项目 | Compress %d Items |
| `action.extract` | 解压 | Extract |
| `action.extract_here` | 解压到此处 | Extract Here |
| `action.extract_to` | 解压到… | Extract To… |
| `action.extract_downloads` | 解压到「下载」 | Extract to Downloads |
| `preview.toolbar.extract` | 解压 | Extract |
| `preview.toolbar.extract_to` | 解压到… | Extract To… |
| `archive.job.compress` | 压缩 | Compress |
| `archive.job.extract` | 解压 | Extract |
| `archive.status.compressing` | 正在压缩… | Compressing… |
| `archive.status.extracting` | 正在解压… | Extracting… |
| `archive.error.encrypted` | 不支持加密压缩包 | Encrypted archives are not supported |
| `archive.error.unsupported` | 无法识别或不支持的归档格式 | Unrecognized or unsupported archive format |
| `archive.hint.network_slow` | 网络卷上的归档操作可能较慢 | Archive operations on network volumes may be slow |
| `help.entry.compress.name` | 压缩 | Compress |
| `help.entry.compress.desc` | 将选中文件或文件夹打包为 ZIP | Zip selected files or folders |
| `help.entry.extract.name` | 解压 | Extract |
| `help.entry.extract.desc` | 将压缩包解压到当前或其它文件夹 | Extract archives to the current or another folder |

---

## 八、测试计划

### 8.1 单元测试（`ArchiveOperationsTests`）

- `defaultArchiveName`：单选 / 多选 / 含特殊字符文件名
- `uniqueExtractDirectory`：重名递增
- `makeCompressCommand` / `makeExtractCommand`：引号、空格、中文路径
- `isArchive`：扩展名大小写、`.tar.gz` 双扩展

### 8.2 集成测试（可选手工）

| 用例 | 预期 |
|------|------|
| 压缩文件夹再解压 | 目录结构一致 |
| 多选混合类型 | 生成单个 `Archive.zip` |
| 右键解压到下载 | `~/Downloads` 下出现内容 |
| 预览栏解压 | 与列表右键等价 |
| 取消大任务 | 进程终止，UI 恢复 |
| 废纸篓内 | 菜单项不可用 |

---

## 九、风险与对策

| 风险 | 对策 |
|------|------|
| `ditto` 与 `tar` 对 zip 兼容性差异 | 创建用 `ditto`，解压用 `tar`；往返测试覆盖 |
| 超大目录压缩长时间无进度 | 大任务强制输出面板；Phase 2 解析 `tar -v` 行更新进度条 |
| 网络卷 halfway 失败 | 不自动重试；日志保留；列表刷新显示已写出文件 |
| 与 Finder Archive Utility 并发 | 不锁文件；依赖系统错误 surfaced 给用户 |
| 加密 zip 误导用户 | 明确文案 + 帮助速查说明首版不支持 |

---

## 十、小结

本方案的核心取舍：

1. **压缩**：完全对齐 Finder——右键一键 ZIP，无格式选择。
2. **解压**：右键三级子菜单覆盖 90% 场景；**预览工具栏**补全「看着清单解压」的独有能力。
3. **执行层**：复用已有 `ShellQuoting`、`ShellProcessRunner`、`JobStore`，不引入新依赖。
4. **演进路径**：Phase 1 做稳 zip 往返；Phase 2 用预览多选做差异化「部分解压」；rar/7z 走系统工具探测。

下一步：按 Phase 1 任务拆 PR（建议顺序：`ArchiveOperations` → 右键菜单 → 预览工具栏 → i18n / 测试）。
