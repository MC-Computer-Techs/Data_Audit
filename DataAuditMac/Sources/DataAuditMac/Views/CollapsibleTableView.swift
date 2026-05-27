import SwiftUI
import AppKit

struct PendingEdit: Equatable {
    let rawId: Int
    let column: String
    var value: String
}

struct CollapsibleTableView: View {
    let title: String
    let data: [Reservation]
    let columns: [String]
    @Binding var edits: [PendingEdit]
    let defaultIncluded: Bool

    @State private var isOpen = false

    var body: some View {
        if data.isEmpty { EmptyView() } else { content }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isOpen.toggle() } }) {
                HStack {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    Text(title)
                        .font(.headline)
                    Text("(\(data.count) records)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            if isOpen {
                NativeTableWrapper(
                    data: data,
                    columns: columns,
                    edits: $edits,
                    defaultIncluded: defaultIncluded
                )
                .frame(height: min(CGFloat(data.count + 1) * 24 + 28, 500))
                .padding(.top, 6)
            }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Native NSTableView Wrapper

struct NativeTableWrapper: NSViewRepresentable {
    let data: [Reservation]
    let columns: [String]
    @Binding var edits: [PendingEdit]
    let defaultIncluded: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(edits: $edits, defaultIncluded: defaultIncluded)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let tableView = NSTableView()
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.allowsColumnSelection = false
        tableView.rowHeight = 22
        tableView.intercellSpacing = NSSize(width: 4, height: 2)
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.headerView = NSTableHeaderView()
        tableView.style = .plain

        // Include column
        let includeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("_include_"))
        includeCol.title = "Include"
        includeCol.width = 60
        includeCol.minWidth = 60
        includeCol.maxWidth = 60
        tableView.addTableColumn(includeCol)

        // Data columns
        for col in columns {
            let tc = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(col))
            tc.title = col
            tc.width = Self.columnWidth(for: col)
            tc.minWidth = 50
            tc.sortDescriptorPrototype = NSSortDescriptor(key: col, ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
            tableView.addTableColumn(tc)
        }

        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        context.coordinator.tableView = tableView
        context.coordinator.sortedData = data
        context.coordinator.currentData = data
        context.coordinator.columns = columns

        scrollView.documentView = tableView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let c = context.coordinator
        let prevEditCount = c.currentEdits.count
        let dataChanged = c.currentData.count != data.count

        c.currentData = data
        c.currentEdits = edits
        c.defaultIncluded = defaultIncluded

        // Full reload when data changes or edits bulk-cleared (discard)
        if dataChanged || (prevEditCount > 0 && edits.isEmpty) {
            c.updateSort()
            c.tableView?.reloadData()
        }
    }

    static func columnWidth(for col: String) -> CGFloat {
        let long = ["Reservation Title", "Department", "Clean Department", "Room(s)", "Filter Reason",
                     "All Depts", "Reservation Description", "Room Setup Details", "Media Service Details"]
        if long.contains(col) { return 200 }
        let medium = ["Clean School", "Clean Room", "Booking Start Date", "Booking End Date",
                       "End Event Status", "Booking Type", "Role (Affiliation)",
                       "Attendee Affiliation(s)", "Reservation Origin"]
        if medium.contains(col) { return 140 }
        return 100
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
        var edits: Binding<[PendingEdit]>
        var defaultIncluded: Bool
        weak var tableView: NSTableView?
        var sortedData: [Reservation] = []
        var currentData: [Reservation] = []
        var currentEdits: [PendingEdit] = []
        var columns: [String] = []
        var sortKey: String? = nil
        var sortAscending: Bool = true

        init(edits: Binding<[PendingEdit]>, defaultIncluded: Bool) {
            self.edits = edits
            self.defaultIncluded = defaultIncluded
        }

        func updateSort() {
            guard let key = sortKey else { sortedData = currentData; return }
            sortedData = currentData.sorted { a, b in
                let aVal = currentEdits.first(where: { $0.rawId == a.id && $0.column == key })?.value ?? a.rawData[key] ?? ""
                let bVal = currentEdits.first(where: { $0.rawId == b.id && $0.column == key })?.value ?? b.rawData[key] ?? ""
                if let aNum = Double(aVal), let bNum = Double(bVal) {
                    return sortAscending ? aNum < bNum : aNum > bNum
                }
                return sortAscending
                    ? aVal.localizedCaseInsensitiveCompare(bVal) == .orderedAscending
                    : aVal.localizedCaseInsensitiveCompare(bVal) == .orderedDescending
            }
        }

        // MARK: DataSource

        func numberOfRows(in tableView: NSTableView) -> Int {
            sortedData.count
        }

        // MARK: Delegate

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let tableColumn = tableColumn, row < sortedData.count else { return nil }
            let colId = tableColumn.identifier.rawValue
            let res = sortedData[row]

            if colId == "_include_" {
                return makeCheckbox(tableView: tableView, res: res, row: row)
            }
            return makeTextCell(tableView: tableView, res: res, colId: colId)
        }

        private func makeCheckbox(tableView: NSTableView, res: Reservation, row: Int) -> NSView {
            let id = NSUserInterfaceItemIdentifier("CheckboxCell")
            let button: NSButton
            if let existing = tableView.makeView(withIdentifier: id, owner: self) as? NSButton {
                button = existing
            } else {
                button = NSButton(checkboxWithTitle: "", target: self, action: #selector(includeToggled(_:)))
                button.identifier = id
            }
            button.tag = row
            let filterEdit = currentEdits.first(where: { $0.rawId == res.id && $0.column == "Manual Override Filtered" })
            let isIncluded = filterEdit.map { $0.value == "false" } ?? defaultIncluded
            button.state = isIncluded ? .on : .off
            return button
        }

        private func makeTextCell(tableView: NSTableView, res: Reservation, colId: String) -> NSView {
            let cellId = NSUserInterfaceItemIdentifier("TextCell")
            let cellView: NSTableCellView
            if let existing = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView {
                cellView = existing
            } else {
                let cv = NSTableCellView()
                let tf = NSTextField()
                tf.isBordered = false
                tf.drawsBackground = false
                tf.isEditable = true
                tf.isSelectable = true
                tf.font = NSFont.systemFont(ofSize: 12)
                tf.cell?.isScrollable = true
                tf.cell?.wraps = false
                tf.cell?.lineBreakMode = .byTruncatingTail
                tf.translatesAutoresizingMaskIntoConstraints = false
                cv.addSubview(tf)
                cv.textField = tf
                NSLayoutConstraint.activate([
                    tf.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 2),
                    tf.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -2),
                    tf.centerYAnchor.constraint(equalTo: cv.centerYAnchor),
                ])
                cv.identifier = cellId
                cellView = cv
            }

            let edit = currentEdits.first(where: { $0.rawId == res.id && $0.column == colId })
            let displayValue = edit?.value ?? res.rawData[colId] ?? ""
            cellView.textField?.stringValue = displayValue
            cellView.textField?.delegate = self

            if edit != nil {
                cellView.textField?.drawsBackground = true
                cellView.textField?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.15)
            } else {
                cellView.textField?.drawsBackground = false
            }
            return cellView
        }

        // MARK: Actions

        @MainActor @objc func includeToggled(_ sender: NSButton) {
            let row = sender.tag
            guard row >= 0, row < sortedData.count else { return }
            let res = sortedData[row]
            let newVal = sender.state == .on ? "false" : ""
            handleCellChange(rawId: res.id, column: "Manual Override Filtered", value: newVal)
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField,
                  let tv = self.tableView else { return }
            let row = tv.row(for: tf)
            let col = tv.column(for: tf)
            guard row >= 0, col >= 0, row < sortedData.count else { return }

            let colId = tv.tableColumns[col].identifier.rawValue
            if colId == "_include_" { return }

            let res = sortedData[row]
            let newVal = tf.stringValue
            let oldVal = currentEdits.first(where: { $0.rawId == res.id && $0.column == colId })?.value ?? res.rawData[colId] ?? ""

            if newVal != oldVal {
                handleCellChange(rawId: res.id, column: colId, value: newVal)
                // Update just this cell's background
                tf.drawsBackground = true
                tf.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.15)
            }
        }

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            if let d = tableView.sortDescriptors.first {
                sortKey = d.key
                sortAscending = d.ascending
            } else {
                sortKey = nil
            }
            updateSort()
            tableView.reloadData()
        }

        private func handleCellChange(rawId: Int, column: String, value: String) {
            if let idx = edits.wrappedValue.firstIndex(where: { $0.rawId == rawId && $0.column == column }) {
                edits.wrappedValue[idx].value = value
            } else {
                edits.wrappedValue.append(PendingEdit(rawId: rawId, column: column, value: value))
            }
            currentEdits = edits.wrappedValue
        }
    }
}
