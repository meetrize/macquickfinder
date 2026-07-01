import CoreGraphics
import Foundation

enum PreviewDetachedWindowFrameStore {
    private struct StoredFrame: Codable {
        var width: Double
        var height: Double
    }

    private static func key(for kind: PreviewDetachedWindowContentKind) -> String {
        "preview.detachedFrame.\(kind.rawValue)"
    }

    static func savedContentSize(for kind: PreviewDetachedWindowContentKind) -> CGSize? {
        guard let data = UserDefaultsStorage.data(forKey: key(for: kind)),
              let stored = try? JSONDecoder().decode(StoredFrame.self, from: data),
              stored.width > 0,
              stored.height > 0 else {
            return nil
        }
        return CGSize(width: stored.width, height: stored.height)
    }

    static func saveContentSize(_ size: CGSize, for kind: PreviewDetachedWindowContentKind) {
        guard size.width > 0, size.height > 0 else { return }
        let stored = StoredFrame(width: Double(size.width), height: Double(size.height))
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaultsStorage.set(data, forKey: key(for: kind))
    }
}
