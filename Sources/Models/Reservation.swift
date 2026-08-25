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
    
    var canceledAtDate: Date? {
        guard let str = rawData["Canceled At"] else { return nil }
        return Self.parseDate(from: str)
    }

    var fullBookingStartDate: Date? {
        guard let startDate = bookingStartDate else { return nil }
        let timeStr = bookingStartTime.trimmingCharacters(in: .whitespacesAndNewlines)
        if timeStr.isEmpty { return startDate }
        
        let formatter = DateFormatter()
        let timeFormats = ["h:mm a", "h:mm:ss a", "HH:mm", "HH:mm:ss"]
        for tf in timeFormats {
            formatter.dateFormat = tf
            if let timeDate = formatter.date(from: timeStr) {
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: timeDate)
                return calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                     minute: timeComponents.minute ?? 0,
                                     second: timeComponents.second ?? 0,
                                     of: startDate)
            }
        }
        return startDate
    }
    
    var endEventStatus: String { rawData["End Event Status"] ?? "" }
    var bookingType: String { rawData["Booking Type"] ?? "" }
    var reservationTitle: String { rawData["Reservation Title"] ?? "" }
    var roomsStr: String { rawData["Room(s)"] ?? "" }
    var department: String { rawData["Department"] ?? "" }
    var manualOverrideFiltered: String { rawData["Manual Override Filtered"] ?? "" }
    
    // Timestamp-based status columns
    var noShowAtDate: Date? {
        guard let str = rawData["No Show At"], !str.isEmpty else { return nil }
        return Self.parseDate(from: str)
    }
    
    var checkedInAtDate: Date? {
        guard let str = rawData["Checked In At"], !str.isEmpty else { return nil }
        return Self.parseDate(from: str)
    }
    
    var checkedOutAtDate: Date? {
        guard let str = rawData["Checked Out At"], !str.isEmpty else { return nil }
        return Self.parseDate(from: str)
    }
    
    var declinedAtDate: Date? {
        guard let str = rawData["Declined At"], !str.isEmpty else { return nil }
        return Self.parseDate(from: str)
    }
    
    var firstApprovedAtDate: Date? {
        guard let str = rawData["First Approved At"], !str.isEmpty else { return nil }
        return Self.parseDate(from: str)
    }
    
    var finalApprovedAtDate: Date? {
        guard let str = rawData["Final Approved At"], !str.isEmpty else { return nil }
        return Self.parseDate(from: str)
    }
    
    // Convenience booleans for status checks
    var hasNoShow: Bool { noShowAtDate != nil }
    var hasCheckedIn: Bool { checkedInAtDate != nil }
    var hasCheckedOut: Bool { checkedOutAtDate != nil }
    var hasApproval: Bool { firstApprovedAtDate != nil || finalApprovedAtDate != nil }
    var hasDecline: Bool { declinedAtDate != nil }
    var hasCancellation: Bool { canceledAtDate != nil }
    
    var actualHours: Double? {
        if let val = rawData["ACTUAL hours"], let d = Double(val) { return d }
        return nil
    }
    
    var timeInUseHours: Double? {
        if let val = rawData["Time In Use, Hours"], let d = Double(val) { return d }
        return nil
    }
    
    var numRoomsUsed: Int {
        if let val = rawData["# rooms used"] {
            if let i = Int(val) { return i }
            // Handle "2.0" style strings from CSV round-trips
            if let d = Double(val) { return Int(d) }
        }
        return 1
    }
    
    // Formatting
    private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd h:mm a",
            "MM/dd/yyyy",
            "MM/dd/yyyy HH:mm:ss",
            "MM/dd/yyyy h:mm a",
            "M/d/yyyy",
            "M/d/yyyy HH:mm:ss",
            "M/d/yyyy h:mm a",
            "M/d/yy",
            "M/d/yy HH:mm:ss",
            "M/d/yy h:mm a",
            "MM/dd/yy",
            "MM/dd/yy HH:mm:ss",
            "MM/dd/yy h:mm a",
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
