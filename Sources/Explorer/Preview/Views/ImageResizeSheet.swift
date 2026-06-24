import SwiftUI

struct ImageResizeSheet: View {
    let aspectWidth: Int
    let aspectHeight: Int
    let onCancel: () -> Void
    let onApply: (Int, Int) -> Void

    @State private var widthText: String
    @State private var heightText: String
    @State private var maintainAspectRatio = true
    @State private var isSyncingFields = false

    init(
        initialWidth: Int,
        initialHeight: Int,
        aspectWidth: Int,
        aspectHeight: Int,
        onCancel: @escaping () -> Void,
        onApply: @escaping (Int, Int) -> Void
    ) {
        let safeWidth = max(1, initialWidth)
        let safeHeight = max(1, initialHeight)
        self.aspectWidth = max(1, aspectWidth)
        self.aspectHeight = max(1, aspectHeight)
        self.onCancel = onCancel
        self.onApply = onApply
        _widthText = State(initialValue: "\(safeWidth)")
        _heightText = State(initialValue: "\(safeHeight)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.Preview.Image.resizeTitle)
                .font(.headline)

            Text(L10n.Preview.Image.resizeHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(L10n.Preview.Image.maintainAspect, isOn: $maintainAspectRatio)
                .toggleStyle(.checkbox)
                .onChange(of: maintainAspectRatio) { isLocked in
                    guard isLocked else { return }
                    syncHeightFromWidth()
                }

            HStack(spacing: 12) {
                dimensionField(title: L10n.Preview.Image.width, text: widthBinding)
                Text("×")
                    .foregroundStyle(.secondary)
                dimensionField(title: L10n.Preview.Image.height, text: heightBinding)
            }

            if let message = validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button(L10n.Action.cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(L10n.Preview.Image.confirm) {
                    guard let size = parsedSize else { return }
                    onApply(size.width, size.height)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(parsedSize == nil)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private var widthBinding: Binding<String> {
        Binding(
            get: { widthText },
            set: { newValue in
                widthText = sanitizedDigits(from: newValue)
                if maintainAspectRatio {
                    syncHeightFromWidth()
                }
            }
        )
    }

    private var heightBinding: Binding<String> {
        Binding(
            get: { heightText },
            set: { newValue in
                heightText = sanitizedDigits(from: newValue)
                if maintainAspectRatio {
                    syncWidthFromHeight()
                }
            }
        )
    }

    private var parsedSize: (width: Int, height: Int)? {
        guard let width = Int(widthText), let height = Int(heightText) else { return nil }
        guard width > 0, height > 0, width <= 65_535, height <= 65_535 else { return nil }
        return (width, height)
    }

    private var validationMessage: String? {
        if widthText.isEmpty || heightText.isEmpty {
            return L10n.Preview.Image.validationEmpty
        }
        guard let width = Int(widthText), let height = Int(heightText) else {
            return L10n.Preview.Image.validationInvalid
        }
        if width <= 0 || height <= 0 {
            return L10n.Preview.Image.validationPositive
        }
        if width > 65_535 || height > 65_535 {
            return L10n.Preview.Image.validationMax
        }
        return nil
    }

    @ViewBuilder
    private func dimensionField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 96)
                    .multilineTextAlignment(.trailing)
                Text("px")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func sanitizedDigits(from value: String) -> String {
        String(value.filter(\.isNumber))
    }

    private func syncHeightFromWidth() {
        guard !isSyncingFields else { return }
        guard let width = Int(widthText), width > 0, aspectWidth > 0 else { return }
        isSyncingFields = true
        let height = max(1, Int((Double(width) * Double(aspectHeight) / Double(aspectWidth)).rounded()))
        heightText = "\(height)"
        isSyncingFields = false
    }

    private func syncWidthFromHeight() {
        guard !isSyncingFields else { return }
        guard let height = Int(heightText), height > 0, aspectHeight > 0 else { return }
        isSyncingFields = true
        let width = max(1, Int((Double(height) * Double(aspectWidth) / Double(aspectHeight)).rounded()))
        widthText = "\(width)"
        isSyncingFields = false
    }
}
