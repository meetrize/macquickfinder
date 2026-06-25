import Foundation

enum LeftPanelMode: String, CaseIterable, Sendable {
    case sidebar
    case rail
    case hidden
    
    var isVisible: Bool {
        self != .hidden
    }
}

enum LeftPanelVisibleMode: String, CaseIterable, Sendable {
    case sidebar
    case rail
    
    var asPanelMode: LeftPanelMode {
        switch self {
        case .sidebar: return .sidebar
        case .rail: return .rail
        }
    }
}

struct LeftPanelLayoutConstants: Sendable {
    /// 侧栏（显示文字）可缩窄到的最小宽度；约为 `railWidth` 的两倍，再窄则进入仅图标模式。
    var sidebarMinWidth: CGFloat = 80
    var sidebarMaxWidth: CGFloat = 420
    var railWidth: CGFloat = 44
    
    /// 进入隐藏状态阈值（从 sidebar/rail 继续向左拖到足够小才隐藏）。
    var hideThreshold: CGFloat = 28
    
    /// 回滞：避免在阈值附近来回抖动。
    var sidebarToRailHysteresis: CGFloat = 4
    var railToSidebarHysteresis: CGFloat = 8
    
    func clampedSidebarWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, sidebarMinWidth), sidebarMaxWidth)
    }
    
    /// 工具栏模式拖拽时的显示宽度：可随鼠标变宽，但不窄于 `railWidth`；低于 `hideThreshold` 视为隐藏。
    func railDisplayWidth(liveDragWidth: CGFloat) -> CGFloat {
        if liveDragWidth < hideThreshold {
            return railWidth
        }
        return max(liveDragWidth, railWidth)
    }
}

struct LeftPanelTransitionResult: Sendable {
    var mode: LeftPanelMode
    var lastVisible: LeftPanelVisibleMode
    var sidebarWidth: CGFloat
}

enum LeftPanelStateMachine {
    /// 处理拖拽中的“目标宽度”（未 clamp 到最小宽度），并输出新的模式与应持久化的状态。
    static func applyDrag(
        proposedWidth: CGFloat,
        currentMode: LeftPanelMode,
        lastVisible: LeftPanelVisibleMode,
        sidebarWidth: CGFloat,
        constants: LeftPanelLayoutConstants
    ) -> LeftPanelTransitionResult {
        let width = max(proposedWidth, 0)
        
        // 优先处理隐藏（两态都可以继续往左拖到隐藏）
        if width < constants.hideThreshold {
            return LeftPanelTransitionResult(
                mode: .hidden,
                lastVisible: lastVisible,
                sidebarWidth: constants.clampedSidebarWidth(sidebarWidth)
            )
        }
        
        switch currentMode {
        case .sidebar:
            if width < constants.sidebarMinWidth - constants.sidebarToRailHysteresis {
                return LeftPanelTransitionResult(
                    mode: .rail,
                    lastVisible: .rail,
                    sidebarWidth: constants.clampedSidebarWidth(sidebarWidth)
                )
            }
            return LeftPanelTransitionResult(
                mode: .sidebar,
                lastVisible: .sidebar,
                sidebarWidth: constants.clampedSidebarWidth(width)
            )
            
        case .rail:
            if width >= constants.sidebarMinWidth + constants.railToSidebarHysteresis {
                return LeftPanelTransitionResult(
                    mode: .sidebar,
                    lastVisible: .sidebar,
                    sidebarWidth: constants.clampedSidebarWidth(width)
                )
            }
            return LeftPanelTransitionResult(
                mode: .rail,
                lastVisible: .rail,
                sidebarWidth: constants.clampedSidebarWidth(sidebarWidth)
            )
            
        case .hidden:
            // 隐藏状态下不响应拖拽（没有可拖拽的 divider），保持不变。
            return LeftPanelTransitionResult(
                mode: .hidden,
                lastVisible: lastVisible,
                sidebarWidth: constants.clampedSidebarWidth(sidebarWidth)
            )
        }
    }
}

