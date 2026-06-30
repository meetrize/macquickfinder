import AppKit
import Foundation

// MARK: - Visible refresh

extension FileListTableController {
    func refreshVisibleNameLabels() {
        guard let tableView else { return }
        guard let nameColumnIndex = tableView.tableColumns.firstIndex(where: {
            FileListColumnID.from(column: $0) == .name
        }) else { return }

        let visible = tableView.rows(in: tableView.visibleRect)
        guard visible.length > 0 else { return }
        let isEmphasized = tableView.window?.isKeyWindow ?? true

        for row in visible.location..<(visible.location + visible.length) {
            guard row >= 0, row < displayRows.count,
                  let cell = tableView.view(atColumn: nameColumnIndex, row: row, makeIfNecessary: false) as? NSTableCellView
            else { continue }
            let item = displayRows[row]
            if renamingRowID == item.id {
                applyRenameField(in: cell, item: item)
            } else {
                applyNameLabel(
                    in: cell,
                    item: item,
                    isSelected: tableView.selectedRowIndexes.contains(row),
                    isEmphasized: isEmphasized
                )
            }
        }
    }
}

// MARK: - NSTableViewDataSource & Delegate

extension FileListTableController: NSTableViewDataSource, NSTableViewDelegate {
    public func numberOfRows(in tableView: NSTableView) -> Int {
        displayRows.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn, row >= 0, row < displayRows.count else { return nil }

        if FileListPaddingColumn.isPadding(tableColumn) {
            let identifier = NSUserInterfaceItemIdentifier("FileListCell.padding")
            if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
                return reused
            }
            let cell = NSTableCellView()
            cell.identifier = identifier
            return cell
        }

        guard let columnID = FileListColumnID.from(column: tableColumn) else { return nil }

        let item = displayRows[row]
        let identifier = NSUserInterfaceItemIdentifier("FileListCell.\(columnID.rawValue)")

        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = makeCell(for: columnID, identifier: identifier)
        }

        configure(cell: cell, columnID: columnID, item: item, row: row)
        return cell
    }

    public func tableViewSelectionDidChange(_ notification: Notification) {
        if isRenaming,
           let rowID = renamingRowID,
           let row = displayRows.firstIndex(where: { $0.id == rowID }),
           let tableView,
           !tableView.selectedRowIndexes.contains(row) {
            cancelRename()
        }
        recordRenameSelectionTimestamps()
        syncSelectionFromTable()
        refreshVisibleRowContentClip()
        refreshVisibleNameLabels()
    }

    public func tableView(
        _ tableView: NSTableView,
        shouldReorderColumn columnIndex: Int,
        toColumn newColumnIndex: Int
    ) -> Bool {
        guard columnIndex >= 0, columnIndex < tableView.tableColumns.count else { return false }
        guard newColumnIndex >= 0, newColumnIndex < tableView.tableColumns.count else { return false }
        let moving = tableView.tableColumns[columnIndex]
        let target = tableView.tableColumns[newColumnIndex]
        return !FileListPaddingColumn.isPadding(moving) && !FileListPaddingColumn.isPadding(target)
    }
}

// MARK: - Cell factory & configuration

extension FileListTableController {
    func makeCell(for columnID: FileListColumnID, identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        switch columnID {
        case .name:
            let disclosure = NSImageView()
            disclosure.identifier = NSUserInterfaceItemIdentifier("FileListCell.name.disclosure")
            disclosure.translatesAutoresizingMaskIntoConstraints = false
            disclosure.imageScaling = .scaleProportionallyDown
            let icon = NSImageView()
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.imageScaling = .scaleProportionallyDown
            let label = FileListTruncatingLabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            let renameField = FileListInlineRenameField()
            renameField.translatesAutoresizingMaskIntoConstraints = false
            renameField.isHidden = true
            renameField.onCommit = { [weak self] newName in
                self?.commitRename(newName: newName)
            }
            renameField.onCancel = { [weak self] in
                self?.cancelRename()
            }
            cell.addSubview(disclosure)
            cell.addSubview(icon)
            cell.addSubview(label)
            cell.addSubview(renameField)
            let iconLeading = icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2)
            iconLeading.identifier = "FileListCell.name.iconLeading"
            NSLayoutConstraint.activate([
                disclosure.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                disclosure.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                disclosure.widthAnchor.constraint(equalToConstant: 12),
                disclosure.heightAnchor.constraint(equalToConstant: 12),
                iconLeading,
                icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 18),
                icon.heightAnchor.constraint(equalToConstant: 18),
                label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                label.topAnchor.constraint(equalTo: cell.topAnchor),
                label.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
                renameField.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 4),
                renameField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            cell.imageView = icon
        default:
            let label = makeTruncatingLabel(truncation: .byTruncatingTail)
            cell.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            cell.textField = label
        }

        return cell
    }

    func configure(cell: NSTableCellView, columnID: FileListColumnID, item: FileListRow, row: Int) {
        if let label = cell.textField {
            applyTruncationSettings(to: label, truncation: .byTruncatingTail)
        }

        switch columnID {
        case .name:
            let indentation = CGFloat(max(0, item.depth)) * 14
            let disclosureSlotWidth: CGFloat = 14
            let disclosureToIconSpacing: CGFloat = 6
            let iconLeading = 2 + indentation + disclosureSlotWidth + disclosureToIconSpacing
            nameIconLeadingConstraint(in: cell)?.constant = iconLeading
            if let disclosure = disclosureImageView(in: cell) {
                disclosure.isHidden = !item.isExpandable
                if item.isExpandable {
                    let symbolName: String
                    if item.isExpanding {
                        symbolName = "clock.arrow.2.circlepath"
                    } else if item.isExpanded {
                        symbolName = "chevron.down"
                    } else {
                        symbolName = "chevron.right"
                    }
                    disclosure.image = NSImage(
                        systemSymbolName: symbolName,
                        accessibilityDescription: "展开折叠"
                    )
                    disclosure.contentTintColor = item.expandErrorMessage == nil ? .tertiaryLabelColor : .systemRed
                }
            }
            if item.isParentDirectoryEntry {
                cell.imageView?.image = Self.parentDirectoryNameCellIcon(for: cell)
            } else {
                configureNameCellIcon(in: cell, item: item)
            }
            let isSelected = tableView?.selectedRowIndexes.contains(row) ?? false
            let isEmphasized = tableView?.window?.isKeyWindow ?? true
            if renamingRowID == item.id {
                applyRenameField(in: cell, item: item)
            } else {
                applyNameLabel(in: cell, item: item, isSelected: isSelected, isEmphasized: isEmphasized)
            }
        case .type:
            cell.textField?.stringValue = item.isParentDirectoryEntry ? "" : item.fileType
            cell.textField?.font = .systemFont(ofSize: NSFont.systemFontSize)
            cell.textField?.textColor = .secondaryLabelColor
        case .size:
            cell.textField?.stringValue = item.isParentDirectoryEntry ? "" : item.sizeDisplay
            cell.textField?.font = .systemFont(ofSize: NSFont.systemFontSize)
            cell.textField?.textColor = .secondaryLabelColor
        case .dateModified:
            cell.textField?.stringValue = item.isParentDirectoryEntry ? "" : item.dateDisplay
            cell.textField?.font = .systemFont(ofSize: NSFont.systemFontSize)
            cell.textField?.textColor = .labelColor
        case .dateCreated:
            cell.textField?.stringValue = item.isParentDirectoryEntry ? "" : item.creationDateDisplay
            cell.textField?.font = .systemFont(ofSize: NSFont.systemFontSize)
            cell.textField?.textColor = .labelColor
        case .comment:
            cell.textField?.stringValue = item.isParentDirectoryEntry ? "" : item.comment
            cell.textField?.font = .systemFont(ofSize: NSFont.systemFontSize)
            cell.textField?.textColor = .secondaryLabelColor
        case .tags:
            cell.textField?.stringValue = item.isParentDirectoryEntry ? "" : item.tagsDisplay
            cell.textField?.font = .systemFont(ofSize: NSFont.systemFontSize)
            cell.textField?.textColor = .secondaryLabelColor
        }
    }

    func isDisclosureTogglePoint(_ point: NSPoint, row: Int, in tableView: NSTableView) -> Bool {
        guard row >= 0, row < displayRows.count else { return false }
        let rowItem = displayRows[row]
        guard rowItem.isExpandable else { return false }
        guard let nameColumnIndex = tableView.tableColumns.firstIndex(where: {
            FileListColumnID.from(column: $0) == .name
        }) else { return false }
        guard let nameCell = tableView.view(atColumn: nameColumnIndex, row: row, makeIfNecessary: false) as? NSTableCellView,
              let disclosure = disclosureImageView(in: nameCell),
              !disclosure.isHidden
        else { return false }
        let pointInCell = nameCell.convert(point, from: tableView)
        return disclosure.frame.insetBy(dx: -4, dy: -2).contains(pointInCell)
    }

    func isRenameNameClickPoint(_ point: NSPoint, row: Int, in tableView: NSTableView) -> Bool {
        guard row >= 0, row < displayRows.count else { return false }
        let column = tableView.column(at: point)
        guard column >= 0, column < tableView.tableColumns.count else { return false }
        guard FileListColumnID.from(column: tableView.tableColumns[column]) == .name else { return false }
        guard let nameCell = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView,
              let label = nameLabel(in: nameCell)
        else { return false }
        // 行处于重命名态时 label 会被隐藏；隐藏 label 不应继续作为“文件名文字点击”命中区。
        guard !label.isHidden else { return false }

        let pointInLabel = label.convert(point, from: tableView)
        guard label.bounds.contains(pointInLabel) else { return false }
        return label.visibleTextRect().contains(pointInLabel)
    }

    func isFileDragStartPoint(_ point: NSPoint, row: Int, in tableView: NSTableView) -> Bool {
        guard row >= 0, row < displayRows.count else { return false }
        let column = tableView.column(at: point)
        guard column >= 0, column < tableView.tableColumns.count else { return false }
        guard FileListColumnID.from(column: tableView.tableColumns[column]) == .name else { return false }
        guard let nameCell = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView else {
            return false
        }

        let pointInCell = nameCell.convert(point, from: tableView)

        if let icon = nameCell.imageView, !icon.isHidden {
            if icon.frame.insetBy(dx: -2, dy: -2).contains(pointInCell) {
                return true
            }
        }

        return isRenameNameClickPoint(point, row: row, in: tableView)
    }

    func applyNameLabel(
        in cell: NSTableCellView,
        item: FileListRow,
        isSelected: Bool,
        isEmphasized: Bool
    ) {
        nameLabel(in: cell)?.isHidden = false
        renameField(in: cell)?.isHidden = true
        let highlightText = interaction.quickSearchText.isEmpty
            ? interaction.searchText
            : interaction.quickSearchText
        nameLabel(in: cell)?.attributedString = FileListTextHighlight.attributedName(
            item.name,
            searchText: highlightText,
            isDirectory: item.isDirectory || item.isParentDirectoryEntry,
            isHidden: item.isHidden,
            isSelected: isSelected,
            isEmphasized: isEmphasized
        )
    }

    func applyRenameField(in cell: NSTableCellView, item: FileListRow) {
        nameLabel(in: cell)?.isHidden = true
        guard let field = renameField(in: cell) else { return }
        field.isHidden = false
        field.stringValue = item.name
        field.font = item.isDirectory
            ? .boldSystemFont(ofSize: NSFont.systemFontSize)
            : .systemFont(ofSize: NSFont.systemFontSize)
        field.updateLayoutWidth(maxAvailableWidth: renameFieldMaxWidth(in: cell))
    }

    func makeTruncatingLabel(truncation: NSLineBreakMode) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        applyTruncationSettings(to: label, truncation: truncation)
        return label
    }

    func applyTruncationSettings(to label: NSTextField, truncation: NSLineBreakMode) {
        label.lineBreakMode = truncation
        label.usesSingleLineMode = true
        if let cell = label.cell as? NSTextFieldCell {
            cell.lineBreakMode = truncation
            cell.truncatesLastVisibleLine = true
            cell.wraps = false
            cell.isScrollable = false
        }
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    func nameLabel(in cell: NSTableCellView) -> FileListTruncatingLabel? {
        cell.subviews.compactMap { $0 as? FileListTruncatingLabel }.first
    }

    func disclosureImageView(in cell: NSTableCellView) -> NSImageView? {
        cell.subviews.first(where: { $0.identifier?.rawValue == "FileListCell.name.disclosure" }) as? NSImageView
    }

    func nameIconLeadingConstraint(in cell: NSTableCellView) -> NSLayoutConstraint? {
        cell.constraints.first(where: { $0.identifier == "FileListCell.name.iconLeading" })
    }
}
