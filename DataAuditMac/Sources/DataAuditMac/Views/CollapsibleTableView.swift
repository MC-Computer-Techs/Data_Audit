import SwiftUI

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
    @State private var sortKey: String? = nil
    @State private var sortAscending = true
    @State private var selectedCells: Set<String> = []
    @State private var dragStartCell: (rowIndex: Int, col: String)? = nil
    @State private var isDragging = false

    private let readOnlyColumns: Set<String> = [
        "Calc Hours", "ACTUAL hours", "Time In Use, Hours",
        "_raw_id", "Filtered Out", "Filter Reason", "All Depts"
    ]

    var body: some View {
        if data.isEmpty { EmptyView() } else { content }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsible header
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
                tableContent
                    .padding(.top, 6)
            }
        }
        .padding(.bottom, 8)
    }

    private var sortedData: [Reservation] {
        guard let key = sortKey else { return data }
        return data.sorted { a, b in
            let aEdit = edits.first(where: { $0.rawId == a.id && $0.column == key })
            let bEdit = edits.first(where: { $0.rawId == b.id && $0.column == key })
            let aVal = aEdit?.value ?? a.rawData[key] ?? ""
            let bVal = bEdit?.value ?? b.rawData[key] ?? ""

            // Try numeric comparison
            if let aNum = Double(aVal), let bNum = Double(bVal) {
                return sortAscending ? aNum < bNum : aNum > bNum
            }
            return sortAscending
                ? aVal.localizedCaseInsensitiveCompare(bVal) == .orderedAscending
                : aVal.localizedCaseInsensitiveCompare(bVal) == .orderedDescending
        }
    }

    private var tableContent: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    Text("Include")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .center)
                        .padding(.vertical, 8)
                        .background(Color(nsColor: .controlBackgroundColor))

                    ForEach(columns, id: \.self) { col in
                        Button(action: {
                            if sortKey == col {
                                sortAscending.toggle()
                            } else {
                                sortKey = col
                                sortAscending = true
                            }
                        }) {
                            HStack(spacing: 2) {
                                Text(col)
                                    .font(.caption.weight(.semibold))
                                    .textCase(.uppercase)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                if sortKey == col {
                                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(width: columnWidth(for: col), alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                    }
                }

                Divider()

                // Data rows
                let sorted = sortedData
                ForEach(Array(sorted.enumerated()), id: \.offset) { idx, res in
                    dataRow(res: res, rowIndex: idx, sortedData: sorted)
                    Divider()
                }
            }
        }
        .frame(maxHeight: 500)
        .border(Color.gray.opacity(0.3), width: 1)
        .cornerRadius(6)
    }

    private func dataRow(res: Reservation, rowIndex: Int, sortedData: [Reservation]) -> some View {
        let bgColor: Color = defaultIncluded ? .clear : Color.red.opacity(0.06)

        return HStack(spacing: 0) {
            // Include checkbox
            let filterEdit = edits.first(where: { $0.rawId == res.id && $0.column == "Manual Override Filtered" })
            let isIncluded: Bool = {
                if let edit = filterEdit {
                    return edit.value == "false"  // "false" means override = include it
                }
                return defaultIncluded
            }()

            Toggle("", isOn: Binding(
                get: { isIncluded },
                set: { newVal in
                    handleCellChange(rawId: res.id, column: "Manual Override Filtered", value: newVal ? "false" : "")
                }
            ))
            .toggleStyle(.checkbox)
            .frame(width: 70, alignment: .center)

            // Data cells
            ForEach(columns, id: \.self) { col in
                let isEditable = !readOnlyColumns.contains(col)
                let edit = edits.first(where: { $0.rawId == res.id && $0.column == col })
                let displayValue = edit?.value ?? res.rawData[col] ?? ""
                let cellId = "\(res.id)-\(col)"
                let isSelected = selectedCells.contains(cellId)
                let hasEdit = edit != nil

                if isEditable {
                    editableCell(
                        cellId: cellId,
                        displayValue: displayValue,
                        rawId: res.id,
                        col: col,
                        rowIndex: rowIndex,
                        isSelected: isSelected,
                        hasEdit: hasEdit,
                        sortedData: sortedData
                    )
                    .frame(width: columnWidth(for: col))
                } else {
                    Text(displayValue)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .frame(width: columnWidth(for: col), alignment: .leading)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                }
            }
        }
        .background(bgColor)
    }

    private func editableCell(
        cellId: String,
        displayValue: String,
        rawId: Int,
        col: String,
        rowIndex: Int,
        isSelected: Bool,
        hasEdit: Bool,
        sortedData: [Reservation]
    ) -> some View {
        CellTextField(
            value: displayValue,
            isSelected: isSelected,
            hasEdit: hasEdit,
            onChange: { newVal in
                // Batch: if multiple cells selected and this is one of them, update all
                if selectedCells.contains(cellId) && selectedCells.count > 1 {
                    for id in selectedCells {
                        let parts = id.split(separator: "-", maxSplits: 1)
                        if parts.count == 2, let rid = Int(parts[0]) {
                            handleCellChange(rawId: rid, column: String(parts[1]), value: newVal)
                        }
                    }
                } else {
                    handleCellChange(rawId: rawId, column: col, value: newVal)
                }
            },
            onPaste: { pastedText in
                let lines = pastedText.components(separatedBy: .newlines).filter { !$0.isEmpty }
                if lines.count <= 1 && selectedCells.contains(cellId) && selectedCells.count > 1 {
                    // Single paste value → apply to all selected
                    let val = lines.first ?? pastedText
                    for id in selectedCells {
                        let parts = id.split(separator: "-", maxSplits: 1)
                        if parts.count == 2, let rid = Int(parts[0]) {
                            handleCellChange(rawId: rid, column: String(parts[1]), value: val)
                        }
                    }
                } else if lines.count > 1 {
                    // Multi-line paste: each line goes to the next row
                    for (offset, val) in lines.enumerated() {
                        let targetIdx = rowIndex + offset
                        if targetIdx < sortedData.count {
                            let targetRow = sortedData[targetIdx]
                            handleCellChange(rawId: targetRow.id, column: col, value: val)
                        }
                    }
                }
            },
            onSelect: {
                selectedCells = Set([cellId])
                dragStartCell = (rowIndex: rowIndex, col: col)
            }
        )
    }

    private func handleCellChange(rawId: Int, column: String, value: String) {
        if let idx = edits.firstIndex(where: { $0.rawId == rawId && $0.column == column }) {
            edits[idx].value = value
        } else {
            edits.append(PendingEdit(rawId: rawId, column: column, value: value))
        }
    }

    private func columnWidth(for col: String) -> CGFloat {
        let long = ["Reservation Title", "Department", "Clean Department", "Room(s)", "Filter Reason", "All Depts"]
        if long.contains(col) { return 200 }
        let medium = ["Clean School", "Clean Room", "Booking Start Date", "Booking End Date", "End Event Status", "Booking Type"]
        if medium.contains(col) { return 140 }
        return 100
    }
}

// MARK: - CellTextField

struct CellTextField: NSViewRepresentable {
    let value: String
    let isSelected: Bool
    let hasEdit: Bool
    let onChange: (String) -> Void
    let onPaste: (String) -> Void
    let onSelect: () -> Void

    func makeNSView(context: Context) -> PastableTextField {
        let field = PastableTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.font = NSFont.systemFont(ofSize: 12)
        field.stringValue = value
        field.delegate = context.coordinator
        field.onPasteCallback = { text in onPaste(text) }
        field.onFocusCallback = { onSelect() }
        return field
    }

    func updateNSView(_ nsView: PastableTextField, context: Context) {
        if nsView.stringValue != value {
            nsView.stringValue = value
        }
        if isSelected {
            nsView.drawsBackground = true
            nsView.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.15)
        } else if hasEdit {
            nsView.drawsBackground = true
            nsView.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.1)
        } else {
            nsView.drawsBackground = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let onChange: (String) -> Void
        init(onChange: @escaping (String) -> Void) { self.onChange = onChange }

        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                onChange(field.stringValue)
            }
        }
    }
}

class PastableTextField: NSTextField {
    var onPasteCallback: ((String) -> Void)?
    var onFocusCallback: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result { onFocusCallback?() }
        return result
    }

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        // Check if the change looks like a multi-line paste
        if let text = NSPasteboard.general.string(forType: .string) {
            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
            if lines.count > 1 && self.stringValue.contains(lines[0]) {
                onPasteCallback?(text)
            }
        }
    }
}
