import AppKit

enum FileListTableAnimations {
    static func performWithoutAnimation(_ work: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            context.allowsImplicitAnimation = false
            work()
        }
        CATransaction.commit()
    }
}
