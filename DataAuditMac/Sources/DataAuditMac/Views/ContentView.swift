import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var rawReservations: [Reservation] = []
    @State private var processedPack: (overall: [Reservation], rooms: [Reservation], deptsSchools: [Reservation], raw: [Reservation], semesters: [String])? = nil

    @State private var startDate: Date = {
        var comps = DateComponents()
        comps.year = 2024; comps.month = 9; comps.day = 1
        return Calendar.current.date(from: comps) ?? Date()
    }()
    @State private var endDate: Date = {
        var comps = DateComponents()
        comps.year = 2025; comps.month = 8; comps.day = 31
        return Calendar.current.date(from: comps) ?? Date()
    }()

    @State private var csvFileURL: URL? = nil
    @State private var oneSheetURL: URL? = nil
    @State private var historicOneSheetRows: [[String]]? = nil
    @State private var oneSheetUpdatedRows: [[String]]? = nil

    @State private var selectedAcademicYear: String = "2024-2025"
    private let academicYears = ["2022-2023", "2023-2024", "2024-2025", "2025-2026", "2026-2027", "2027-2028"]

    @State private var pendingEdits: [PendingEdit] = []

    @State private var isImportedBundle = false
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            if processedPack == nil {
                uploadView
            } else {
                tabbedInterface
            }
        }
        .frame(minWidth: 900, minHeight: 650)
    }

    // MARK: - Upload View

    private var uploadView: some View {
        VStack(spacing: 24) {
            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "gearshape.2")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                Text("Reservation Data Audit Application")
                    .font(.largeTitle.weight(.bold))
            }

            Text("Upload the Booking Tool reservations CSV file to generate Grouping Pairs, Top Sheet, and One Sheet stats.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 600)

            // Date pickers and Academic Year selection
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Academic Year").font(.caption).foregroundColor(.secondary)
                    Picker("", selection: $selectedAcademicYear) {
                        ForEach(academicYears, id: \.self) { year in
                            Text(year).tag(year)
                        }
                        Text("Custom").tag("Custom")
                    }
                    .labelsHidden()
                    .frame(width: 120)
                    .onChange(of: selectedAcademicYear) { newValue in
                        if newValue != "Custom" {
                            let parts = newValue.split(separator: "-")
                            if parts.count == 2, let startYear = Int(parts[0]), let endYear = Int(parts[1]) {
                                var startComps = DateComponents()
                                startComps.year = startYear; startComps.month = 9; startComps.day = 1
                                if let newStart = Calendar.current.date(from: startComps) {
                                    startDate = newStart
                                }
                                
                                var endComps = DateComponents()
                                endComps.year = endYear; endComps.month = 8; endComps.day = 31
                                if let newEnd = Calendar.current.date(from: endComps) {
                                    endDate = newEnd
                                }
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Date").font(.caption).foregroundColor(.secondary)
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: startDate) { _ in updateAcademicYearToCustomIfNeeded() }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("End Date").font(.caption).foregroundColor(.secondary)
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: endDate) { _ in updateAcademicYearToCustomIfNeeded() }
                }
            }

            // File upload zones
            HStack(spacing: 16) {
                FileDropZone(
                    icon: "tablecells",
                    label: csvFileURL?.lastPathComponent ?? "Upload 'Booking Tool' CSV",
                    fileTypes: [UTType.commaSeparatedText],
                    onSelect: { url in csvFileURL = url }
                )

                FileDropZone(
                    icon: "chart.bar.doc.horizontal",
                    label: oneSheetURL?.lastPathComponent ?? "Upload Historic 'One Sheet' (Optional)",
                    fileTypes: [UTType.commaSeparatedText],
                    onSelect: { url in oneSheetURL = url }
                )
                
                FolderDropZone(
                    icon: "folder",
                    label: "Import Exported Bundle",
                    onSelect: { url in importBundle(from: url) }
                )
            }
            .frame(maxWidth: 800)

            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                }
                .foregroundColor(.red)
                .padding(10)
                .background(Color.red.opacity(0.08))
                .cornerRadius(8)
            }

            Button(action: processData) {
                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 20)
                } else {
                    Text("Process Data")
                        .font(.headline)
                        .frame(maxWidth: 400)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(csvFileURL == nil || isProcessing)

            Spacer()
        }
        .padding(32)
    }

    // MARK: - Tabbed Interface

    private var tabbedInterface: some View {
        VStack(spacing: 0) {
            // Success banner
            if let msg = successMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(msg)
                    Spacer()
                    Button("Dismiss") { successMessage = nil }
                        .buttonStyle(.plain)
                        .foregroundColor(.green)
                }
                .foregroundColor(.green)
                .padding(12)
                .background(Color.green.opacity(0.08))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top, 8)
            }

            // Toolbar
            HStack {
                Button(action: startOver) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Start Over")
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Export Bundle") { exportBundle() }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Tabs — order matches web app: Top Sheet → Grouping Pairs → One Sheet → Filtered
            TabView {
                TopSheetView(pack: processedPack!)
                    .tabItem {
                        Image(systemName: "rectangle.split.3x3")
                        Text("Top Sheet Overview")
                    }

                GroupingPairsView(
                    pack: processedPack!,
                    edits: $pendingEdits,
                    onSave: saveChanges,
                    onDiscard: discardChanges
                )
                .tabItem {
                    Image(systemName: "square.stack.3d.up")
                    Text("Grouping Pairs")
                }

                OneSheetView(oneSheetRows: oneSheetUpdatedRows, startDate: startDate)
                    .tabItem {
                        Image(systemName: "number.square")
                        Text("One Sheet Update")
                    }

                FilteredBookingsView(
                    pack: processedPack!,
                    edits: $pendingEdits,
                    onSave: saveChanges,
                    onDiscard: discardChanges
                )
                .tabItem {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Filtered Bookings")
                }
            }
        }
    }

    // MARK: - Actions

    private func startOver() {
        processedPack = nil
        rawReservations = []
        oneSheetUpdatedRows = nil
        historicOneSheetRows = nil
        pendingEdits = []
        successMessage = nil
        errorMessage = nil
        csvFileURL = nil
        isImportedBundle = false
    }

    private func updateAcademicYearToCustomIfNeeded() {
        let cal = Calendar.current
        let startYear = cal.component(.year, from: startDate)
        let endYear = cal.component(.year, from: endDate)
        let startMonth = cal.component(.month, from: startDate)
        let startDay = cal.component(.day, from: startDate)
        let endMonth = cal.component(.month, from: endDate)
        let endDay = cal.component(.day, from: endDate)
        
        let expectedYearString = "\(startYear)-\(endYear)"
        if startMonth == 9 && startDay == 1 && endMonth == 8 && endDay == 31 && endYear == startYear + 1 && academicYears.contains(expectedYearString) {
            if selectedAcademicYear != expectedYearString {
                selectedAcademicYear = expectedYearString
            }
        } else {
            if selectedAcademicYear != "Custom" {
                selectedAcademicYear = "Custom"
            }
        }
    }

    private func importBundle(from url: URL) {
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try CSVManager.importBundle(from: url)
                DispatchQueue.main.async {
                    self.rawReservations = result.pack.raw
                    self.processedPack = result.pack
                    self.oneSheetUpdatedRows = result.oneSheetRows
                    self.isImportedBundle = true
                    self.isProcessing = false
                    self.successMessage = "Bundle imported successfully. You can now make edits and re-export."
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to import bundle: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }

    private func processData() {
        guard let csvURL = csvFileURL else {
            errorMessage = "Please upload a Booking Tool CSV."
            return
        }

        isProcessing = true
        errorMessage = nil
        successMessage = nil

        let currentStartDate = self.startDate
        let currentEndDate = self.endDate
        let currentOSURL = self.oneSheetURL

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let raw = try CSVManager.importReservations(from: csvURL)
                let pack = DataProcessor.processReservations(reservations: raw, startDate: currentStartDate, endDate: currentEndDate)

                var osRows: [[String]]? = nil
                var osUpdated: [[String]]? = nil
                if let osURL = currentOSURL {
                    osRows = try? CSVManager.parseCSVRows(from: osURL)
                    if let rows = osRows {
                        osUpdated = DataProcessor.generateOneSheet(pack: pack, historicCSVRows: rows, startDate: currentStartDate)
                    }
                }

                // Auto-export bundle to Documents folder (matching Python's auto-save behavior)
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                let bundleName = "\(df.string(from: currentStartDate))_to_\(df.string(from: currentEndDate))_Data_Audit"
                let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let bundlePath = docsDir.appendingPathComponent(bundleName).path

                try? CSVManager.exportBundle(pack: pack, startDate: currentStartDate, endDate: currentEndDate, oneSheetRows: osUpdated, to: docsDir)

                DispatchQueue.main.async {
                    self.rawReservations = raw
                    self.processedPack = pack
                    self.historicOneSheetRows = osRows
                    self.oneSheetUpdatedRows = osUpdated
                    self.isProcessing = false
                    self.successMessage = "Processing Complete! Files saved locally in `\(bundlePath)` directory."
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load CSV: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }

    private func saveChanges() {
        guard !pendingEdits.isEmpty else { return }

        // Apply all pending edits to rawReservations
        let editTuples = pendingEdits.map { (id: $0.rawId, column: $0.column, value: $0.value) }
        DataProcessor.applyEdits(edits: editTuples, to: &rawReservations)
        pendingEdits = []

        // Recalculate
        recalculate()
    }

    private func discardChanges() {
        pendingEdits = []
    }

    private func recalculate() {
        isProcessing = true
        let currentStartDate = self.startDate
        let currentEndDate = self.endDate
        let currentRaw = self.rawReservations
        let histRows = self.historicOneSheetRows

        DispatchQueue.global(qos: .userInitiated).async {
            let pack = DataProcessor.processReservations(reservations: currentRaw, startDate: currentStartDate, endDate: currentEndDate)

            var osUpdated: [[String]]? = nil
            if let rows = histRows {
                osUpdated = DataProcessor.generateOneSheet(pack: pack, historicCSVRows: rows, startDate: currentStartDate)
            }

            // Re-export bundle
            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            try? CSVManager.exportBundle(pack: pack, startDate: currentStartDate, endDate: currentEndDate, oneSheetRows: osUpdated, to: docsDir)

            DispatchQueue.main.async {
                self.processedPack = pack
                self.oneSheetUpdatedRows = osUpdated
                self.isProcessing = false
            }
        }
    }

    private func exportBundle() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Select Output Directory"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                if let pack = processedPack {
                    try CSVManager.exportBundle(pack: pack, startDate: startDate, endDate: endDate, oneSheetRows: oneSheetUpdatedRows, to: url)
                }
            } catch {
                errorMessage = "Failed to export bundle: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - FileDropZone

struct FileDropZone: View {
    let icon: String
    let label: String
    let fileTypes: [UTType]
    let onSelect: (URL) -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: selectFile) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1, dash: [6])
                    )
                    .foregroundColor(isHovering ? .blue : .secondary.opacity(0.5))
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovering ? Color.blue.opacity(0.03) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovering = hovering }
    }

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = fileTypes
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            onSelect(url)
        }
    }
}

// MARK: - FolderDropZone

struct FolderDropZone: View {
    let icon: String
    let label: String
    let onSelect: (URL) -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: selectFolder) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1, dash: [6])
                    )
                    .foregroundColor(isHovering ? .orange : .secondary.opacity(0.5))
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovering ? Color.orange.opacity(0.03) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovering = hovering }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            onSelect(url)
        }
    }
}
