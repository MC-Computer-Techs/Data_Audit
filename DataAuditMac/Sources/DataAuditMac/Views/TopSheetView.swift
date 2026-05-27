import SwiftUI
import UniformTypeIdentifiers

struct TopSheetView: View {
    let pack: (overall: [Reservation], rooms: [Reservation], deptsSchools: [Reservation], raw: [Reservation], semesters: [String])

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with download buttons
                HStack {
                    Text("Top Sheet Overview")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Button(action: downloadPDF) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                            Text("Download PDF")
                        }
                    }
                    .buttonStyle(.bordered)
                }

                // Metric cards
                HStack(spacing: 16) {
                    MetricCard(
                        label: "Total Reservations",
                        value: "\(pack.overall.count)"
                    )
                    MetricCard(
                        label: "Total Hours",
                        value: String(format: "%.2f", pack.overall.reduce(0) { $0 + $1.calcHours })
                    )
                }

                // Top Sheet Table
                topSheetTable
            }
            .padding()
        }
    }

    private var topSheetTable: some View {
        let sems = pack.semesters
        let rows = buildTopSheetRows(sems: sems)

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                let isHeaderRow = row.isHeader
                let isSectionTitle = row.isSectionTitle

                HStack(spacing: 0) {
                    // First column (label)
                    Text(row.cells[0])
                        .font(.system(size: 13, weight: (isHeaderRow || isSectionTitle) ? .bold : .regular))
                        .foregroundColor(isHeaderRow ? .white : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, (isSectionTitle || isHeaderRow) ? 8 : 20)
                        .padding(.vertical, 8)

                    // Semester columns + Total
                    ForEach(1..<row.cells.count, id: \.self) { j in
                        Text(row.cells[j])
                            .font(.system(size: 13, weight: isHeaderRow ? .bold : .regular))
                            .foregroundColor(isHeaderRow ? .white : .primary)
                            .frame(width: 90, alignment: .trailing)
                            .padding(.vertical, 8)
                    }
                }
                .background(
                    isHeaderRow
                        ? Color.blue.opacity(0.8)
                        : isSectionTitle
                            ? Color(nsColor: .controlBackgroundColor)
                            : Color.clear
                )

                if !isHeaderRow {
                    Divider()
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    private func downloadPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.nameFieldStringValue = "DataAudit_TopSheet.pdf"
        if panel.runModal() == .OK, let url = panel.url {
            Task { @MainActor in
                PDFGenerator.generatePDF(from: pack, title: "Data Audit Report", to: url)
            }
        }
    }

    // Build structured rows for the table
    private func buildTopSheetRows(sems: [String]) -> [TopSheetRow] {
        var rows = [TopSheetRow]()

        // Header
        rows.append(TopSheetRow(cells: [""] + sems + ["Total:"], isHeader: true))

        // Totals
        let totalRes = sems.map { s in pack.overall.filter({ $0.semester == s }).count }
        let totalHrs = sems.map { s in pack.overall.filter({ $0.semester == s }).reduce(0) { $0 + $1.calcHours } }

        rows.append(TopSheetRow(cells: ["Total # of reservations:"] + Array(repeating: "", count: sems.count) + ["\(pack.overall.count)"], isSectionTitle: true))
        rows.append(TopSheetRow(cells: ["Hours"] + totalHrs.map { String(format: "%.2f", $0) } + [String(format: "%.2f", totalHrs.reduce(0, +))], isSectionTitle: true))
        rows.append(TopSheetRow(cells: ["Reservations"] + totalRes.map { "\($0)" } + ["\(totalRes.reduce(0, +))"], isSectionTitle: true))

        // Rooms
        let roomOrder = ["1201 Seminar Room", "233 Co-Lab", "230 Audio Lab", "221-224 Ballrooms", "220 Blackbox", "202 Lecture Hall", "103 Garage", "260 Post Production Lab"]
        rows.append(TopSheetRow(cells: ["Reservations per room:"] + Array(repeating: "", count: sems.count + 1), isSectionTitle: true))
        for room in roomOrder {
            let vals = sems.map { s in pack.rooms.filter({ $0.semester == s && $0.rawData["Clean Room"] == room }).count }
            rows.append(TopSheetRow(cells: [room] + vals.map { "\($0)" } + ["\(vals.reduce(0, +))"]))
        }

        rows.append(TopSheetRow(cells: ["Hours per room:"] + Array(repeating: "", count: sems.count + 1), isSectionTitle: true))
        for room in roomOrder {
            let vals = sems.map { s in pack.rooms.filter({ $0.semester == s && $0.rawData["Clean Room"] == room }).reduce(0) { $0 + $1.calcHours } }
            rows.append(TopSheetRow(cells: [room] + vals.map { String(format: "%.2f", $0) } + [String(format: "%.2f", vals.reduce(0, +))]))
        }

        // Programs
        let progOrder = ["ALT (Ed Leadership, ECT, and Higher and Post Secondary Education)", "IDM", "ITP / IMA / Low Res", "CDI / Recorded Music", "Music Tech", "MARL", "MPAP", "Game Center", "Other Group(s)", "Community Partner"]
        rows.append(TopSheetRow(cells: ["Reservations per program:"] + Array(repeating: "", count: sems.count + 1), isSectionTitle: true))
        for prog in progOrder {
            let vals = sems.map { s in pack.deptsSchools.filter({ $0.semester == s && $0.rawData["Clean Department"] == prog }).count }
            rows.append(TopSheetRow(cells: [prog] + vals.map { "\($0)" } + ["\(vals.reduce(0, +))"]))
        }

        rows.append(TopSheetRow(cells: ["Hours per Program:"] + Array(repeating: "", count: sems.count + 1), isSectionTitle: true))
        for prog in progOrder {
            let vals = sems.map { s in pack.deptsSchools.filter({ $0.semester == s && $0.rawData["Clean Department"] == prog }).reduce(0) { $0 + $1.calcHours } }
            rows.append(TopSheetRow(cells: [prog] + vals.map { String(format: "%.2f", $0) } + [String(format: "%.2f", vals.reduce(0, +))]))
        }

        // Schools
        let schoolOrder = ["Tandon", "Tisch", "Steinhardt", "Provost", "URPA / Community Partner", "Central", "Greater NYU", "Other Schools"]
        rows.append(TopSheetRow(cells: ["Reservations per School:"] + Array(repeating: "", count: sems.count + 1), isSectionTitle: true))
        for school in schoolOrder {
            let vals = sems.map { s in pack.deptsSchools.filter({ $0.semester == s && $0.rawData["Clean School"] == school }).count }
            rows.append(TopSheetRow(cells: [school] + vals.map { "\($0)" } + ["\(vals.reduce(0, +))"]))
        }

        rows.append(TopSheetRow(cells: ["Hours per School:"] + Array(repeating: "", count: sems.count + 1), isSectionTitle: true))
        for school in schoolOrder {
            let vals = sems.map { s in pack.deptsSchools.filter({ $0.semester == s && $0.rawData["Clean School"] == school }).reduce(0) { $0 + $1.calcHours } }
            rows.append(TopSheetRow(cells: [school] + vals.map { String(format: "%.2f", $0) } + [String(format: "%.2f", vals.reduce(0, +))]))
        }

        return rows
    }
}

private struct TopSheetRow {
    let cells: [String]
    var isHeader: Bool = false
    var isSectionTitle: Bool = false
}

struct MetricCard: View {
    let label: String
    let value: String
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundColor(.secondary)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(isHovering ? 0.15 : 0.05), radius: isHovering ? 12 : 4, y: isHovering ? -4 : 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovering ? Color.blue.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .onHover { hovering in isHovering = hovering }
    }
}
