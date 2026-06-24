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
            Text("调整图片尺寸")
                .font(.headline)

            Text("按像素设置输出尺寸。确认后需点击「保存编辑结果」写入文件。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("保持宽高比", isOn: $maintainAspectRatio)
                .toggleStyle(.checkbox)
                .onChange(of: maintainAspectRatio) { isLocked in
                    guard isLocked else { return }
                    syncHeightFromWidth()
                }

            HStack(spacing: 12) {
                dimensionField(title: "宽度", text: widthBinding)
                Text("×")
                    .foregroundStyle(.secondary)
                dimensionField(title: "高度", text: heightBinding)
            }

            if let message = validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("确定") {
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
            return "请输入宽度和高度"
        }
        guard let width = Int(widthText), let height = Int(heightText) else {
            return "请输入有效的像素数值"
        }
        if width <= 0 || height <= 0 {
            return "宽度和高度必须大于 0"
        }
        if width > 65_535 || height > 65_535 {
            return "单边像素不能超过 65535"
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
