import AppKit

/// Snippet `%ask` 多参数输入表单（AppKit，供面板 / 右键 / Command Palette 共用）。
@MainActor
enum SnippetAskInputPanel {
    private static let formWidth: CGFloat = 360
    private static let fieldHeight: CGFloat = 24
    private static let singleFieldWidth: CGFloat = 320

    /// 返回 `parameter.key → 用户输入`；取消为 `nil`。
    static func collect(
        parameters: [SnippetAskParameter],
        snippetName: String
    ) -> [String: String]? {
        guard !parameters.isEmpty else { return [:] }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.informativeText = L10n.Snippets.Ask.forSnippet(snippetName)
        alert.addButton(withTitle: L10n.Snippets.Ask.continueButton)
        alert.addButton(withTitle: L10n.Action.cancel)

        let fields: [NSTextField]
        if parameters.count == 1, let only = parameters.first {
            alert.messageText = only.prompt
            let field = makeField(for: only, width: singleFieldWidth)
            alert.accessoryView = field
            fields = [field]
            alert.window.initialFirstResponder = field
        } else {
            alert.messageText = L10n.Snippets.Ask.formTitle
            let (container, builtFields) = makeForm(parameters: parameters)
            alert.accessoryView = container
            fields = builtFields
            if let first = builtFields.first {
                alert.window.initialFirstResponder = first
            }
        }

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        var values: [String: String] = [:]
        for (parameter, field) in zip(parameters, fields) {
            values[parameter.key] = field.stringValue
        }
        return values
    }

    /// 固定宽度容器 + 手排 frame，避免 NSStackView 按 placeholder 长短把某行输入框压窄。
    private static func makeForm(parameters: [SnippetAskParameter]) -> (NSView, [NSTextField]) {
        let labelFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        let rowGap: CGFloat = 10
        let labelFieldGap: CGFloat = 4
        let topInset: CGFloat = 4

        struct RowLayout {
            var prompt: String
            var parameter: SnippetAskParameter
            var labelHeight: CGFloat
        }

        let rows: [RowLayout] = parameters.map { parameter in
            let labelHeight = measureLabelHeight(parameter.prompt, font: labelFont, width: formWidth)
            return RowLayout(prompt: parameter.prompt, parameter: parameter, labelHeight: labelHeight)
        }

        let contentHeight = rows.reduce(CGFloat(0)) { partial, row in
            partial + row.labelHeight + labelFieldGap + fieldHeight
        }
        let totalHeight = topInset
            + contentHeight
            + CGFloat(max(rows.count - 1, 0)) * rowGap

        let container = NSView(frame: NSRect(x: 0, y: 0, width: formWidth, height: totalHeight))
        var fields: [NSTextField] = []
        var y = totalHeight - topInset

        for row in rows {
            y -= row.labelHeight
            let label = NSTextField(labelWithString: row.prompt)
            label.font = labelFont
            label.textColor = .secondaryLabelColor
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 2
            label.isEditable = false
            label.isBordered = false
            label.drawsBackground = false
            label.frame = NSRect(x: 0, y: y, width: formWidth, height: row.labelHeight)
            container.addSubview(label)

            y -= labelFieldGap + fieldHeight
            let field = makeField(for: row.parameter, width: formWidth)
            field.frame.origin = NSPoint(x: 0, y: y)
            container.addSubview(field)
            fields.append(field)

            y -= rowGap
        }

        return (container, fields)
    }

    private static func measureLabelHeight(_ text: String, font: NSFont, width: CGFloat) -> CGFloat {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        let size = label.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: width, height: 10_000))
            ?? NSSize(width: width, height: font.boundingRectForFont.height)
        return max(ceil(size.height), ceil(font.boundingRectForFont.height))
    }

    private static func makeField(for parameter: SnippetAskParameter, width: CGFloat) -> NSTextField {
        let frame = NSRect(x: 0, y: 0, width: width, height: fieldHeight)
        let field: NSTextField = parameter.isSecret
            ? NSSecureTextField(frame: frame)
            : NSTextField(frame: frame)
        field.isEditable = true
        field.isBordered = true
        field.bezelStyle = .squareBezel
        field.placeholderString = parameter.prompt
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        // 明确关掉 Auto Layout，只用 frame，避免 accessory 布局按内在宽度压缩短 placeholder 行
        field.translatesAutoresizingMaskIntoConstraints = true
        field.autoresizingMask = []
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.required, for: .horizontal)
        return field
    }
}
