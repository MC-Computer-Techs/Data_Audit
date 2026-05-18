import Foundation

struct Reservation: Identifiable, Hashable {
    let id: Int // Corresponds to _raw_id
    var rawData: [String: String]
    
    // Derived/Calculated fields
    var filteredOut: Bool = false
    var filterReason: String = ""
    var semester: String = "Other"
    var calcHours: Double = 0.0
    var allDepts: [String] = []
    
    init(id: Int, rawData: [String: String]) {
        self.id = id
        self.rawData = rawData
    }
    
    // Accessors for common fields to simplify logic
    var bookingStartDate: Date? {
        guard let str = rawData["Booking Start Date"] else { return nil }
        return Self.parseDate(from: str)
    }
    
    var bookingEndDate: Date? {
        guard let str = rawData["Booking End Date"] else { return nil }
        return Self.parseDate(from: str)
    }
    
    var bookingStartTime: String { rawData["Booking Start Time"] ?? "" }
    var bookingEndTime: String { rawData["Booking End Time"] ?? "" }
    
    var endEventStatus: String { rawData["End Event Status"] ?? "" }
    var bookingType: String { rawData["Booking Type"] ?? "" }
    var reservationTitle: String { rawData["Reservation Title"] ?? "" }
    var roomsStr: String { rawData["Room(s)"] ?? "" }
    var department: String { rawData["Department"] ?? "" }
    var manualOverrideFiltered: String { rawData["Manual Override Filtered"] ?? "" }
    
    var actualHours: Double? {
        if let val = rawData["ACTUAL hours"], let d = Double(val) { return d }
        return nil
    }
    
    var timeInUseHours: Double? {
        if let val = rawData["Time In Use, Hours"], let d = Double(val) { return d }
        return nil
    }
    
    var numRoomsUsed: Int {
        if let val = rawData["# rooms used"], let i = Int(val) { return i }
        return 1
    }
    
    // Formatting
    private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd",
            "yyyy-MM-dd HH:mm:ss",
            "MM/dd/yyyy",
            "M/d/yy",
            "M/d/yyyy",
            "MM/dd/yy",
            "yyyy/MM/dd"
        ]
        return formats.map {
            let df = DateFormatter()
            df.dateFormat = $0
            return df
        }
    }()
    
    static func parseDate(from str: String) -> Date? {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        
        let dateOnly = String(trimmed.split(separator: " ").first ?? "")
        
        for df in dateFormatters {
            if let d = df.date(from: trimmed) { return d }
            if !dateOnly.isEmpty, let d = df.date(from: dateOnly) { return d }
        }
        return nil
    }
}
