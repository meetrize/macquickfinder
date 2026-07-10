import FileList

extension FileListRow {
    init(item: FileItem) {
        self.init(
            item: item,
            directorySizeDisplay: nil,
            depth: 0,
            parentID: nil,
            isExpandable: item.isDirectory && !item.isParentDirectoryEntry,
            isExpanded: false,
            isExpanding: false,
            expandErrorMessage: nil
        )
    }
    
    init(
        item: FileItem,
        directorySizeDisplay: DirectorySizeDisplayInfo?,
        childCountDisplay: DirectoryItemCountDisplayInfo? = nil,
        depth: Int,
        parentID: String?,
        isExpandable: Bool,
        isExpanded: Bool,
        isExpanding: Bool,
        expandErrorMessage: String?
    ) {
        let effectiveSize: Int64
        let effectiveDisplay: String
        
        if item.isDirectory, !item.isParentDirectoryEntry {
            if let directorySizeDisplay {
                effectiveSize = directorySizeDisplay.sortableSize
                effectiveDisplay = directorySizeDisplay.text
            } else {
                effectiveSize = -1
                effectiveDisplay = "--"
            }
        } else {
            effectiveSize = item.size
            effectiveDisplay = item.sizeDisplay
        }
        
        self.init(
            id: item.id,
            name: item.isParentDirectoryEntry ? ".." : item.name,
            fileType: item.fileType,
            sizeDisplay: effectiveDisplay,
            childCountDisplay: childCountDisplay?.text,
            dateDisplay: item.dateDisplay,
            creationDateDisplay: item.creationDateDisplay,
            comment: item.finderComment,
            tagsDisplay: item.tags.joined(separator: ", "),
            size: effectiveSize,
            modificationDate: item.modificationDate,
            creationDate: item.creationDate,
            isDirectory: item.isDirectory,
            isHidden: item.isHidden,
            isParentDirectoryEntry: item.isParentDirectoryEntry,
            iconPath: item.url.path,
            depth: depth,
            parentID: parentID,
            isExpandable: isExpandable,
            isExpanded: isExpanded,
            isExpanding: isExpanding,
            expandErrorMessage: expandErrorMessage
        )
    }
}

extension FileItem {
    var isApplicationBundle: Bool {
        isDirectory && FileListApplicationBundle.isBundle(path: url.path)
    }
}
