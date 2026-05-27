import SwiftUI

struct FilteredBookingsView: View {
    let pack: (overall: [Reservation], rooms: [Reservation], deptsSchools: [Reservation], raw: [Reservation], semesters: [String])
    @Binding var edits: [PendingEdit]
    let onSave: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        let filtered = pack.raw.filter { $0.filteredOut }
        let misformatted = filtered.filter { $0.filterReason.contains("Room 000") }
        let columns = filtered.first.map { Array($0.rawData.keys).sorted() } ?? []

        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Raw Data & Filtering")
                        .font(.title2.weight(.semibold))
                    Text("Below is the original imported data. Bookings filtered out are indicated in the Filtered Out and Filter Reason columns.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("There are **\(filtered.count)** bookings filtered out.")
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(8)
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

            // Tables
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !misformatted.isEmpty {
                        CollapsibleTableView(
                            title: "Misformatted Rooms",
                            data: misformatted,
                            columns: columns,
                            edits: $edits,
                            defaultIncluded: false
                        )
                    }

                    if !filtered.isEmpty {
                        CollapsibleTableView(
                            title: "Filtered Bookings",
                            data: filtered,
                            columns: columns,
                            edits: $edits,
                            defaultIncluded: false
                        )
                    }

                    if filtered.isEmpty {
                        Text("No filtered bookings found.")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            }
        }
        .padding()
    }
}
