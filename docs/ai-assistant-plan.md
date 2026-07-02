# AI 助手能力 — 分阶段实施计划

> 设计文档：[ai-assistant-design.md](./ai-assistant-design.md)  
> 状态：未开始（2026-07）

---

## P0 — 数据模型与存储

- [ ] 新建 `Sources/Explorer/AI/` 目录骨架
- [ ] 定义 `AIProviderConfig`、`AIModelConfig`、`AIProviderKind`、`AIModelCapability`
- [ ] 实现 `AIProviderStore`（JSON 持久化 + Keychain API Key）
- [ ] 实现 `AISessionStore`（SQLite：`sessions` / `messages` 表）
- [ ] `AppPreferences` 注册 AI 相关键
- [ ] 单元测试：`AIProviderStore`、`AISessionStore`

---

## P1 — 设置页「AI」Tab

- [ ] `SettingsView` 增加 AI Tab
- [ ] 供应商 CRUD、模型列表、启用/禁用
- [ ] 多默认模型：全局 / 视觉 / 代码 / 长上下文
- [ ] 连接测试按钮
- [ ] 「安装命令行工具」入口（UI 先占位，P5 接逻辑）
- [ ] i18n：`settings.ai.*` + `L10nTests`

---

## P2 — AIChatService 统一调用层

- [ ] OpenAI 兼容 Chat Completions（含流式 SSE）
- [ ] Anthropic Messages API 适配
- [ ] 按 capability 选择默认模型
- [ ] Token 用量回写 `messages.token_usage_json`
- [ ] Mock HTTP 集成测试

---

## P3 — 输出面板 AI 对话模式

- [ ] `JobSource.aiChat(sessionID:)`
- [ ] Shell / AI 模式切换（`⌘⇧A`）
- [ ] 多行输入、`Enter` 发送
- [ ] 流式 Markdown 回复渲染
- [ ] AI Tab 与 Shell Tab 视觉区分
- [ ] i18n：`output.ai.*`

---

## P4 — 文件引用系统

- [ ] `AIAttachmentResolver`（文本 / 图片 / PDF / 目录 / 降级）
- [ ] 右键「加入对话」→ `FileListRowContextMenuBuilder`
- [ ] 引用 chip UI（输入框上方）
- [ ] 拖拽文件到 AI 输入区
- [ ] `@` 文件提及浮层（可拆为 P4b）
- [ ] i18n：`contextMenu.ai.*`、`ai.attachment.*`

---

## P5 — 内置 CLI

- [ ] SPM executable 或 Resources 内嵌 `meofind`
- [ ] 子命令 `ai`：`--file`、`--session`、`--model`、`--json`、`--new`
- [ ] Unix Domain Socket 协议（JSON line）
- [ ] App 内 `MeoFindAISocketServer` 监听
- [ ] 「安装命令行工具」symlink 到 `~/.local/bin`
- [ ] App 未运行：静默拉起 + 兜底直连 API + 写 SQLite

---

## P6 — 历史贯通验收

- [ ] Snippet 调用 `meofind ai` → GUI 历史可见，`source_tag=snippet:*`
- [ ] CLI 兜底写入 → 重启 App 后加载
- [ ] 历史列表：搜索、重命名、置顶、删除
- [ ] 端到端手工测试清单（见设计文档 §十一）

---

## P7 — 增强（按优先级排期）

| 优先级 | 项 | 设计文档 |
|--------|-----|----------|
| 高 | 「应用建议」结构化 Action + 二次确认 | §7.3 |
| 高 | Slash Commands（`/summarize` 等） | §7.5 |
| 中 | Shell 失败 →「让 AI 解释」 | §7.13 |
| 中 | 预览区划词发送到 AI | §7.2 |
| 中 | 聊出来的脚本 → 存为 Snippet | §7.6 |
| 中 | 用量与成本可视化 | §7.9 |
| 低 | 隐私目录 → 本地模型提示 | §7.8 |
| 低 | 双文件对比、智能整理向导 | §7.14、§7.15 |
| 低 | 操作录制 → AI 优化脚本 | §7.16 |
| 远期 | 预览并排 AI、语义索引 | §7.10、§7.19 |

---

## P8 — Snippet 示例迁移

- [ ] 用 `meofind ai` 重写 `docs/snippets-claude-ai.json` 示例
- [ ] 内置 Snippet 包更新说明（Release Notes）

---

## 风险与依赖

| 风险 | 缓解 |
|------|------|
| 非 PTY 输出面板与 AI 流式 UI 混排 | AI Tab 独立渲染层，不复用 stdout 文本区 |
| 多进程写 SQLite | WAL 模式 + 短事务；CLI 只做 INSERT |
| GUI App PATH 与终端不一致 | CLI 自包含，不依赖用户 shell 里的 `claude` |
| 批量 AI 成本 | §7.22 队列限速 + §7.9 用量提示 |
| API Key 泄露 | 仅 Keychain；导出配置排除 Key |
