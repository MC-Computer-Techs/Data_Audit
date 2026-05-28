import SwiftUI

struct GroupingPairsView: View {
    let pack: (overall: [Reservation], rooms: [Reservation], deptsSchools: [Reservation], raw: [Reservation], semesters: [String])
    @Binding var edits: [PendingEdit]
    let onSave: () -> Void
    let onDiscard: () -> Void

    @State private var searchText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Generated Grouping Pairs")
                        .font(.title2.weight(.semibold))
                    Text("Edit values below to update quantities. Click save to recalculate totals.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()

                // Search bar
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search bookings… (⌘F)", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !edits.isEmpty {
                    Button(action: onDiscard) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                            Text("Discard Changes")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                Button(action: onSave) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save Changes")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(edits.isEmpty)
            }
            .padding(.bottom, 16)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(pack.semesters, id: \.self) { sem in
                        semesterSection(sem: sem)
                        Divider()
                    }
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private func semesterSection(sem: String) -> some View {
        let code = getSemesterCode(sem)
        let schoolsData = pack.deptsSchools.filter { $0.semester == sem }
            .sorted { ($0.rawData["Clean School"] ?? "") < ($1.rawData["Clean School"] ?? "") }
        let deptsData = pack.deptsSchools.filter { $0.semester == sem }
            .sorted { ($0.rawData["Clean Department"] ?? "") < ($1.rawData["Clean Department"] ?? "") }
        let roomsData = pack.rooms.filter { $0.semester == sem }
            .sorted { ($0.rawData["Clean Room"] ?? "") < ($1.rawData["Clean Room"] ?? "") }

        VStack(alignment: .leading, spacing: 8) {
            Text("\(code) (\(sem))")
                .font(.title3.weight(.semibold))
                .foregroundColor(.blue)

            CollapsibleTableView(
                title: "Schools",
                data: schoolsData,
                columns: orderedColumns(for: schoolsData, type: .schools),
                edits: $edits,
                defaultIncluded: true,
                searchText: searchText
            )

            CollapsibleTableView(
                title: "Departments",
                data: deptsData,
                columns: orderedColumns(for: deptsData, type: .departments),
                edits: $edits,
                defaultIncluded: true,
                searchText: searchText
            )

            CollapsibleTableView(
                title: "Rooms",
                data: roomsData,
                columns: orderedColumns(for: roomsData, type: .rooms),
                edits: $edits,
                defaultIncluded: true,
                searchText: searchText
            )
        }
    }

    private enum TableType {
        case schools
        case departments
        case rooms
    }

    /// Canonical column order matching the exported CSV files
    private static let baseColumnOrder: [String] = [
        "Request #",
        "Department",
        "Role (Affiliation)",
        "Room(s)",
        "Booking Start Date",
        "Booking End Date",
        "Booking Start Time",
        "Booking End Time",
        "Time In Use, Hours",
        "# rooms used",
        "ACTUAL hours",
        "Reservation Title",
        "Reservation Description",
        "Expected Attendance",
        "Reservation Origin",
        "Booking Type",
        "Attendee Affiliation(s)",
        "End Event Status",
        "Room Setup Needed (Y/N)",
        "Room Setup Details",
        "Media Services (Y/N)",
        "Media Service Details",
        "Catering (Y/N)",
        "Hire Security (Y/N)",
        "_raw_id",
        "Filtered Out",
        "Filter Reason",
        "Semester",
        "Calc Hours"
    ]

    private static let deptsSchoolsTrailingColumns = ["All Depts", "Clean Department", "Clean School"]
    private static let roomsTrailingColumns = ["Clean Room"]

    private func orderedColumns(for data: [Reservation], type: TableType) -> [String] {
        guard let first = data.first else { return [] }
        let available = Set(first.rawData.keys)

        let trailing: [String]
        let priorityColumn: String?
        
        switch type {
        case .schools:
            trailing = Self.deptsSchoolsTrailingColumns
            priorityColumn = "Clean School"
        case .departments:
            trailing = Self.deptsSchoolsTrailingColumns
            priorityColumn = "Clean Department"
        case .rooms:
            trailing = Self.roomsTrailingColumns
            priorityColumn = "Clean Room"
        }

        // Start with columns in canonical order that exist in the data
        var result = Self.baseColumnOrder.filter { available.contains($0) }

        // Add trailing type-specific columns
        for col in trailing {
            if available.contains(col) && !result.contains(col) {
                result.append(col)
            }
        }
        
        // Move the priority column immediately after 'Request #'
        if let pCol = priorityColumn, result.contains(pCol) {
            result.removeAll(where: { $0 == pCol })
            if let reqIndex = result.firstIndex(of: "Request #") {
                result.insert(pCol, at: reqIndex + 1)
            } else {
                result.insert(pCol, at: 0)
            }
        }

        // Append any remaining columns not yet included (alphabetically)
        let remaining = available.subtracting(Set(result)).sorted()
        result.append(contentsOf: remaining)

        return result
    }

    private func getSemesterCode(_ sem: String) -> String {
        let suffix = String(sem.suffix(2))
        if sem.contains("Fall") { return "F\(suffix)" }
        if sem.contains("Winter") { return "W\(suffix)" }
        if sem.contains("Spring") { return "Sp\(suffix)" }
        if sem.contains("Summer") { return "Su\(suffix)" }
        return "Other"
    }
}
