import FileList

extension FileListSortState {
    init(sortOrder: SortOrder) {
        switch sortOrder {
        case .nameAscending:
            self.init(column: .name, ascending: true)
        case .nameDescending:
            self.init(column: .name, ascending: false)
        case .dateNewest:
            self.init(column: .dateModified, ascending: false)
        case .dateOldest:
            self.init(column: .dateModified, ascending: true)
        case .sizeSmallest:
            self.init(column: .size, ascending: true)
        case .sizeLargest:
            self.init(column: .size, ascending: false)
        }
    }
    
    var explorerSortOrder: SortOrder? {
        switch column {
        case .name:
            return ascending ? .nameAscending : .nameDescending
        case .dateModified:
            return ascending ? .dateOldest : .dateNewest
        case .size:
            return ascending ? .sizeSmallest : .sizeLargest
        case .type:
            return nil
        case .dateCreated, .comment, .tags:
            return nil
        }
    }
}
