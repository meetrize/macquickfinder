import FileList

extension FileListRow {
    init(item: FileItem) {
        self.init(item: item, directorySizeDisplay: nil)
    }
    
    init(item: FileItem, directorySizeDisplay: DirectorySizeDisplayInfo?) {
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
            dateDisplay: item.dateDisplay,
            size: effectiveSize,
            modificationDate: item.modificationDate,
            isDirectory: item.isDirectory,
            isHidden: item.isHidden,
            isParentDirectoryEntry: item.isParentDirectoryEntry,
            iconPath: item.url.path
        )
    }
}
