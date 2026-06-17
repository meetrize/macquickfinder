import AppKit

@objc(FileListThumbnailItem)
final class FileListThumbnailItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("FileListThumbnailItem")
    
    private(set) var representedRowID: String?
    private(set) var loadToken = UUID()
    private(set) var hasLoadedContent = false
    
    private var cellView: FileListThumbnailCellView? {
        view as? FileListThumbnailCellView
    }
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
        identifier = Self.identifier
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = FileListThumbnailCellView(frame: .zero)
    }
    
    func beginLoad(for rowID: String) -> UUID {
        representedRowID = rowID
        hasLoadedContent = false
        let token = UUID()
        loadToken = token
        return token
    }
    
    func configure(
        row: FileListRow,
        isSelected: Bool,
        highlightText: String,
        placeholderImage: NSImage
    ) {
        representedRowID = row.id
        cellView?.configure(
            row: row,
            isSelected: isSelected,
            highlightText: highlightText,
            placeholderImage: placeholderImage
        )
    }
    
    func applyLoadedImage(_ image: NSImage, isThumbnail: Bool, animated: Bool) {
        guard representedRowID != nil else { return }
        hasLoadedContent = true
        cellView?.applyLoadedImage(image, isThumbnail: isThumbnail, animated: animated)
    }
    
    func updateSelection(_ isSelected: Bool, highlightText: String, row: FileListRow) {
        cellView?.updateSelection(isSelected, highlightText: highlightText, row: row)
    }
    
    func setDropTargetHighlighted(_ highlighted: Bool) {
        cellView?.setDropTargetHighlighted(highlighted)
    }
    
    func beginRename(
        name: String,
        onCommit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        cellView?.beginRename(name: name, onCommit: onCommit, onCancel: onCancel)
    }
    
    func endRename() {
        cellView?.endRename()
    }
}
