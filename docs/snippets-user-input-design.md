# Snippets 用户输入参数（`%ask`）设计

> 状态：P0 已实现（解析 + 多参数表单 + Executor 接入 + Shell 默认引号）  
> 关联：[`snippets-panel-design.md`](./snippets-panel-design.md) §7 上下文变量

## 1. 目标

在现有 `%p` / `%d` 等**上下文变量**之外，增加**执行时向用户询问**的占位符：

- 脚本内容出现 `%ask{提示}`（或带 id 的变体）时，执行前弹出输入表单；
- **提示文案**作为该输入项的标题（单参数时亦作为对话框标题）；
- 用户确认后把输入值代入脚本，再展开上下文变量并执行；
- 取消则中止，不创建 Job。

**不做（本阶段）**：TextExpander 式全局缩写、参数类型系统、默认值 / 必填校验 UI、`%askraw` 裸插入（见 §8）。

## 2. 语法

| 形态 | 含义 |
|------|------|
| `%ask{提示文案}` | 匿名参数；按提示文案去重 |
| `%ask[id]{提示文案}` | 命名参数；按 `id` 去重，全文同 id 共用一次输入 |

### 2.1 规则

- `id`：`[A-Za-z_][A-Za-z0-9_]*`
- 提示文案：非空；P0 **不允许**未转义的 `}`（不得在提示中写 `}`）
- 去重键：`id` 优先；无 id 时用 `prompt:` + 提示全文
- 询问顺序：按脚本中**首次出现**的顺序
- 与 `%date` / `%uuid` 等短 token 不冲突：仅匹配 `%ask[` 或 `%ask{` 前缀

### 2.2 示例

```bash
# 单参数：对话框标题 =「请输入新文件名」
mv %p %d/%ask{请输入新文件名}

# 多参数：一张表单，每行标签为提示；同 id 只问一次
zip -P %ask[password]{请输入压缩密码} %ask{输出文件名}.zip %P
# 脚本另一处再次引用同一密码：
# echo %ask[password]{请输入压缩密码}
```

## 3. 交互

### 3.1 表单（P0：始终用一张表单，含单参数）

| 场景 | 对话框标题 `messageText` | 字段 |
|------|--------------------------|------|
| 1 个参数 | **该参数的提示文案** | 一个输入框（不再重复标签） |
| ≥2 个参数 | 固定文案「填写参数」 | 每行：`提示` 作标签 + 输入框 |

- 副文案：`用于：{Snippet 名称}`
- 按钮：继续 / 取消（Esc 取消，⌘↩ 确认）
- 启发式密文：`id` 或提示含 `password` / `secret` / `token` / `密码`（大小写不敏感）→ `NSSecureTextField`
- 空字符串允许提交（必填留给后续阶段）

### 3.2 与危险确认的顺序

```text
触发执行
  →（可选）破坏性关键字确认
  → 解析 %ask → 弹表单（可取消）
  → SnippetExpander（哨兵保护用户输入 + 上下文展开）
  → Job / 系统终端
```

## 4. 展开与转义

### 4.1 顺序（防二次展开）

用户输入可能含 `%p` 等字面量，不得再被上下文替换：

1. 将所有 `%ask…` 替换为仅内部使用的哨兵；
2. 展开 `%p` / `%d` / …；
3. 将哨兵回填为用户值（已按脚本类型处理引号）。

### 4.2 Shell 引号（P0）

| `scriptType` | `%ask` 回填 |
|--------------|-------------|
| `shell` | `ShellQuoting.singleQuote(value)`（与路径类默认安全策略一致） |
| `python3` / `appleScript` | 原文回填（引号由脚本作者在模板中书写） |

后续 `%askraw`：Shell 下也不加引号（见 §8）。

## 5. 数据模型与持久化

- **真相来源**：脚本 `content` 内的 `%ask` 字面量；执行时扫描，不依赖 `variableHints`。
- **无需** bump `schemaVersion`；旧 Snippet 无 `%ask` 时行为不变。
- `variableHints` 仍仅作上下文变量说明，不作为 ask 执行依据。

```swift
struct SnippetAskParameter: Equatable, Identifiable {
    var key: String          // 去重键：id:xxx 或 prompt:…
    var id: String?
    var prompt: String
    var isSecret: Bool
}

enum SnippetAskParseError { /* emptyPrompt / unclosed / invalidId */ }
```

## 6. 模块与调用点

| 文件 | 职责 |
|------|------|
| `SnippetAskParser.swift` | 解析、去重、校验 |
| `SnippetAskInputPanel.swift` | AppKit 表单（面板 / 右键 / ⌘⇧P 均可） |
| `SnippetExpander.swift` | 哨兵 + 上下文展开 + 回填 |
| `SnippetExecutor.swift` | 危险确认后收集输入再 expand |
| `SnippetVariableCatalog.swift` | 变量参考 / 插入芯片增加 `%ask{提示}` |

触发入口无需逐个改 UI：统一走 `SnippetExecutor.execute` / `executeFromMenu`。

## 7. 文案（i18n）

键写入 `Sources/Explorer/Resources/Localizable.xcstrings`（`en` + `zh-Hans`），经 `L10n.Snippets.Ask` / `L10n.Error.SnippetAsk` 访问：

| 键 | 用途 |
|----|------|
| `snippets.ask.form_title` | 多参数对话框标题 |
| `snippets.ask.for_snippet %@` | 副文案「用于：…」 |
| `snippets.ask.continue` | 继续按钮 |
| `snippets.variable.ask` | Catalog 说明 |
| `error.snippet_ask.*` | 解析错误 |

## 8. 分期

| 阶段 | 内容 |
|------|------|
| **P0**（本文已实现） | `%ask` / `%ask[id]`；一张表单；Executor；Shell 默认引号；Catalog；单测 |
| **P1** | `%askraw`；编辑器「将询问」预览；插入时弹窗填提示 |
| **P2** | 默认值 `%ask{提示\|默认}`；必填；显式 `%asksecret` |

## 9. 验收

- [ ] `mv %p %d/%ask{新名}`：单选文件执行时弹窗，标题为「新名」，确认后路径正确且 Shell 带引号
- [ ] 两个不同 `%ask{…}`：一张表单两行，一次确认
- [ ] 同 `%ask[id]{…}` 出现两次：只问一次，两处同值
- [ ] 输入内容含 `%p`：展开后仍为字面 `%p`，不会变成路径
- [ ] 取消：不创建 Job、不启动进程
- [ ] 无 `%ask`：与改造前行为一致
- [ ] 未闭合 `{` / 空提示：展开失败，输出面板可见错误说明

## 10. 与主设计文档的关系

`snippets-panel-design.md` §7 描述上下文变量全集；**用户输入参数以本文为准**，§7.2 仅保留交叉引用与摘要行，避免两处细节分叉。
