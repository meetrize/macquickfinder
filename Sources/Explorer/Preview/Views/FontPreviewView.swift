import AppKit
import SwiftUI

struct FontPreviewView: View {
    let content: FontPreviewContent
    let textContentInset: CGFloat

    @State private var registrationFailed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                metadataSection
                if registrationFailed {
                    Text(L10n.Preview.Font.registrationFailed)
                        .foregroundStyle(.secondary)
                } else {
                    samplesSection
                }
            }
            .padding(textContentInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            registrationFailed = !registerFontIfNeeded()
        }
        .onDisappear {
            FontPreviewLoader.unregisterFontForPreview(at: content.sourceURL)
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content.metadata.fullName)
                .font(.title2.weight(.semibold))
            metadataRow(label: L10n.Preview.Font.family, value: content.metadata.familyName)
            metadataRow(label: L10n.Preview.Font.style, value: content.metadata.styleName)
            metadataRow(label: L10n.Preview.Font.postScriptName, value: content.metadata.postScriptName)
            metadataRow(label: L10n.Preview.Font.version, value: content.metadata.version)
            metadataRow(label: L10n.Preview.Font.glyphs, value: "\(content.metadata.glyphCount)")
            metadataRow(label: L10n.Preview.Font.copyright, value: content.metadata.copyright)
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var samplesSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.Preview.Font.samples)
                .font(.headline)

            ForEach(FontPreviewLoader.sampleSizes, id: \.self) { size in
                sampleBlock(size: size)
            }
        }
    }

    private func sampleBlock(size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.Preview.Font.pointSize(Int(size.rounded())))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let font = NSFont(name: content.postScriptName, size: size) {
                Text(FontPreviewLoader.englishSample)
                    .font(Font(font))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                Text(FontPreviewLoader.chineseSample)
                    .font(Font(font))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func metadataRow(label: String, value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 88, alignment: .trailing)
                Text(value)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func registerFontIfNeeded() -> Bool {
        do {
            try FontPreviewLoader.registerFontForPreview(at: content.sourceURL)
            return NSFont(name: content.postScriptName, size: 12) != nil
        } catch {
            return false
        }
    }
}
