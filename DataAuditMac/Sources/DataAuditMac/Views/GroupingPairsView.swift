import SwiftUI

struct GroupingPairsView: View {
    let pack: (overall: [Reservation], rooms: [Reservation], deptsSchools: [Reservation], raw: [Reservation], semesters: [String])
    @Binding var edits: [PendingEdit]
    let onSave: () -> Void
    let onDiscard: () -> Void

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
                columns: columnsFrom(schoolsData),
                edits: $edits,
                defaultIncluded: true
            )

            CollapsibleTableView(
                title: "Departments",
                data: deptsData,
                columns: columnsFrom(deptsData),
                edits: $edits,
                defaultIncluded: true
            )

            CollapsibleTableView(
                title: "Rooms",
                data: roomsData,
                columns: columnsFrom(roomsData),
                edits: $edits,
                defaultIncluded: true
            )
        }
    }

    private func columnsFrom(_ data: [Reservation]) -> [String] {
        guard let first = data.first else { return [] }
        return first.rawData.keys.sorted()
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
