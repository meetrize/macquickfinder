# 多窗口吸附与联动移动设计方案

> 目标：当应用同时打开两个主窗口时，支持窗口边缘在接近时自动吸附，对齐后两个窗口边框紧贴；支持左右吸附和上下吸附；吸附后拖动任一窗口时，另一个窗口保持相对位置与原始大小，跟随一起移动。  
> 本文档基于 2026-06 代码库现状编写，聚焦 **MVP 方案**，优先兼顾实现复杂度、交互稳定性和性能风险。

---

## 一、现状与切入点

### 1.1 当前窗口结构

| 维度 | 现状 |
|------|------|
| 窗口创建 | `Sources/Explorer/AppModule.swift` 通过 `WindowGroup` 创建主窗口 |
| 单窗口状态 | 每个窗口持有独立的 `ExplorerWindowLayoutState` |
| 跨窗口协调 | `ActiveWindowLayoutCenter` 已存在，可维护多个窗口关联对象 |
| AppKit 接入点 | `WindowKeyLayoutTracker` 已挂到窗口视图树，可拿到 `NSWindow` 并监听通知 |

### 1.2 对本功能最有价值的现有基础

当前代码已经有一个适合继续扩展的窗口跟踪器：

- `WindowKeyLayoutTracker` 已能在 `viewDidMoveToWindow()` 中获取 `window`
- 已通过 `NotificationCenter` 注册窗口通知
- 已有 `ActiveWindowLayoutCenter.shared` 作为跨窗口共享中心

这意味着本功能**不需要重构窗口架构**，只需在现有跟踪体系上增加：

1. `NSWindow` 实例注册
2. `didMove` 监听
3. 吸附关系状态机
4. 联动移动保护逻辑

结论：这是一个**中等复杂度的增量功能**，不是高风险架构改造。

---

## 二、针对关键交互问题的建议

上一轮评估里提到有几项“需要提前想清楚的交互”。结合当前项目结构，建议如下。

### 2.1 是否只支持两窗成对，还是允许 3+ 窗口竞争吸附

**建议：MVP 只支持“一个窗口最多吸附到一个其他主窗口”，运行上优先面向双窗场景。**

原因：

- 用户需求描述明确围绕“两窗并排”展开
- 当前项目没有多窗口编排系统，直接做链式/网状吸附会显著增加复杂度
- 两窗模型能把状态压缩成一条 `SnapLink`，实现和调试都明显更稳
- 后续若用户反馈确实需要 3 窗拼接，再扩展为“每窗一条主吸附关系”也更自然

MVP 行为建议：

- 当存在多个候选窗口时，只选择**距离最近且满足阈值**的那个
- 一个窗口在同一时刻只维护**一条**吸附关系
- 新吸附成功时，替换旧吸附关系

不建议首期就做：

- A 吸附 B，B 再吸附 C 的链式整体联动
- 一个窗口同时贴住两个窗口
- 平铺布局器式的自动重排

### 2.2 吸附后如果主导窗口 resize，另一个窗口是否响应

**建议：MVP 不联动 resize，只联动 position。**

原因：

- 你的原始需求明确说“另一个要保持相对的位置和原大小”
- 位置联动与尺寸联动的事件模型完全不同，后者要再处理 `didResize`
- 当前 `ExplorerWindowLayoutState` 管的是窗口内部布局，不适合承担跨窗口尺寸联动语义
- 只联动位置能显著减少抖动与递归更新风险

明确规则：

- 吸附后拖动窗口：另一个窗口一起移动
- 吸附后调整窗口大小：另一个窗口**不变尺寸**
- 如果 resize 导致两窗不再贴边：
  - 建议自动**解除吸附**
  - 不尝试在 resize 过程中持续重算并强制追随

这是最符合用户直觉、也最容易维护的方案。

### 2.3 是否持久化吸附关系，应用重启后是否恢复

**建议：首期不持久化。**

原因：

- 吸附关系是强运行时语义，依赖当时的屏幕、分辨率、显示器排列和窗口是否还存在
- 本项目当前持久化的是窗口内 UI 偏好，不是窗口间拓扑关系
- macOS 多显示器、外接屏拔插、空间（Spaces）切换后，恢复旧吸附关系容易产生异常位置
- 不持久化实现更轻，符合 MVP 原则

建议策略：

- 吸附关系仅保存在内存
- 应用退出、窗口关闭、窗口最小化/全屏时自动清除
- 若后续确有需求，再考虑持久化“最后的相邻布局偏好”，而不是原始链接对象

### 2.4 哪些窗口参与吸附

**建议：首期仅主浏览窗口参与，不包含设置窗口、sheet、弹窗、QuickLook 类临时窗口。**

原因：

- 目标场景是两个 Finder 风格主窗口并排浏览
- 设置页与 sheet 参与吸附没有明显用户价值，反而会制造意外行为
- 当前应用主体由 `WindowGroup` 创建，主窗口识别成本最低

建议规则：

- 只注册承载 `ContentView` 的主窗口
- 忽略：
  - Settings 窗口
  - 各类 sheet / modal
  - 系统面板或临时工具窗口
  - miniaturized / fullscreen 窗口

### 2.5 吸附阈值、解除阈值和“手感”

**建议：**

- 吸附阈值：`12pt`
- 解除阈值：`18pt` 或 `20pt`
- 非吸附轴允许的重叠范围：至少 `80pt`，避免仅角点擦到就吸附

原因：

- 吸附阈值过大，窗口会“被抢走”
- 吸附阈值过小，用户会觉得难以命中
- 解除阈值略大于吸附阈值，可减少边缘来回抖动

建议采用“迟滞”机制：

- 进入吸附：距离 <= `snapThreshold`
- 保持吸附：距离 <= `releaseThreshold`
- 超出释放阈值：解除吸附

这类设计比使用同一个阈值更稳定。

### 2.6 拖动任一窗口时，谁是 leader / follower

**建议：始终以“用户当前直接拖动的那个窗口”为 leader，另一个窗口为 follower。**

原因：

- 用户心智最明确
- 不需要长期固定主从关系
- 一旦两窗吸附完成，不论拖哪个，都可带着另一个走

实现上：

- 在 `didMove` 事件中，谁先产生“用户手动拖动”的位置变化，就临时视为 leader
- 程序驱动移动 follower 时，设置保护标记，避免 follower 的 `didMove` 再反向影响 leader

### 2.7 脱离吸附的规则

**建议：满足以下任一条件时解除吸附：**

1. 拖动方向明显把两个窗口拉开
2. 吸附边距离超过 `releaseThreshold`
3. 两窗不再有足够的非吸附轴重叠
4. 任一窗口关闭、最小化、进入全屏
5. 任一窗口 resize 后不再满足贴边关系

这套规则比较简单，也更容易预测。

---

## 三、推荐的 MVP 行为定义

### 3.1 支持的吸附类型

仅支持四种一维贴边关系：

- 左吸右：A.left 贴 B.right
- 右吸左：A.right 贴 B.left
- 上吸下：A.top 贴 B.bottom
- 下吸上：A.bottom 贴 B.top

不支持：

- 角点吸附
- 自动居中对齐
- 同时横向和纵向双重约束

### 3.2 吸附后联动规则

- 只保持**相对位置**
- 不同步宽高
- follower 始终维持原始大小
- leader 移动多少，follower 跟着平移多少

### 3.3 多候选窗口选择规则

若某次拖动时有多个候选窗口落入阈值内：

1. 优先选距离最小的
2. 若距离相同，优先保留当前已存在的吸附对象
3. 若仍相同，优先左右吸附，再考虑上下吸附

这样可以减少吸附对象频繁切换。

### 3.4 功能开关建议

建议加一个设置项：

- `启用窗口吸附与联动移动`

首期默认值建议：

- **默认开启**

理由：

- 这是增强型桌面体验功能，且不会破坏原有单窗口逻辑
- 若个别用户不喜欢，仍可手动关闭

---

## 四、基于现有结构的实现方案

### 4.1 设计原则

1. 尽量复用 `WindowKeyLayoutTracker`
2. 尽量扩展 `ActiveWindowLayoutCenter`，避免再引入第二套窗口中心
3. 吸附关系只存在于运行时内存
4. 所有窗口几何计算都在主线程完成
5. 尽量不触碰文件浏览、预览、Snippets 等无关模块

### 4.2 推荐新增类型

建议新增文件：

- `Sources/Explorer/WindowSnapCoordinator.swift`

建议在其中定义：

```swift
import AppKit

enum WindowSnapEdge {
    case leftToRight
    case rightToLeft
    case topToBottom
    case bottomToTop
}

struct WindowSnapLink {
    weak var windowA: NSWindow?
    weak var windowB: NSWindow?
    var edge: WindowSnapEdge
}

@MainActor
final class WindowSnapCoordinator {
    static let shared = WindowSnapCoordinator()
}
```

说明：

- `WindowSnapCoordinator` 负责窗口注册、吸附检测、联动移动、解除吸附
- `ActiveWindowLayoutCenter` 继续负责布局状态与 key window 语义
- 两者职责分离，避免把 `ExplorerWindowLayoutState` 变成“万能中心”

### 4.3 推荐的数据结构

建议 coordinator 维护：

| 字段 | 作用 |
|------|------|
| `NSHashTable<NSWindow>` | 跟踪所有参与吸附的主窗口 |
| `activeLink` | 当前吸附关系；MVP 可全局只保留一条 |
| `lastFramesByWindowID` | 记录窗口上次 frame，用于计算位移 delta |
| `isProgrammaticMove` | 防止联动移动造成递归通知 |
| `snapEnabled` | 用户设置开关缓存 |

推荐窗口标识：

- 优先直接用 `ObjectIdentifier(window)`
- 不必为 `NSWindow` 建持久 ID

### 4.4 与现有代码的接入点

#### A. 扩展窗口注册

在 `WindowKeyLayoutTracker.TrackerView.viewDidMoveToWindow()` 中：

- 继续保留现有的 key window 注册
- 额外调用：
  - `WindowSnapCoordinator.shared.register(window:)`
  - 注册 `NSWindow.didMoveNotification`
  - 可选注册 `NSWindow.didResizeNotification`
  - 注册 `NSWindow.willCloseNotification`

#### B. 统一通知入口

建议 `TrackerView` 只做桥接，不做吸附逻辑：

```swift
WindowSnapCoordinator.shared.handleWindowDidMove(window)
WindowSnapCoordinator.shared.handleWindowDidResize(window)
WindowSnapCoordinator.shared.unregister(window)
```

这样 `TrackerView` 保持轻量，逻辑集中在 coordinator。

### 4.5 吸附检测算法

以当前移动中的窗口 `moving` 为基准，遍历其他已注册窗口 `candidate`。

对每对窗口计算四个边缘距离：

- `abs(moving.frame.maxX - candidate.frame.minX)` => 右吸左
- `abs(moving.frame.minX - candidate.frame.maxX)` => 左吸右
- `abs(moving.frame.maxY - candidate.frame.minY)` => 上吸下
- `abs(moving.frame.minY - candidate.frame.maxY)` => 下吸上

同时要求：

- 对于左右吸附，两窗在 Y 轴上有足够重叠
- 对于上下吸附，两窗在 X 轴上有足够重叠

建议使用：

```swift
overlapLength >= 80
```

选出满足阈值的最佳候选后：

1. 计算目标贴边 frame
2. 将 `moving` 调整到精确吸附位置
3. 建立 `activeLink`

### 4.6 联动移动算法

当 `activeLink` 存在且某一端窗口被用户拖动：

1. 根据当前 frame 与 `lastFrame` 计算 `dx / dy`
2. 找到另一端窗口 `other`
3. 将 `other` 的 origin 平移相同的 `dx / dy`
4. 不修改 `other` 的 size

建议使用的保护策略：

```swift
isProgrammaticMove = true
other.setFrameOrigin(newOrigin)
isProgrammaticMove = false
```

或按窗口粒度维护：

```swift
programmaticMoveWindows: Set<ObjectIdentifier>
```

后者更稳，能避免多个事件重叠时互相污染。

### 4.7 解除吸附

在 `handleWindowDidMove` / `handleWindowDidResize` 中都检查：

- 当前吸附边距离是否仍在 `releaseThreshold` 内
- 非吸附轴重叠是否仍满足最小要求

不满足则：

- 清空 `activeLink`

若后续拖动再次回到边缘，可重新吸附。

### 4.8 窗口关闭与失效处理

`NSWindow` 是弱引用目标，仍建议在以下事件主动清理：

- `willClose`
- `didMiniaturize`
- 进入全屏（若后续纳入处理）

MVP 最少做：

- `unregister(window:)`
- 如果 `activeLink` 引用了该窗口，则清空 link

---

## 五、为什么不建议把逻辑直接塞进 `ActiveWindowLayoutCenter`

虽然当前已有 `ActiveWindowLayoutCenter`，但仍建议把吸附做成单独 coordinator，原因如下：

| 方案 | 问题 |
|------|------|
| 全塞进 `ActiveWindowLayoutCenter` | 它原本服务于布局状态，会逐渐混入窗口几何、拖动状态、防递归逻辑，职责失衡 |
| 单独 `WindowSnapCoordinator` | 职责清晰，后续即使删除/关闭该功能，也更易维护 |

推荐分工：

- `ActiveWindowLayoutCenter`：布局状态、key window、输出面板相关跨窗行为
- `WindowSnapCoordinator`：窗口注册、几何检测、吸附联动

---

## 六、性能评估

### 6.1 结论

**性能影响很小，可认为对主功能无明显负担。**

### 6.2 原因

| 维度 | 分析 |
|------|------|
| 计算量 | 双窗场景下只是少量 `CGRect` 距离与重叠计算，接近 O(1) |
| 触发频率 | 仅拖动窗口时才高频触发 |
| 数据规模 | 首期仅主窗口参与，通常就是 2 个 |
| I/O | 无磁盘、无网络、无目录扫描 |
| 与业务耦合 | 不触发文件列表刷新、不影响缩略图、不影响目录监控 |

### 6.3 真正需要防范的不是“慢”，而是“抖”

主要风险不在 CPU，而在交互稳定性：

1. 联动移动递归触发 `didMove`
2. 吸附和解除共用同一阈值导致边缘抖动
3. 多个候选窗口间来回切换

解决后，性能层面基本不会成为问题。

---

## 七、MVP 实施步骤

### Phase 1：最小闭环

1. 新增 `WindowSnapCoordinator`
2. 在 `WindowKeyLayoutTracker` 中注册 `didMove` / `willClose`
3. 支持四向吸附检测
4. 支持吸附后拖动联动
5. 支持窗口关闭时解除链接

### Phase 2：稳定性增强

1. 加入 `didResize` 解除吸附
2. 增加设置开关
3. 增加阈值常量集中配置
4. 细化多候选选择策略

### Phase 3：可选增强

1. 支持更多窗口策略
2. 支持跨屏细节打磨
3. 支持更细的视觉反馈（如吸附瞬间轻微动画）

---

## 八、最终建议

### 建议采纳的产品规则

1. 只支持主窗口之间的吸附
2. MVP 只维护一条吸附关系，优先满足双窗场景
3. 吸附后仅联动移动，不联动尺寸
4. resize、关闭、最小化后允许自动解除吸附
5. 首期不做持久化
6. 默认开启，并提供设置开关

### 建议采纳的工程方案

1. 保留 `ActiveWindowLayoutCenter` 现有职责不变
2. 新增独立的 `WindowSnapCoordinator`
3. 在 `WindowKeyLayoutTracker` 中追加窗口移动/关闭桥接
4. 所有几何和联动逻辑统一放在 coordinator 中

### 难度与收益结论

| 维度 | 结论 |
|------|------|
| 实现难度 | 中等，重点在稳定性而不是代码量 |
| 对现有架构侵入 | 低到中等 |
| 性能影响 | 很小 |
| 用户感知收益 | 高，尤其适合双窗对照浏览目录 |

如果按本方案实施，推荐先完成 **MVP 吸附 + 联动移动**，不要首期同时追求多窗链式编排、持久化恢复和动画打磨。
