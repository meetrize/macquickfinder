import FileList

extension FileListRow {
    init(item: FileItem) {
        self.init(
            id: item.id,
            name: item.isParentDirectoryEntry ? ".." : item.name,
            fileType: item.fileType,
            sizeDisplay: item.sizeDisplay,
            dateDisplay: item.dateDisplay,
            size: item.size,
            modificationDate: item.modificationDate,
            isDirectory: item.isDirectory,
            isHidden: item.isHidden,
            isParentDirectoryEntry: item.isParentDirectoryEntry,
            iconPath: item.url.path
        )
    }
}
