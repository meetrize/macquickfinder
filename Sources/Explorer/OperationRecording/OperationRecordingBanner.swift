import SwiftUI

struct OperationRecordingBanner: View {
    @ObservedObject var recorder: OperationRecorder
    @AppStorage(AppPreferences.OperationRecording.showBanner) private var showBanner = true

    let onStopAndGenerate: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        if recorder.isRecording, showBanner {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)

                Text(L10n.OperationRecording.bannerMessage(recorder.stepCount))
                    .font(.subheadline)

                Spacer(minLength: 8)

                Button(L10n.OperationRecording.bannerStop, action: onStopAndGenerate)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                Button(L10n.OperationRecording.bannerDiscard, role: .destructive, action: onDiscard)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.08))
            .overlay(alignment: .bottom) {
                Divider()
            }
        }
    }
}
