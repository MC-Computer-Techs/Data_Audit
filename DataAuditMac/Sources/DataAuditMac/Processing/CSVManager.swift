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
}
