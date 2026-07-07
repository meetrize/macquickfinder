# MeoFind 双产品线 Git 分支工作流

> 目标：在**同一仓库**内维护两个可发布产品——**基础版**（无 AI）与 **AI 整合版**——并保证基础版升级时，AI 版的基础功能能**低成本、低冲突**地同步跟进。  
> 本文档描述推荐的分支模型、一次性初始化、日常开发节奏，以及在 **Cursor** 中的实操习惯。  
> AI 功能架构见 [ai-assistant-design.md](./ai-assistant-design.md)；分阶段 checklist 见 [ai-assistant-plan.md](./ai-assistant-plan.md)。

---

## 一、分支模型

### 1.1 总体关系

采用 **「主干 + 长期 AI 分支」**，而不是两个互相独立、很少合并的分支。

```
main（基础版，唯一真相来源）
  │
  └── ai（AI 整合版 = main + AI 增量）
```

| 分支 | 职责 | 发布 |
|------|------|------|
| `main` | 所有非 AI 功能、bugfix、性能、UI、i18n 等 | 基础版 |
| `ai` | 在 `main` 之上叠加 AI 模块、CLI、设置页等 | AI 整合版 |

### 1.2 铁律

1. **基础功能只在 `main` 开发**——预览、文件列表、侧边栏、Git 面板等均属此类。
2. **AI 功能只在 `ai` 开发**——模型配置、对话面板、Snippet CLI、会话历史等。
3. **同步方向永远是 `main → ai`**——基础版更新后，把 `main` 合并进 `ai`。
4. **禁止**将 `ai` 整包 merge 回 `main`（否则 AI 代码会污染基础版）。
5. **bug 若在 AI 版发现、根因在基础代码**：先在 `main` 修复并提交，再在 `ai` 执行 `merge main`。

### 1.3 为何不用其他模型

| 做法 | 问题 |
|------|------|
| 两个完全独立分支、互不 merge | 基础功能要改两遍，迟早严重分叉 |
| 经常 `ai → main` 整包 merge | AI 代码渗入基础版，无法单独发基础版 |
| 同一工作区频繁 `checkout main/ai` | 易误提交、DerivedData/构建缓存混乱 |
| 全仓库 `#if AI_ENABLED` 散落 | 短期省事，长期 merge 冲突多 |

---

## 二、一次性初始化

在仓库根目录执行：

```bash
cd /path/to/macquickfinder

# 1. 确认 main 干净且最新
git checkout main
git pull

# 2. 创建 AI 长期分支并推送
git checkout -b ai
git push -u origin ai

# 3.（强烈建议）用 git worktree 开第二个工作目录
git worktree add ../macquickfinder-ai ai
```

完成后目录布局示例：

```
/path/to/macquickfinder       ← 对应 main，基础版日常开发
/path/to/macquickfinder-ai     ← 对应 ai，AI 版日常开发
```

在 Cursor 中分别 **File → Open Folder** 打开上述两个目录，即两个独立窗口，无需频繁切分支。

---

## 三、代码结构：让 merge 更平滑

Git 只能同步提交历史；**冲突多少取决于代码如何拆分**。

### 3.1 推荐模块划分

在 `Package.swift` 中增加独立 target（实施细节见 AI 设计文档）：

| 模块 | 说明 |
|------|------|
| `FileList` / `Explorer` | 基础版与 AI 版共用 |
| `AIAssistant`（新） | AI 调用、会话存储、Provider 适配等，**主要在 `ai` 分支演进** |
| `meofind` CLI | AI 版 Snippet 调用入口 |

基础版 `Explorer` **不 import `AIAssistant`**。AI 版在 App 入口通过 optional 注册 / 依赖注入挂载 AI 能力，避免在 `FileListView` 等核心文件里散落 `if isAIVersion`。

### 3.2 允许修改的范围（约定）

| 分支 | 优先改动 |
|------|----------|
| `main` | `Sources/FileList/`、`Sources/Explorer/`（非 AI）、通用 docs |
| `ai` | `Sources/AIAssistant/`、`docs/ai-*`、CLI；合并 `main` 后仅在挂载点做最小接入 |

---

## 四、日常开发

### 4.1 场景 A：基础功能（约 90% 日常）

**窗口**：`macquickfinder`（`main`）

1. 确认当前分支为 **`main`**（Cursor 状态栏 / 终端 `git branch --show-current`）。
2. 正常开发、测试、提交。提交信息遵循仓库规范（简体中文），例如：
   ```
   feat: 侧边栏 Devices 动态显示已挂载移动硬盘
   fix: 修复路径切换后目录列表不刷新的问题
   ```
3. `git push origin main`。
4. **尽快**在 AI 工作区合并（见 §4.3），不要堆很多天再合。

### 4.2 场景 B：AI 功能

**窗口**：`macquickfinder-ai`（`ai`）

1. 确认当前分支为 **`ai`**。
2. 只改 AI 相关模块与文档。
3. 提交示例：
   ```
   feat: 输出面板新增 AI 对话 Tab 与流式回复
   feat: 设置页新增大模型供应商配置
   ```
4. **不要** merge 回 `main`。

### 4.3 将 main 同步到 ai（核心操作）

**在 AI 工作区**（`macquickfinder-ai`）执行：

```bash
git fetch origin
git merge origin/main
# 若有冲突：在 Cursor 中解决 → git add → git commit
swift test   # 或 ./build_and_run.sh / 项目惯用构建命令
git push origin ai
```

说明：

- 当天 `main` 有多个 commit 时，**一次 merge 全部带入**，无需逐个 cherry-pick。
- 若 `ai` 上尚无新提交，merge 通常为 fast-forward，无冲突。
- 冲突多出现在「同一文件的同一区域」——若 AI 与基础改动分离到不同模块，冲突会很少。

### 4.4 场景 C：AI 版发现 bug，根因在基础代码

1. 在 **`main` 窗口**修复并提交、推送。
2. 在 **`ai` 窗口**执行 §4.3 的 merge。
3. 若 AI 版还有仅 AI 特有的补丁，在 merge 完成后于 `ai` 上追加提交。

---

## 五、Cursor 中的实操习惯

### 5.1 双窗口对照

| Cursor 窗口 | 目录 | 分支 | 用途 |
|-------------|------|------|------|
| MeoFind Basic | `macquickfinder` | `main` | 基础版功能与 bugfix |
| MeoFind AI | `macquickfinder-ai` | `ai` | AI 功能 + 定期 merge main |

### 5.2 Agent / Chat 提示

新开对话时**首句标明分支与范围**，减少误改：

- 基础版：`当前在 main 分支，做基础版功能，不要引入 AI 相关代码。`
- AI 版：`当前在 ai 分支 worktree，只改 Sources/AIAssistant/ 及 AI 挂载点。`

### 5.3 合并节奏

| 频率 | 做法 |
|------|------|
| 每完成一个基础功能 | 立刻在 `ai` merge 一次 |
| 多人协作 | 至少每日一次：`git fetch` + `git merge origin/main` |
| 发基础版 tag 前 | 确认 `ai` 已 merge 到最新 `main` |

### 5.4 可选：Cursor Rules

可在 `.cursor/rules/` 增加分支约束（例如 AI worktree 仅允许改 `AIAssistant`），与本文档保持一致；Agent 会自动遵循。

---

## 六、发版与标签

```bash
# 基础版（在 main）
git checkout main
git pull
git tag v1.2.0
git push origin v1.2.0

# AI 版（在 ai，版本号可独立）
git checkout ai
git pull
git merge origin/main   # 发版前再合一次
git tag v1.2.0-ai
git push origin v1.2.0-ai
```

基础版与 AI 版可使用不同版本号策略；tag 命名建议加 `-ai` 后缀以便区分。

---

## 七、一周典型节奏（示例）

| 日 | main | ai |
|----|------|-----|
| 周一 | 修预览 bug → push | merge main → 继续 AI 设置页 |
| 周二 | 侧边栏新功能 → push | merge main → 文件列表「加入对话」 |
| 周三 | （无改动） | 会话历史持久化 |
| 周四 | 性能优化 → push | merge main → 解决少量冲突 |
| 周五 | tag `v1.3.0` | merge main → tag `v1.3.0-ai` → 内测 |

---

## 八、命令速查

```bash
# 查看当前分支
git branch --show-current

# 创建 worktree（仅需一次）
git worktree add ../macquickfinder-ai ai

# 列出所有 worktree
git worktree list

# main → ai 同步（在 ai 目录执行）
git fetch origin && git merge origin/main

# 删除 worktree（若不再需要）
git worktree remove ../macquickfinder-ai
```

---

## 九、与 AI 设计文档的关系

| 文档 | 内容 |
|------|------|
| 本文档 | Git 分支、worktree、Cursor 日常流程 |
| [ai-assistant-design.md](./ai-assistant-design.md) | AI 模块架构、`AIChatService`、CLI、IPC |
| [ai-assistant-plan.md](./ai-assistant-plan.md) | 分阶段实施 checklist |

实施 AI 功能时：**架构与设计**以 AI 设计文档为准；**在哪个分支改、如何同步基础版**以本文档为准。

---

## 十、最小启动清单

- [ ] 从最新 `main` 创建 `ai` 并 `push -u origin ai`
- [ ] `git worktree add ../macquickfinder-ai ai`
- [ ] Cursor 打开两个文件夹，分别固定为 Basic / AI 窗口
- [ ] 在 `ai` 上搭建 `AIAssistant` target 骨架（见 AI 设计文档）
- [ ] 养成习惯：**main 开发 → push → ai 窗口 merge origin/main**
