import SwiftUI

struct PreviewOpenWithMenuSection: View {
    let fileURL: URL

    var body: some View {
        let options = OpenWithMenuBuilder.applicationOptions(for: fileURL)
        Menu {
            if options.isEmpty {
                Button(L10n.Action.openWithOther) {
                    FileOperations.openWith(url: fileURL)
                }
            } else {
                ForEach(options) { option in
                    Button {
                        OpenWithMenuBuilder.open(fileURLs: [fileURL], withApplicationAt: option.url)
                    } label: {
                        Text(
                            option.isDefault
                                ? L10n.Action.openWithDefault(option.displayName)
                                : option.displayName
                        )
                    }
                }
                Divider()
                Button(L10n.Action.openWithOther) {
                    FileOperations.openWith(url: fileURL)
                }
            }
        } label: {
            Label(L10n.Preview.Toolbar.openDefaultApp, systemImage: "arrowshape.turn.up.right.circle")
        }
    }
}
