import FileList
import SwiftUI

extension PreviewSession {
    func prependRunnableScriptRunButton(
        to items: [PreviewToolbarOverflowModel],
        for item: FileItem
    ) -> [PreviewToolbarOverflowModel] {
        guard PreviewTypeClassifier.runnableScriptType(forExtension: item.url.pathExtension) != nil else {
            return items
        }

        let runItem = previewToolbarIconItem(
            id: "script-run",
            title: L10n.Preview.Toolbar.runScript,
            systemImage: "play.circle.fill",
            action: { PreviewScriptRunner.run(file: item) }
        )
        return [runItem] + items
    }
}
