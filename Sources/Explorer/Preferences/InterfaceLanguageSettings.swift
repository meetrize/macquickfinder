import Combine
import FileList
import Foundation

@MainActor
final class InterfaceLanguageSettings: ObservableObject {
    static let shared = InterfaceLanguageSettings()

    @Published private(set) var revision = ModuleLocalization.revision
    @Published var language: InterfaceLanguage {
        didSet {
            if ModuleLocalization.setLanguage(language) {
                revision = ModuleLocalization.revision
            } else if language != ModuleLocalization.currentLanguage {
                language = ModuleLocalization.currentLanguage
            }
        }
    }

    var locale: Locale { ModuleLocalization.effectiveLocale }

    private var cancellable: AnyCancellable?

    private init() {
        language = ModuleLocalization.currentLanguage
        cancellable = NotificationCenter.default.publisher(for: ModuleLocalization.languageDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                language = ModuleLocalization.currentLanguage
                revision = ModuleLocalization.revision
            }
    }
}
