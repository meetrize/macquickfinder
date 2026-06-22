import AppKit
import Foundation

public enum FileListColumnID: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case name
    case type
    case size
    case dateModified
    
    public var id: String { rawValue }
    
    /// 表头显示（不参与本地化，便于与 NSTableColumn 对应）
    public var headerTitle: String {
        switch self {
        case .name: return "Name"
        case .type: return "Type"
        case .size: return "Size"
        case .dateModified: return "Date Modified"
        }
    }
    
    /// 表头右键菜单显示名
    public var menuTitle: String {
        switch self {
        case .name: return "名称"
        case .type: return "类型"
        case .size: return "大小"
        case .dateModified: return "修改日期"
        }
    }
    
    public var knownHeaderTitles: [String] {
        switch self {
        case .name: return ["Name", "名称"]
        case .type: return ["Type", "类型"]
        case .size: return ["Size", "大小"]
        case .dateModified: return ["Date Modified", "修改日期", "修改时间"]
        }
    }
    
    public static func from(title: String) -> FileListColumnID? {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return allCases.first { $0.knownHeaderTitles.contains(normalized) }
    }
    
    public static func from(column: NSTableColumn) -> FileListColumnID? {
        if let id = FileListColumnID(rawValue: column.identifier.rawValue) {
            return id
        }
        return from(title: column.title)
    }
    
    public static func defaultOrderIndex(for columnID: FileListColumnID) -> Int {
        allCases.firstIndex(of: columnID) ?? Int.max
    }
    
    /// 可在表头右键菜单中显示/隐藏、调整顺序的列（不含名称列）
    public static let menuToggleableCases: [FileListColumnID] = [.type, .size, .dateModified]
    
    public var isMenuToggleable: Bool {
        Self.menuToggleableCases.contains(self)
    }
    
    public var minWidth: CGFloat {
        switch self {
        case .name: return 220
        case .type: return 80
        case .size: return 80
        case .dateModified: return 150
        }
    }
    
    public var idealWidth: CGFloat {
        switch self {
        case .name: return 300
        case .type: return 110
        case .size: return 100
        case .dateModified: return 180
        }
    }
    
    public var maxWidth: CGFloat {
        switch self {
        case .name: return 960
        case .type: return 320
        case .size: return 280
        case .dateModified: return 520
        }
    }
}

public struct FileListColumnConfiguration: Equatable, Codable, Sendable {
    public var order: [FileListColumnID]
    public var visible: Set<FileListColumnID>
    public var widths: [String: Double]
    
    public static let `default` = FileListColumnConfiguration(
        order: FileListColumnID.allCases,
        visible: Set(FileListColumnID.allCases),
        widths: [:]
    )
    
    public init(
        order: [FileListColumnID],
        visible: Set<FileListColumnID>,
        widths: [String: Double] = [:]
    ) {
        self.order = order
        self.visible = visible
        self.widths = widths
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        order = try container.decode([FileListColumnID].self, forKey: .order)
        visible = try container.decode(Set<FileListColumnID>.self, forKey: .visible)
        widths = try container.decodeIfPresent([String: Double].self, forKey: .widths) ?? [:]
    }
    
    private enum CodingKeys: String, CodingKey {
        case order, visible, widths
    }
    
    public func width(for columnID: FileListColumnID) -> CGFloat? {
        widths[columnID.rawValue].map { CGFloat($0) }
    }
    
    public mutating func setWidth(_ width: CGFloat, for columnID: FileListColumnID) {
        widths[columnID.rawValue] = Double(width)
    }
    
    public mutating func toggleVisibility(_ column: FileListColumnID) -> Bool {
        guard column.isMenuToggleable else { return false }
        if visible.contains(column) {
            guard visible.count > 1 else { return false }
            visible.remove(column)
        } else {
            visible.insert(column)
        }
        visible.insert(.name)
        return true
    }
    
    public mutating func moveColumn(_ column: FileListColumnID, offset: Int) -> Bool {
        guard let index = order.firstIndex(of: column) else { return false }
        let newIndex = index + offset
        guard order.indices.contains(newIndex) else { return false }
        order.swapAt(index, newIndex)
        return true
    }
    
    public func canMoveColumn(_ column: FileListColumnID, offset: Int) -> Bool {
        guard let index = order.firstIndex(of: column) else { return false }
        return order.indices.contains(index + offset)
    }
    
    /// 合并未知列、去重，并保证名称列可见。
    public static func normalized(_ configuration: FileListColumnConfiguration) -> FileListColumnConfiguration {
        var config = configuration
        let allIDs = FileListColumnID.allCases
        let allSet = Set(allIDs)
        
        var normalizedOrder: [FileListColumnID] = []
        for columnID in config.order where allSet.contains(columnID) && !normalizedOrder.contains(columnID) {
            normalizedOrder.append(columnID)
        }
        for columnID in allIDs where !normalizedOrder.contains(columnID) {
            normalizedOrder.append(columnID)
        }
        config.order = normalizedOrder
        
        config.visible = config.visible.intersection(allSet)
        config.visible.insert(.name)
        if config.visible.isEmpty {
            config.visible = allSet
        }
        return config
    }
}
