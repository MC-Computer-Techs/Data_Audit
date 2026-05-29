import SwiftUI

struct FilteredBookingsView: View {
    let pack: (overall: [Reservation], rooms: [Reservation], deptsSchools: [Reservation], raw: [Reservation], semesters: [String])
    @Binding var edits: [PendingEdit]
    let savedEdits: Set<String>
    let onSave: () -> Void
    let onDiscard: () -> Void

    @State private var searchText: String = ""

    var body: some View {
        // Only show filtered bookings that are within the selected date range
        let inRangeFiltered = pack.raw.filter { $0.filteredOut && !$0.filterReason.contains("Outside Selected Date Range") && !$0.filterReason.contains("Invalid Date") }
        let noShows = inRangeFiltered.filter { $0.filterReason.contains("No Show") }
        let lateCancellations = inRangeFiltered.filter { $0.filterReason.contains("Late Cancellation") }
        let misformatted = inRangeFiltered.filter { $0.filterReason.contains("Room 000") }
        let otherFiltered = inRangeFiltered.filter { !$0.filterReason.contains("No Show") && !$0.filterReason.contains("Late Cancellation") && !$0.filterReason.contains("Room 000") }
        let columns = orderedColumns(for: inRangeFiltered)

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
                        Text("There are **\(inRangeFiltered.count)** bookings filtered out (\(noShows.count) No Shows, \(lateCancellations.count) Late Cancellations).")
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(8)
                }
                Spacer()

                // Search bar
                VStack {
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

                    HStack {
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
                }
            }
            .padding(.bottom, 16)

            // Tables
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !noShows.isEmpty {
                        CollapsibleTableView(
                            title: "No Shows",
                            data: noShows,
                            columns: columns,
                            edits: $edits,
                            savedEdits: savedEdits,
                            defaultIncluded: false,
                            searchText: searchText
                        )
                    }

                    if !lateCancellations.isEmpty {
                        CollapsibleTableView(
                            title: "Late Cancellations",
                            data: lateCancellations,
                            columns: columns,
                            edits: $edits,
                            savedEdits: savedEdits,
                            defaultIncluded: false,
                            searchText: searchText
                        )
                    }

                    if !misformatted.isEmpty {
                        CollapsibleTableView(
                            title: "Misformatted Rooms",
                            data: misformatted,
                            columns: columns,
                            edits: $edits,
                            savedEdits: savedEdits,
                            defaultIncluded: false,
                            searchText: searchText
                        )
                    }

                    if !otherFiltered.isEmpty {
                        CollapsibleTableView(
                            title: "Other Filtered Bookings",
                            data: otherFiltered,
                            columns: columns,
                            edits: $edits,
                            savedEdits: savedEdits,
                            defaultIncluded: false,
                            searchText: searchText
                        )
                    }

                    if inRangeFiltered.isEmpty {
                        Text("No filtered bookings found within the selected date range.")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            }
        }
        .padding()
    }

    /// Canonical column order matching the exported CSV files
    private static let baseColumnOrder: [String] = [
        "Request #",
        "Filter Reason",
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
        "Semester",
        "Calc Hours",
        "All Depts",
        "Clean Department",
        "Clean School",
        "Clean Room"
    ]

    private func orderedColumns(for data: [Reservation]) -> [String] {
        guard let first = data.first else { return [] }
        let available = Set(first.rawData.keys)

        // Start with columns in canonical order that exist in the data
        var result = Self.baseColumnOrder.filter { available.contains($0) }

        // Append any remaining columns not yet included (alphabetically)
        let remaining = available.subtracting(Set(result)).sorted()
        result.append(contentsOf: remaining)

        return result
    }
}
