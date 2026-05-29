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
        
        // Canonical column order matching the web app's CSV exports
        let canonicalOrder: [String] = [
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
        
        // Find all unique keys across the data
        var headerSet = Set<String>()
        for res in reservations {
            headerSet.formUnion(res.rawData.keys)
        }
        
        // Build header: canonical columns first, then any extras alphabetically
        var headers = canonicalOrder.filter { headerSet.contains($0) }
        let remaining = headerSet.subtracting(Set(headers)).sorted()
        headers.append(contentsOf: remaining)
        
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
        
        // Export ALL raw reservations (including filtered) for lossless round-trip
        try exportCSV(reservations: pack.raw, to: bundleURL.appendingPathComponent("Raw_Data.csv"))
        
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
        
        // No Shows & Late Cancellations (only bookings within the date range)
        let inRangeRaw = pack.raw.filter { !$0.filterReason.contains("Outside Selected Date Range") && !$0.filterReason.contains("Invalid Date") }
        let noShowCounts = pack.semesters.map { s in inRangeRaw.filter({ $0.semester == s && $0.filterReason.contains("No Show") }).count }
        lines.append(["No Shows"] + noShowCounts.map { "\($0)" } + ["\(noShowCounts.reduce(0, +))"])
        let lateCancelCounts = pack.semesters.map { s in inRangeRaw.filter({ $0.semester == s && $0.filterReason.contains("Late Cancellation") }).count }
        lines.append(["Late Cancellations"] + lateCancelCounts.map { "\($0)" } + ["\(lateCancelCounts.reduce(0, +))"])
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
    
    // MARK: - Bundle Import
    
    static func importBundle(from directoryURL: URL) throws -> (pack: (overall: [Reservation], rooms: [Reservation], deptsSchools: [Reservation], raw: [Reservation], semesters: [String]), oneSheetRows: [[String]]?) {
        let fm = FileManager.default
        
        // Look for One Sheet first (shared by both paths)
        var oneSheetRows: [[String]]? = nil
        if let bundleFiles = try? fm.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) {
            if let osFile = bundleFiles.first(where: { $0.lastPathComponent.starts(with: "One_Sheet_Updated") }) {
                oneSheetRows = try? parseCSVRows(from: osFile)
            }
        }
        
        // Preferred path: If Raw_Data.csv exists, use it as the authoritative source
        // and re-run processReservations for a lossless round-trip.
        let rawDataURL = directoryURL.appendingPathComponent("Raw_Data.csv")
        if fm.fileExists(atPath: rawDataURL.path) {
            let rawReservations = try importReservations(from: rawDataURL)
            
            // Infer date range from the bundle directory name (format: YYYY-MM-DD_to_YYYY-MM-DD_Data_Audit)
            let dirName = directoryURL.lastPathComponent
            let (inferredStart, inferredEnd) = parseBundleDateRange(from: dirName)
            
            let pack = DataProcessor.processReservations(
                reservations: rawReservations,
                startDate: inferredStart,
                endDate: inferredEnd
            )
            return (pack, oneSheetRows)
        }
        
        // Fallback path: Reconstruct from grouping pair files (backward compatibility)
        return try importBundleLegacy(from: directoryURL, oneSheetRows: oneSheetRows)
    }
    
    /// Parse start and end dates from a bundle directory name like "2024-09-01_to_2025-08-31_Data_Audit"
    private static func parseBundleDateRange(from dirName: String) -> (start: Date, end: Date) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        
        // Default fallback: 2024-09-01 to 2025-08-31
        let fallbackStart = df.date(from: "2024-09-01")!
        let fallbackEnd = df.date(from: "2025-08-31")!
        
        let parts = dirName.split(separator: "_")
        // Expected: ["2024-09-01", "to", "2025-08-31", "Data", "Audit"]
        guard parts.count >= 3,
              let start = df.date(from: String(parts[0])),
              parts[1] == "to",
              let end = df.date(from: String(parts[2])) else {
            return (fallbackStart, fallbackEnd)
        }
        return (start, end)
    }
    
    /// Legacy import path: reconstruct pack from grouping pair CSV files
    private static func importBundleLegacy(from directoryURL: URL, oneSheetRows: [[String]]?) throws -> (pack: (overall: [Reservation], rooms: [Reservation], deptsSchools: [Reservation], raw: [Reservation], semesters: [String]), oneSheetRows: [[String]]?) {
        let fm = FileManager.default
        
        // 1. Grouping Pairs
        let groupingDir = directoryURL.appendingPathComponent("Grouping_Pairs")
        var deptsSchools = [Reservation]()
        var rooms = [Reservation]()
        
        if let groupingFiles = try? fm.contentsOfDirectory(at: groupingDir, includingPropertiesForKeys: nil) {
            for file in groupingFiles where file.pathExtension == "csv" {
                let name = file.lastPathComponent
                let rows = try importReservations(from: file)
                if name.contains("_Schools") || name.contains("_Dpmts") {
                    deptsSchools.append(contentsOf: rows)
                } else if name.contains("_Rooms") {
                    rooms.append(contentsOf: rows)
                }
            }
        }
        
        // 2. Other Directory
        let otherDir = directoryURL.appendingPathComponent("Other")
        var raw = [Reservation]()
        if let otherFiles = try? fm.contentsOfDirectory(at: otherDir, includingPropertiesForKeys: nil) {
            for file in otherFiles where file.pathExtension == "csv" {
                let name = file.lastPathComponent
                let rows = try importReservations(from: file)
                if name == "Other_Schools.csv" {
                    deptsSchools.append(contentsOf: rows)
                } else if name == "Misformatted.csv" {
                    raw.append(contentsOf: rows)
                }
            }
        }
        
        // Ensure no duplicates in deptsSchools if they were in both _Schools and _Dpmts
        var uniqueDeptsSchools = [Reservation]()
        var seenDepts = Set<String>()
        for res in deptsSchools {
            let key = "\(res.id)_\(res.rawData["Clean Department"] ?? "")"
            if !seenDepts.contains(key) {
                seenDepts.insert(key)
                uniqueDeptsSchools.append(res)
            }
        }
        deptsSchools = uniqueDeptsSchools
        
        // Ensure no duplicates in rooms
        var uniqueRooms = [Reservation]()
        var seenRooms = Set<String>()
        for res in rooms {
            let key = "\(res.id)_\(res.rawData["Clean Room"] ?? "")"
            if !seenRooms.contains(key) {
                seenRooms.insert(key)
                uniqueRooms.append(res)
            }
        }
        rooms = uniqueRooms
        
        // 3. Reconstruct `overall` by taking unique IDs from deptsSchools
        var overall = [Reservation]()
        var seenIds = Set<Int>()
        for res in deptsSchools {
            if !seenIds.contains(res.id) {
                seenIds.insert(res.id)
                overall.append(res)
            }
        }
        
        // Also add valid items back to raw (which currently only has Misformatted)
        raw.append(contentsOf: overall)
        
        // Recalculate derived properties for reconstructed items since importReservations leaves them as defaults
        for i in 0..<overall.count {
            overall[i].semester = DataProcessor.getSemester(date: overall[i].bookingStartDate)
            overall[i].calcHours = DataProcessor.calcCappedHours(res: overall[i])
            overall[i].allDepts = DataProcessor.extractDepartments(deptStr: overall[i].department, title: overall[i].reservationTitle)
        }
        for i in 0..<rooms.count {
            rooms[i].semester = DataProcessor.getSemester(date: rooms[i].bookingStartDate)
            let totalRooms = max(1, rooms[i].numRoomsUsed)
            rooms[i].calcHours = DataProcessor.calcCappedHours(res: rooms[i]) / Double(totalRooms)
            rooms[i].allDepts = DataProcessor.extractDepartments(deptStr: rooms[i].department, title: rooms[i].reservationTitle)
        }
        for i in 0..<deptsSchools.count {
            deptsSchools[i].semester = DataProcessor.getSemester(date: deptsSchools[i].bookingStartDate)
            deptsSchools[i].calcHours = DataProcessor.calcCappedHours(res: deptsSchools[i])
            deptsSchools[i].allDepts = DataProcessor.extractDepartments(deptStr: deptsSchools[i].department, title: deptsSchools[i].reservationTitle)
        }
        
        // Semesters
        let sems = Array(Set(overall.map { $0.semester })).filter { $0 != "Other" }.sorted(by: DataProcessor.semesterOrder)
        
        let pack = (overall: overall, rooms: rooms, deptsSchools: deptsSchools, raw: raw, semesters: sems)
        return (pack, oneSheetRows)
    }
}
