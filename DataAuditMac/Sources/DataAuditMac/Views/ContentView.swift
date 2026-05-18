import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var rawReservations: [Reservation] = []
    @State private var processedPack: (overall: [Reservation], rooms: [Reservation], deptsSchools: [Reservation], raw: [Reservation], semesters: [String])? = nil
    
    @State private var startDate: Date = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack {
            if processedPack == nil {
                uploadView
            } else {
                tabbedInterface
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .padding()
    }
    
    private var uploadView: some View {
        VStack(spacing: 20) {
            Text("Data Audit Application")
                .font(.largeTitle)
                .bold()
            
            Text("Select the raw Bookings Tool CSV to begin.")
                .foregroundColor(.secondary)
            
            HStack {
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
            }
            .frame(maxWidth: 400)
            
            Button("Import CSV & Process Data") {
                selectAndProcessCSV()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            if isProcessing {
                ProgressView()
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
        }
    }
    
    private var tabbedInterface: some View {
        VStack {
            HStack {
                Button("Start Over") {
                    processedPack = nil
                    rawReservations = []
                }
                Spacer()
                Button("Export CSV") { exportData() }
                Button("Export PDF") { exportPDF() }
            }
            .padding(.horizontal)
            
            TabView {
                TopSheetView(pack: processedPack!)
                    .tabItem { Text("Top Sheet Overview") }
                
                GroupingPairsView(pack: processedPack!, onUpdate: recalculate)
                    .tabItem { Text("Grouping Pairs") }
                
                FilteredBookingsView(pack: processedPack!, onUpdate: recalculate)
                    .tabItem { Text("Filtered Bookings") }
                
                OneSheetView()
                    .tabItem { Text("One Sheet") }
            }
        }
    }
    
    private func exportData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.nameFieldStringValue = "DataAudit_Export.csv"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                if let pack = processedPack {
                    try CSVManager.exportCSV(reservations: pack.raw, to: url)
                }
            } catch {
                errorMessage = "Failed to export CSV: \(error.localizedDescription)"
            }
        }
    }
    
    private func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.nameFieldStringValue = "DataAudit_TopSheet.pdf"
        if panel.runModal() == .OK, let url = panel.url {
            if let pack = processedPack {
                Task { @MainActor in
                    PDFGenerator.generatePDF(from: pack, title: "Data Audit Report", to: url)
                }
            }
        }
    }
    
    private func selectAndProcessCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            isProcessing = true
            errorMessage = nil
            
            let currentStartDate = self.startDate
            let currentEndDate = self.endDate
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let raw = try CSVManager.importReservations(from: url)
                    let pack = DataProcessor.processReservations(reservations: raw, startDate: currentStartDate, endDate: currentEndDate)
                    DispatchQueue.main.async {
                        self.rawReservations = raw
                        self.processedPack = pack
                        self.isProcessing = false
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to load CSV: \(error.localizedDescription)"
                        self.isProcessing = false
                    }
                }
            }
        }
    }
    
    private func recalculate() {
        if let currentRaw = processedPack?.raw {
            isProcessing = true
            let currentStartDate = self.startDate
            let currentEndDate = self.endDate
            DispatchQueue.global(qos: .userInitiated).async {
                let pack = DataProcessor.processReservations(reservations: currentRaw, startDate: currentStartDate, endDate: currentEndDate)
                DispatchQueue.main.async {
                    self.processedPack = pack
                    self.isProcessing = false
                }
            }
        }
    }
}
