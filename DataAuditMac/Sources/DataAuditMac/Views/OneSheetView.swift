import SwiftUI
import UniformTypeIdentifiers

struct OneSheetView: View {
    let oneSheetRows: [[String]]?
    let startDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("One Sheet Update")
                    .font(.title2.weight(.semibold))
                Spacer()
                if oneSheetRows != nil {
                    Button(action: downloadCSV) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                            Text("Download CSV")
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.bottom, 16)

            if let rows = oneSheetRows {
                // Full table rendering
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                            let isAYRow = row.count > 1 && (row[1].contains("AY") || row[1].contains("Term"))

                            HStack(spacing: 0) {
                                ForEach(Array(row.enumerated()), id: \.offset) { j, cell in
                                    Text(cell)
                                        .font(.system(size: 11))
                                        .foregroundColor(isAYRow ? .white : .primary)
                                        .lineLimit(1)
                                        .frame(width: oneSheetColumnWidth(j), alignment: j == 0 || j == 2 ? .leading : .trailing)
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 4)
                                }
                            }
                            .background(
                                isAYRow
                                    ? Color.purple.opacity(0.6)
                                    : (row.count > 1 && row[1].trimmingCharacters(in: .whitespaces).isEmpty)
                                        ? Color(nsColor: .controlBackgroundColor).opacity(0.5)
                                        : Color.clear
                            )
                            Divider()
                        }
                    }
                }
                .border(Color.gray.opacity(0.3), width: 1)
                .cornerRadius(6)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Please upload a Historic One Sheet CSV in the uploader on the previous screen to automatically append this year's metrics to it.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            }
        }
        .padding()
    }

    private func oneSheetColumnWidth(_ index: Int) -> CGFloat {
        switch index {
        case 0: return 90
        case 1: return 60
        case 2: return 180
        case 3, 4, 5, 6, 7: return 70
        case 8: return 100
        default: return 70
        }
    }

    private func downloadCSV() {
        guard let rows = oneSheetRows else { return }
        let cal = Calendar.current
        let year = cal.component(.year, from: startDate)
        let month = cal.component(.month, from: startDate)
        let ayStartYear = month >= 9 ? year : year - 1
        let filename = "One_Sheet_Updated_AY\(String(ayStartYear).suffix(2))-\(String(ayStartYear+1).suffix(2)).csv"

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.nameFieldStringValue = filename
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try CSVManager.exportCSV(rows: rows, to: url)
            } catch {
                print("Failed to export One Sheet CSV: \(error)")
            }
        }
    }
}
