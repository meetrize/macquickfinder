import SwiftUI

struct RecordedScriptValidationResultView: View {
    let result: RecordedScriptValidationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if result.isSuccessful {
                Label(L10n.OperationRecording.Validation.passed, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                ForEach(result.issues) { issue in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: iconName(for: issue.level))
                            .font(.caption)
                            .padding(.top, 1)
                        Text(issue.message)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(color(for: issue.level))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func iconName(for level: RecordedScriptValidationLevel) -> String {
        switch level {
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    private func color(for level: RecordedScriptValidationLevel) -> Color {
        switch level {
        case .error: return .red
        case .warning: return .orange
        }
    }
}
