import XCTest
import FileList

final class FileListPreferencesTests: XCTestCase {
    
    // MARK: - Round trip
    
    func testPreferencesEncodeDecodeRoundTrip() throws {
        var columns = FileListColumnConfiguration.default
        columns.setWidth(280, for: .name)
        columns.setWidth(95, for: .size)
        columns.visible = [.name, .type, .size]
        columns.order = [.name, .size, .type, .dateModified]
        
        let original = FileListPreferences(
            columns: columns,
            sort: FileListSortState(column: .dateModified, ascending: false)
        )
        
        let data = try XCTUnwrap(original.encoded())
        let decoded = try XCTUnwrap(FileListPreferences.decode(from: data))
        
        XCTAssertEqual(decoded, original)
    }
    
    func testEncodedJSONUsesColumnsAndSortKeys() throws {
        let preferences = FileListPreferences.default
        let data = try XCTUnwrap(preferences.encoded())
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        XCTAssertNotNil(json["columns"])
        XCTAssertNotNil(json["sort"])
    }
    
    // MARK: - Legacy migration
    
    func testDecodeLegacyColumnOnlyJSON() throws {
        let legacy = """
        {
            "order": ["name", "type", "size", "dateModified"],
            "visible": ["name", "type", "size", "dateModified"],
            "widths": { "name": 310.0 }
        }
        """
        let data = try XCTUnwrap(legacy.data(using: .utf8))
        
        let decoded = try XCTUnwrap(FileListPreferences.decode(from: data))
        
        XCTAssertEqual(decoded.sort, .default)
        XCTAssertEqual(decoded.columns.width(for: .name), 310)
        XCTAssertEqual(decoded.columns.order, FileListColumnID.allCases)
    }
    
    func testMigrateLegacyColumnData() throws {
        let legacy = """
        {
            "order": ["name", "dateModified", "type", "size"],
            "visible": ["name", "dateModified"],
            "widths": {}
        }
        """
        let data = try XCTUnwrap(legacy.data(using: .utf8))
        
        let migrated = try XCTUnwrap(FileListPreferencesStore.migrateLegacyColumnData(data))
        
        XCTAssertEqual(migrated.sort, .default)
        XCTAssertEqual(migrated.columns.order.first, .name)
        XCTAssertTrue(migrated.columns.visible.contains(.name))
        XCTAssertTrue(migrated.columns.visible.contains(.dateModified))
    }
    
    func testStoreLoadsLegacyUserDefaultsKey() {
        let suiteName = "FileListPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        
        let legacy = """
        {
            "order": ["name", "type", "size", "dateModified"],
            "visible": ["name", "type"],
            "widths": { "type": 120.0 }
        }
        """
        defaults.set(legacy.data(using: .utf8), forKey: FileListStorageKeys.legacyColumns)
        
        let store = FileListPreferencesStore(defaults: defaults)
        
        XCTAssertEqual(store.sort, .default)
        XCTAssertEqual(store.configuration.width(for: .type), 120)
        XCTAssertTrue(store.configuration.visible.contains(.type))
        XCTAssertNotNil(defaults.data(forKey: FileListStorageKeys.preferences))
    }
    
    // MARK: - Normalization
    
    func testColumnNormalizationDedupesOrderAndEnsuresNameVisible() {
        var columns = FileListColumnConfiguration(
            order: [.name, .name, .type],
            visible: [.type],
            widths: [:]
        )
        
        columns = FileListColumnConfiguration.normalized(columns)
        
        XCTAssertEqual(columns.order.filter { $0 == .name }.count, 1)
        XCTAssertTrue(columns.visible.contains(.name))
        XCTAssertEqual(columns.order.count, FileListColumnID.allCases.count)
    }
    
    func testPreferencesNormalizationFixesUnknownSortColumn() {
        let prefs = FileListPreferences(
            columns: .default,
            sort: FileListSortState(column: .name, ascending: false)
        )
        let normalized = FileListPreferences.normalized(prefs)
        XCTAssertEqual(normalized.sort.column, .name)
    }
    
    // MARK: - Store updates
    
    func testStoreUpdateColumnsPersists() {
        let suiteName = "FileListPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        
        let store = FileListPreferencesStore(defaults: defaults)
        var columns = store.configuration
        columns.setWidth(200, for: .name)
        store.updateColumns(columns)
        
        let reloaded = FileListPreferencesStore(defaults: defaults)
        XCTAssertEqual(reloaded.configuration.width(for: .name), 200)
    }
    
    func testStoreUpdateSortPersists() {
        let suiteName = "FileListPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        
        let store = FileListPreferencesStore(defaults: defaults)
        store.updateSort(FileListSortState(column: .size, ascending: false))
        
        let reloaded = FileListPreferencesStore(defaults: defaults)
        XCTAssertEqual(reloaded.sort.column, .size)
        XCTAssertFalse(reloaded.sort.ascending)
    }
    
    func testColumnStoreTypealiasSharesSingleton() {
        XCTAssertTrue(FileListColumnStore.shared === FileListPreferencesStore.shared)
    }
}
