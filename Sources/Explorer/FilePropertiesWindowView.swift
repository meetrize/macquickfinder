import SwiftUI
import AppKit
import FileList

struct FilePropertiesWindowView: View {
    @ObservedObject var viewModel: FilePropertiesWindowViewModel

    @State private var newTagText: String = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case tagEditor
        case commentEditor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()

            HStack(alignment: .top, spacing: 18) {
                leftEditorColumn
                rightInfoColumn
            }

            saveStatusBar
        }
        .padding(16)
        .frame(minWidth: 620, minHeight: 460)
    }
}

private extension FilePropertiesWindowView {
    var header: some View {
        HStack(alignment: .center, spacing: 12) {
            let icon = iconForPrimaryItem
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text(viewModel.pathSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(viewModel.primaryItem?.url.path ?? "")
            }

            Spacer()
        }
    }

    var leftEditorColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            tagEditor
            commentEditor
        }
        .frame(maxWidth: 360, alignment: .leading)
    }

    var rightInfoColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            let item = viewModel.primaryItem
            if let item {
                KeyValueRow(key: "类型", value: item.isDirectory ? "文件夹" : (item.url.pathExtension.isEmpty ? "文件" : item.fileType))
                KeyValueRow(key: "大小", value: item.isDirectory ? "--" : item.sizeDisplay)
                KeyValueRow(key: "创建时间", value: item.creationDateDisplay)
                KeyValueRow(key: "修改时间", value: item.dateDisplay)
                KeyValueRow(key: "位置", value: item.url.deletingLastPathComponent().path)
                KeyValueRow(key: "路径", value: item.url.path)
            } else {
                Text("无内容")
                    .foregroundStyle(.secondary)
            }

            if viewModel.items.count > 1 {
                Text("提示：本期编辑会应用到所有选中项目。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    var saveStatusBar: some View {
        HStack {
            Spacer()
            if viewModel.saveState == .idle {
                Text(" ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if case .error = viewModel.saveState {
                Text(viewModel.saveMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text(viewModel.saveMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 18)
    }

    var tagEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("标签")
                    .font(.subheadline)
                if viewModel.isMixedTags && viewModel.items.count > 1 {
                    Text("（当前值不同）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            FlowLayout(spacing: 8) {
                ForEach(viewModel.tags, id: \.self) { tag in
                    TagChip(
                        tag: tag,
                        tint: viewModel.tagTintColor(for: tag),
                        onRemove: { viewModel.removeTag(tag) }
                    )
                }

                // 空状态提示 + 行内输入
                if viewModel.tags.isEmpty {
                    Text("暂无标签")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                }
            }

            HStack(spacing: 8) {
                TextField(
                    "添加标签…",
                    text: $newTagText,
                    onCommit: {
                        viewModel.addTag(newTagText)
                        newTagText = ""
                    }
                )
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .tagEditor)

                Button {
                    viewModel.addTag(newTagText)
                    newTagText = ""
                    focusedField = .tagEditor
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 4)
        }
    }

    var commentEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("注释")
                    .font(.subheadline)
                if viewModel.isMixedComment && viewModel.items.count > 1 {
                    Text("（当前值不同）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ZStack(alignment: .topLeading) {
                if viewModel.comment.isEmpty {
                    Text("添加一些备注，方便日后搜索与识别…")
                        .foregroundStyle(.secondary)
                        .padding(8)
                }

                TextEditor(text: $viewModel.comment)
                    .focused($focusedField, equals: .commentEditor)
                    .frame(minHeight: 120, maxHeight: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.gray.opacity(0.35), lineWidth: 1)
                    )
                    .onChange(of: viewModel.comment) { _ in
                        viewModel.didChangeCommentFromUser()
                    }
            }
        }
    }

    var iconForPrimaryItem: NSImage {
        guard let item = viewModel.primaryItem else {
            return NSWorkspace.shared.icon(forFile: NSHomeDirectory())
        }
        return NSWorkspace.shared.icon(forFile: item.url.path)
    }
}

private struct KeyValueRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(key)
                .foregroundStyle(.secondary)
                .font(.caption)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(.body)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}

private struct TagChip: View {
    let tag: String
    let tint: Color
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 6) {
                Circle()
                    .fill(tint)
                    .frame(width: 10, height: 10)
                Text(tag)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 999)
                    .fill(tint)
            )
        }
        .buttonStyle(.plain)
        .help("点击移除标签：\(tag)")
    }
}

// 简易 FlowLayout：让标签胶囊在可用宽度内自动换行。
private struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat) {
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let width = proposal.width ?? 360

        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: width, height: currentY + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )

            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

