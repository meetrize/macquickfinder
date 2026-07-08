import CoreServices
import Foundation

/// 单条 FSEvent 路径与标志（供增量 listing 补丁判断）。
public struct DirectoryFSEvent: Sendable, Equatable {
    public let path: String
    public let flags: UInt32

    public init(path: String, flags: UInt32) {
        self.path = path
        self.flags = flags
    }

    public var isCreated: Bool {
        flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0
    }

    public var isRemoved: Bool {
        flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0
    }

    public var isRenamed: Bool {
        flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0
    }

    public var isModified: Bool {
        flags & UInt32(kFSEventStreamEventFlagItemModified) != 0
    }
}
