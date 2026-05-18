import SwiftUI
import Foundation

@main
struct DataAuditApp: App {
    
    init() {
        let args = CommandLine.arguments
        if let debugIdx = args.firstIndex(of: "--debug"), debugIdx + 1 < args.count {
            let csvPath = args[debugIdx + 1]
            runDebugComparison(csvPath: csvPath)
            exit(0)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

func runDebugComparison(csvPath: String) {
    let url = URL(fileURLWithPath: csvPath)
    
    do {
        let reservations = try CSVManager.importReservations(from: url)
        
        // Use a wide date range matching the Python script
        let cal = Calendar.current
        let startDate = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let endDate = cal.date(from: DateComponents(year: 2027, month: 12, day: 31))!
        
        let pack = DataProcessor.processReservations(
            reservations: reservations,
            startDate: startDate,
            endDate: endDate
        )
        
        let overall = pack.overall
        let rooms = pack.rooms
        let deptsSchools = pack.deptsSchools
        let raw = pack.raw
        let semesters = pack.semesters
        
        let filteredOut = raw.filter { $0.filteredOut }.count
        let totalCalcHours = overall.reduce(0.0) { $0 + $1.calcHours }
        
        print(String(repeating: "=", count: 70))
        print("SWIFT COMPARISON NUMBERS")
        print(String(repeating: "=", count: 70))
        print("Total rows in CSV: \(reservations.count)")
        print("Total raw (annotated): \(raw.count)")
        print("Total filtered OUT: \(filteredOut)")
        print("Total valid (overall): \(overall.count)")
        print("Total Calc Hours: \(String(format: "%.2f", totalCalcHours))")
        print("Semesters: \(semesters)")
        print()
        
        print("--- Reservations per Semester ---")
        for sem in semesters {
            let count = overall.filter { $0.semester == sem }.count
            let hours = overall.filter { $0.semester == sem }.reduce(0.0) { $0 + $1.calcHours }
            print("  \(sem): \(count) reservations, \(String(format: "%.2f", hours)) hours")
        }
        print()
        
        print("--- Reservations per Room ---")
        let roomOrder = ["1201 Seminar Room", "233 Co-Lab", "230 Audio Lab", "221-224 Ballrooms", "220 Blackbox", "202 Lecture Hall", "103 Garage", "260 Post Production Lab", "Other"]
        for room in roomOrder {
            let count = rooms.filter { $0.rawData["Clean Room"] == room }.count
            let hours = rooms.filter { $0.rawData["Clean Room"] == room }.reduce(0.0) { $0 + $1.calcHours }
            print("  \(room): \(count) reservations, \(String(format: "%.2f", hours)) hours")
        }
        print()
        
        print("--- Reservations per Department ---")
        let deptOrder = ["ALT (Ed Leadership, ECT, and Higher and Post Secondary Education)", "IDM", "ITP / IMA / Low Res", "CDI / Recorded Music", "Music Tech", "MARL", "MPAP", "Game Center", "Other Group(s)", "Community Partner"]
        for dept in deptOrder {
            let count = deptsSchools.filter { $0.rawData["Clean Department"] == dept }.count
            let hours = deptsSchools.filter { $0.rawData["Clean Department"] == dept }.reduce(0.0) { $0 + $1.calcHours }
            print("  \(dept): \(count) reservations, \(String(format: "%.2f", hours)) hours")
        }
        print()
        
        print("--- Reservations per School ---")
        let schoolOrder = ["Tandon", "Tisch", "Steinhardt", "URPA / Community Partner", "Central", "Greater NYU", "Other Schools"]
        for school in schoolOrder {
            let count = deptsSchools.filter { $0.rawData["Clean School"] == school }.count
            let hours = deptsSchools.filter { $0.rawData["Clean School"] == school }.reduce(0.0) { $0 + $1.calcHours }
            print("  \(school): \(count) reservations, \(String(format: "%.2f", hours)) hours")
        }
        
        // First 10 rows spot check
        print()
        print("--- First 10 rows Calc Hours (spot check) ---")
        for res in overall.prefix(10) {
            let title = String(res.reservationTitle.prefix(40))
            let ah = res.actualHours.map { String(format: "%.2f", $0) } ?? "N/A"
            let tiu = res.timeInUseHours.map { String(format: "%.2f", $0) } ?? "N/A"
            print("  raw_id=\(res.id), title='\(title)', calcHours=\(String(format: "%.2f", res.calcHours)), actualHrs=\(ah), timeInUse=\(tiu)")
        }
        
    } catch {
        print("ERROR: \(error)")
    }
}
