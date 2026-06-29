import SwiftUI

struct ConnectServerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var recentStore: RecentServersStore

    @State private var addressInput: String
    @State private var isConnecting = false
    @State private var errorMessage: String?

    private let mountService: RemoteVolumeMountService
    private let onConnected: (URL) -> Void

    @MainActor
    init(
        recentStore: RecentServersStore,
        mountService: RemoteVolumeMountService = RemoteVolumeMountService(),
        initialAddress: String = "",
        onConnected: @escaping (URL) -> Void
    ) {
        self.recentStore = recentStore
        self.mountService = mountService
        _addressInput = State(initialValue: initialAddress)
        self.onConnected = onConnected
    }

    @MainActor
    init(
        mountService: RemoteVolumeMountService = RemoteVolumeMountService(),
        initialAddress: String = "",
        onConnected: @escaping (URL) -> Void
    ) {
        self.init(
            recentStore: .shared,
            mountService: mountService,
            initialAddress: initialAddress,
            onConnected: onConnected
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.RemoteServer.sheetTitle)
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.RemoteServer.addressPrompt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField(L10n.RemoteServer.addressPlaceholder, text: $addressInput)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isConnecting)
                    .onSubmit {
                        Task { await connect() }
                    }
            }

            Text(L10n.RemoteServer.supportedProtocols)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(L10n.RemoteServer.ftpSecurityNotice)
                .font(.caption)
                .foregroundStyle(.orange)

            if !recentStore.bookmarks.isEmpty {
                recentSection
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isConnecting {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.RemoteServer.connecting)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                Button(L10n.Action.cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isConnecting)

                Button(L10n.RemoteServer.connect) {
                    Task { await connect() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isConnecting || trimmedAddress.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 440)
    }

    private var trimmedAddress: String {
        addressInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.RemoteServer.recentTitle)
                .font(.subheadline.weight(.semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(recentStore.bookmarks) { bookmark in
                        RecentServerBookmarkRow(
                            bookmark: bookmark,
                            isSelected: addressInput == bookmark.urlString,
                            isDisabled: isConnecting,
                            onSelect: {
                                addressInput = bookmark.urlString
                                errorMessage = nil
                            },
                            onRemove: {
                                removeRecentBookmark(bookmark)
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 140)
        }
    }

    private func removeRecentBookmark(_ bookmark: RemoteServerBookmark) {
        recentStore.removeBookmark(id: bookmark.id)
        if addressInput == bookmark.urlString {
            addressInput = ""
        }
    }

    @MainActor
    private func connect() async {
        let input = trimmedAddress
        guard !input.isEmpty else { return }

        isConnecting = true
        errorMessage = nil
        defer { isConnecting = false }

        do {
            let mountURL = try await mountService.connect(input: input)
            if case .success(let serverURL) = RemoteServerURL.normalize(input) {
                recentStore.recordConnection(for: serverURL)
            }
            dismiss()
            onConnected(mountURL)
        } catch let error as RemoteMountError {
            if case .cancelled = error {
                dismiss()
                return
            }
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct RecentServerBookmarkRow: View {
    let bookmark: RemoteServerBookmark
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onSelect) {
                HStack(spacing: 8) {
                    Image(systemName: "externaldrive.badge.wifi")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bookmark.displayName)
                            .lineLimit(1)
                        Text(bookmark.urlString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .help(L10n.RemoteServer.removeFromRecent)
            .disabled(isDisabled)
            .accessibilityLabel(L10n.RemoteServer.removeFromRecent)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : .clear)
        )
        .contextMenu {
            Button(L10n.RemoteServer.removeFromRecent, role: .destructive, action: onRemove)
        }
    }
}
