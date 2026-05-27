import Foundation
import SwiftCSV

struct CSVManager {
    
    static func importReservations(from url: URL) throws -> [Reservation] {
        let csv = try CSV<Named>(url: url)
        var reservations: [Reservation] = []
        var idCounter = 1
        
        for row in csv.rows {
            // Need to capture dynamic keys
            var rawData: [String: String] = [:]
            for key in csv.header {
                if let val = row[key] {
                    rawData[key] = val
                }
            }
            
            // Generate or use _raw_id
            let id: Int
            if let rawIdStr = row["_raw_id"], let parsedId = Int(rawIdStr) {
                id = parsedId
            } else {
                id = idCounter
            }
            
            let res = Reservation(id: id, rawData: rawData)
            reservations.append(res)
            idCounter += 1
        }
        
        return reservations
    }
    
    static func exportCSV(reservations: [Reservation], to url: URL) throws {
        guard !reservations.isEmpty else { return }
        
        // Find all unique keys to form the header
        var headerSet = Set<String>()
        for res in reservations {
            headerSet.formUnion(res.rawData.keys)
        }
        var headers = Array(headerSet).sorted()
        
        // Ensure _raw_id is first if not in rawData
        if !headers.contains("_raw_id") {
            headers.insert("_raw_id", at: 0)
        } else {
            headers.removeAll { $0 == "_raw_id" }
            headers.insert("_raw_id", at: 0)
        }
        
        var csvString = headers.map { escapeCSV($0) }.joined(separator: ",") + "\n"
        
        for res in reservations {
            var rowRaw = res.rawData
            rowRaw["_raw_id"] = "\(res.id)"
            
            let rowValues = headers.map { key -> String in
                let val = rowRaw[key] ?? ""
                return escapeCSV(val)
            }
            csvString += rowValues.joined(separator: ",") + "\n"
        }
        
        try csvString.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
    
    static func parseCSVRows(from url: URL) throws -> [[String]] {
        let csv = try CSV<Enumerated>(url: url)
        var rows = [[String]]()
        rows.append(csv.header)
        for row in csv.rows {
            rows.append(row)
        }
        return rows
    }
    
    static func exportCSV(rows: [[String]], to url: URL) throws {
        var csvString = ""
        for row in rows {
            let escaped = row.map { escapeCSV($0) }
            csvString += escaped.joined(separator: ",") + "\n"
        }
        try csvString.write(to: url, atomically: true, encoding: .utf8)
    }
    
    static func exportBundle(pack: (overall: [Reservation], rooms: [Reservation], deptsSchools: [Reservation], raw: [Reservation], semesters: [String]),
                             startDate: Date, endDate: Date,
                             oneSheetRows: [[String]]?,
                             to directoryURL: URL) throws {
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let startStr = df.string(from: startDate)
        let endStr = df.string(from: endDate)
        
        let bundleName = "\(startStr)_to_\(endStr)_Data_Audit"
        let bundleURL = directoryURL.appendingPathComponent(bundleName)
        
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        
        let groupingDir = bundleURL.appendingPathComponent("Grouping_Pairs")
        try FileManager.default.createDirectory(at: groupingDir, withIntermediateDirectories: true)
        
        for sem in pack.semesters {
            let code = getSemesterCode(sem)
            
            let schools = pack.deptsSchools.filter { $0.semester == sem }.sorted { ($0.rawData["Clean School"] ?? "") < ($1.rawData["Clean School"] ?? "") }
            try exportCSV(reservations: schools, to: groupingDir.appendingPathComponent("\(code)_Schools.csv"))
            
            let depts = pack.deptsSchools.filter { $0.semester == sem }.sorted { ($0.rawData["Clean Department"] ?? "") < ($1.rawData["Clean Department"] ?? "") }
            try exportCSV(reservations: depts, to: groupingDir.appendingPathComponent("\(code)_Dpmts.csv"))
            
            let rooms = pack.rooms.filter { $0.semester == sem }.sorted { ($0.rawData["Clean Room"] ?? "") < ($1.rawData["Clean Room"] ?? "") }
            try exportCSV(reservations: rooms, to: groupingDir.appendingPathComponent("\(code)_Rooms.csv"))
        }
        
        let otherDir = bundleURL.appendingPathComponent("Other")
        try FileManager.default.createDirectory(at: otherDir, withIntermediateDirectories: true)
        
        let otherSchools = pack.deptsSchools.filter { $0.rawData["Clean School"] == "Other Schools" }
        try exportCSV(reservations: otherSchools, to: otherDir.appendingPathComponent("Other_Schools.csv"))
        
        let misformatted = pack.raw.filter { $0.filterReason.contains("Room 000") }
        if !misformatted.isEmpty {
            try exportCSV(reservations: misformatted, to: otherDir.appendingPathComponent("Misformatted.csv"))
        }
        
        let topSheetStr = generateTopSheetCSVString(pack: pack, startStr: startStr, endStr: endStr)
        try topSheetStr.write(to: bundleURL.appendingPathComponent("Top_Sheet_\(startStr)_to_\(endStr).csv"), atomically: true, encoding: .utf8)
        
        if let osRows = oneSheetRows {
            let cal = Calendar.current
            let year = cal.component(.year, from: startDate)
            let month = cal.component(.month, from: startDate)
            let ayStartYear = month >= 9 ? year : year - 1
            let ayCode = "AY\(String(ayStartYear).suffix(2))-\(String(ayStartYear+1).suffix(2))"
            
            try exportCSV(rows: osRows, to: bundleURL.appendingPathComponent("One_Sheet_Updated_\(ayCode).csv"))
        }
    }
    
    private static func getSemesterCode(_ sem: String) -> String {
        let suffix = String(sem.suffix(2))
        if sem.contains("Fall") { return "F\(suffix)" }
        if sem.contains("Winter") { return "W\(suffix)" }
        if sem.contains("Spring") { return "Sp\(suffix)" }
        if sem.contains("Summer") { return "Su\(suffix)" }
        return "Other"
    }
    
    private static func generateTopSheetCSVString(pack: (overall: [Reservation], rooms: [Reservation], deptsSchools: [Reservation], raw: [Reservation], semesters: [String]), startStr: String, endStr: String) -> String {
        var lines = [[String]]()
        lines.append(["Reservation Data Audit (\(startStr) - \(endStr))"])
        lines.append(["If some #'s don't match with the total nb, it's due to events hosted by multiple dptmnts."])
        
        let header = [""] + pack.semesters + ["Total:"]
        lines.append(header)
        lines.append([])
        
        let totalRes = pack.overall.count
        lines.append(["Total # of reservations:"] + Array(repeating: "", count: pack.semesters.count) + ["\(totalRes)"])
        lines.append([])
        
        let hrs = pack.semesters.map { s in pack.overall.filter({ $0.semester == s }).reduce(0) { $0 + $1.calcHours } }
        lines.append(["Hours"] + hrs.map { String(format: "%.2f", $0) } + [String(format: "%.2f", hrs.reduce(0, +))])
        
        let resCount = pack.semesters.map { s in pack.overall.filter({ $0.semester == s }).count }
        lines.append(["Reservations"] + resCount.map { "\($0)" } + ["\(resCount.reduce(0, +))"])
        lines.append([])
        
        func addSection(title: String, col: String, entities: [String], target: [Reservation]) {
            lines.append([title])
            for entity in entities {
                let counts = pack.semesters.map { s in target.filter({ $0.semester == s && ($0.rawData[col] ?? "") == entity }).count }
                lines.append([entity] + counts.map { "\($0)" } + ["\(counts.reduce(0, +))"])
            }
        }
        
        func addHoursSection(title: String, col: String, entities: [String], target: [Reservation]) {
            lines.append([title])
            for entity in entities {
                let hourCounts = pack.semesters.map { s in target.filter({ $0.semester == s && ($0.rawData[col] ?? "") == entity }).reduce(0) { $0 + $1.calcHours } }
                lines.append([entity] + hourCounts.map { String(format: "%.2f", $0) } + [String(format: "%.2f", hourCounts.reduce(0, +))])
            }
        }
        
        let roomOrder = ["1201 Seminar Room", "233 Co-Lab", "230 Audio Lab", "221-224 Ballrooms", "220 Blackbox", "202 Lecture Hall", "103 Garage", "260 Post Production Lab"]
        addSection(title: "Reservations per room:", col: "Clean Room", entities: roomOrder, target: pack.rooms)
        addHoursSection(title: "Hours per room:", col: "Clean Room", entities: roomOrder, target: pack.rooms)
        
        let progOrder = ["ALT (Ed Leadership, ECT, and Higher and Post Secondary Education)", "IDM", "ITP / IMA / Low Res", "CDI / Recorded Music", "Music Tech", "MARL", "MPAP", "Game Center", "Other Group(s)", "Community Partner"]
        addSection(title: "Reservations per program:", col: "Clean Department", entities: progOrder, target: pack.deptsSchools)
        addHoursSection(title: "Hours per Program:", col: "Clean Department", entities: progOrder, target: pack.deptsSchools)
        
        let schoolOrder = ["Tandon", "Tisch", "Steinhardt", "Provost", "URPA / Community Partner", "Central", "Greater NYU", "Other Schools"]
        addSection(title: "Reservations per School:", col: "Clean School", entities: schoolOrder, target: pack.deptsSchools)
        lines.append([])
        addHoursSection(title: "Hours per School:", col: "Clean School", entities: schoolOrder, target: pack.deptsSchools)
        
        var csvStr = ""
        for row in lines {
            let escaped = row.map { escapeCSV($0) }
            csvStr += escaped.joined(separator: ",") + "\n"
        }
        return csvStr
    }
}
