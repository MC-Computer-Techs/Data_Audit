import Foundation

struct DataProcessor {
    
    static func cleanRoom(_ roomStr: String) -> String {
        let s = roomStr
        if s.isEmpty || s.lowercased() == "nan" { return "Other" }
        if s.contains("1201") { return "1201 Seminar Room" }
        if s.contains("233") { return "233 Co-Lab" }
        if s.contains("230") { return "230 Audio Lab" }
        if s.contains("260") { return "260 Post Production Lab" }
        if s.contains("202") { return "202 Lecture Hall" }
        if s.contains("103") { return "103 Garage" }
        if s.contains("220") { return "220 Blackbox" }
        if s.contains("221") || s.contains("222") || s.contains("223") || s.contains("224") { return "221-224 Ballrooms" }
        return "Other"
    }
    
    static func cleanDepartment(_ deptStr: String) -> String {
        let d = deptStr.trimmingCharacters(in: .whitespacesAndNewlines)
        if d.isEmpty || d.lowercased() == "nan" || d == "Other" { return "Other Group(s)" }
        if d.contains("ALT") { return "ALT (Ed Leadership, ECT, and Higher and Post Secondary Education)" }
        if d.contains("CDI") { return "CDI / Recorded Music" }
        if d.contains("ITP") || d.contains("IMA") || d.contains("Low Res") { return "ITP / IMA / Low Res" }
        let exactMatches = ["IDM", "Music Tech", "MARL", "MPAP", "Game Center"]
        if exactMatches.contains(d) { return d }
        if d == "URPA" { return "Community Partner" }
        if d == "Community Partner" { return d }
        return d
    }
    
    static func wordInTitle(_ word: String, title: String) -> Bool {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: title.utf16.count)
            return regex.firstMatch(in: title, options: [], range: range) != nil
        }
        return false
    }
    
    static func extractDepartments(deptStr: String, title: String) -> [String] {
        var depts = Set<String>()
        let t = title.lowercased()
        
        if !deptStr.isEmpty && deptStr.lowercased() != "nan" && deptStr != "Other" {
            depts.insert(cleanDepartment(deptStr))
        } else {
            if wordInTitle("itp", title: t) || wordInTitle("ima", title: t) || wordInTitle("low res", title: t) { depts.insert("ITP / IMA / Low Res") }
            if wordInTitle("idm", title: t) || wordInTitle("tcs", title: t) { depts.insert("IDM") }
            if wordInTitle("music tech", title: t) || wordInTitle("mtech", title: t) { depts.insert("Music Tech") }
            if wordInTitle("marl", title: t) || wordInTitle("marl_", title: t) || wordInTitle("marl-", title: t) { depts.insert("MARL") }
            if wordInTitle("cdi", title: t) || wordInTitle("recorded music", title: t) || wordInTitle("clive", title: t) { depts.insert("CDI / Recorded Music") }
            if wordInTitle("game center", title: t) { depts.insert("Game Center") }
            if wordInTitle("mpap", title: t) { depts.insert("MPAP") }
            if wordInTitle("alt", title: t) || wordInTitle("alt-", title: t) || wordInTitle("ect", title: t) { depts.insert("ALT (Ed Leadership, ECT, and Higher and Post Secondary Education)") }
            
            if depts.isEmpty {
                depts.insert("Other Group(s)")
            }
        }
        return Array(depts).sorted()
    }
    
    static func mapSchool(deptStr: String, titleStr: String) -> String {
        let d = cleanDepartment(deptStr)
        
        let steinhardtDepts = [
            "ALT (Ed Leadership, ECT, and Higher and Post Secondary Education)", 
            "MARL", "Music Tech", "MPAP",
            "Sony Audio Institute",
            "MPAP Other -- Concert Music, Screen Scoring, Songwriting, and Vocal Performance programs",
            "Music Business", "STEM From Dance"
        ]
        let tischDepts = [
            "CDI / Recorded Music", "Game Center", "ITP / IMA / Low Res",
            "Game Innovation Lab", "Tisch Drama", "Performance Studies",
            "Tisch Film", "Dramatic Writing", "Tisch Dance", "Mary Markhvida"
        ]
        let tandonDepts = [
            "IDM", "CREO center ", "Ability Project", "Future Labs", "Veterans Lab",
            "Data Future Lab", "Urban Future Lab (UFL) / Ninedot Energy (NDE)",
            "Entrepreneurial Institute", "Center for Responsible AI",
            "Institute for Invention, Innovation, and Entrepreneurship",
            "Computer Science and Engineering (CS and CSE)",
            "Electrical and Computer Engineering (ECE)", "NYU Wireless",
            "Center for Advanced Technology and Telecommunications",
            "NYU Video Lab", "NYU Center for Cybersecurity", "OSIRIS Lab",
            "Visualization and Data Analytics Lab", "Center for Urban Science and Progress (CUSP)",
            "The Marron Institute of Urban Management", "Digital Learning",
            "OSLE - Office of Student Leadership and Engagement ",
            "Civil and urban engineering ", "Tandon PhD Hub",
            "EG electrical engineering ", "CBE Chemical Biomedical Electical Engineering ",
            "TSLE Tandon student Leadership & Engagement",
            "Mechanical Space Engineering - MAE", "Bio Medical Engineering ",
            "Finance and Risk Engineering - FRE", "TCS", "MakerSpace",
            "Undergraduate Admissions - UGA", "Applied Physics", "Tech Kids Unlimited "
        ]
        let centralDepts = [
            "Provost ", "President's Office", "University Development and Alumni Relations (UDAR)",
            "Admissions", "Wasserman Center", "CBS"
        ]
        let greaterNyuDepts = [
            "College of Arts and Sciences (CAS)", "Gallatin", "Law School ", "Liberal Studies ", "Linguistics"
        ]
        let communityPartnerDepts = [
            "The Issue Project Room", "Brooklyn Book Festival", "Brooklyn Caribbean Literary Festival"
        ]
        let genericDepts = ["Dean's Office", "Student Affairs", "Student Affairs ", "AMC - Administrative Management Council"]
        
        if steinhardtDepts.contains(d) { return "Steinhardt" }
        if tischDepts.contains(d) { return "Tisch" }
        if tandonDepts.contains(d) { return "Tandon" }
        if centralDepts.contains(d) { return "Central" }
        if greaterNyuDepts.contains(d) { return "Greater NYU" }
        if d == "Community Partner" || communityPartnerDepts.contains(d) { return "URPA / Community Partner" }
        
        let t = titleStr.lowercased()
        
        if genericDepts.contains(d) {
            if t.contains("tisch") || t.contains("film") || t.contains("drama") { return "Tisch" }
            if t.contains("steinhardt") { return "Steinhardt" }
            if ["tandon", "cusp", "ece", "sase", "nsbe"].contains(where: { t.contains($0) }) { return "Tandon" }
        }
        
        if t.contains("tisch") || t.contains("film") || t.contains("drama") { return "Tisch" }
        if t.contains("steinhardt") { return "Steinhardt" }
        if ["tandon", "cusp", "ece", "sase", "nsbe", "terra", "csaw", "mae seminar", "cybersecurity"].contains(where: { t.contains($0) }) { return "Tandon" }
        
        return "Other Schools"
    }
    
    static func getSemester(date: Date?) -> String {
        guard let d = date else { return "Other" }
        let calendar = Calendar.current
        let year = calendar.component(.year, from: d)
        let month = calendar.component(.month, from: d)
        let day = calendar.component(.day, from: d)
        
        if month >= 9 { return "Fall \(year)" }
        else if month == 1 && day <= 18 { return "Winter \(year)" }
        else if month == 1 && day > 18 { return "Spring \(year)" }
        else if month >= 2 && month <= 4 { return "Spring \(year)" }
        else if month == 5 && day <= 16 { return "Spring \(year)" }
        else { return "Summer \(year)" }
    }
    
    static func parseTime(from str: String) -> Date? {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased() == "nan" { return nil }
        
        let formats = [
            "h:mm a", "hh:mm a", "H:mm", "HH:mm", "HH:mm:ss", "h:mm:ss a"
        ]
        
        let df = DateFormatter()
        for format in formats {
            df.dateFormat = "yyyy-MM-dd " + format
            if let d = df.date(from: "2000-01-01 " + trimmed) {
                return d
            }
        }
        return nil
    }
    
    static func calcCappedHours(res: Reservation) -> Double {
        var daysCorrection = 1
        
        let stStr = res.bookingStartTime
        let etStr = res.bookingEndTime
        
        if let sDt = parseTime(from: stStr), let eDt = parseTime(from: etStr) {
            if eDt.timeIntervalSince(sDt) < 0 {
                daysCorrection = 0
            }
        }
        
        var days = 1
        if let start = res.bookingStartDate, let end = res.bookingEndDate {
            let cal = Calendar.current
            let components = cal.dateComponents([.day], from: start, to: end)
            days = max(1, (components.day ?? 0) + daysCorrection)
        }
        
        var rawHours = 0.0
        if let ah = res.actualHours, ah >= 0 { rawHours = ah }
        else if let th = res.timeInUseHours, th >= 0 { rawHours = th }
        
        var rooms = res.numRoomsUsed
        if rooms < 1 { rooms = 1 }
        
        let cap = Double(days * 12 * rooms)
        return (min(rawHours, cap) * 100).rounded() / 100
    }
    
    static func processReservations(reservations: [Reservation], startDate: Date, endDate: Date) -> (overall: [Reservation], rooms: [Reservation], deptsSchools: [Reservation], raw: [Reservation], semesters: [String]) {
        var raw = reservations
        
        // 1. Initial Data Fixes (Native CSV hours)
        for i in 0..<raw.count {
            // Basic emulation of the pandas start/end time diff logic
            let res = raw[i]
            var days = 1
            if let sDate = res.bookingStartDate, let eDate = res.bookingEndDate {
                let comps = Calendar.current.dateComponents([.day], from: sDate, to: eDate)
                days = max(1, (comps.day ?? 0) + 1)
            }
            
            let stStr = res.bookingStartTime
            let etStr = res.bookingEndTime
            
            if let s = parseTime(from: stStr), let e = parseTime(from: etStr) {
                var hoursDiff = e.timeIntervalSince(s) / 3600.0
                var daysCorrection = 1
                if hoursDiff < 0 {
                    hoursDiff += 24.0
                    daysCorrection = 0
                }
                
                if let sDate = res.bookingStartDate, let eDate = res.bookingEndDate {
                    let comps = Calendar.current.dateComponents([.day], from: sDate, to: eDate)
                    days = max(1, (comps.day ?? 0) + daysCorrection)
                }
                
                hoursDiff = min(hoursDiff, 12.0)
                let baseHours = (max(0, hoursDiff) * Double(days) * 100).rounded() / 100
                let totalHours = (baseHours * Double(max(1, res.numRoomsUsed)) * 100).rounded() / 100
                
                // The python code checks for Time In Use, Hours and ACTUAL hours
                if raw[i].rawData["Time In Use, Hours"] != nil {
                    raw[i].rawData["Time In Use, Hours"] = String(format: "%.2f", baseHours)
                }
                if raw[i].rawData["ACTUAL hours"] != nil || raw[i].rawData["Time In Use, Hours"] == nil {
                    raw[i].rawData["ACTUAL hours"] = String(format: "%.2f", totalHours)
                }
            }
            
            // Filters
            raw[i].filteredOut = false
            raw[i].filterReason = ""
            
            // Status filter
            let status = res.endEventStatus.lowercased()
            let hasCheckedIn = status.contains("checked in")
            let hasCheckedOut = status.contains("checked out")
            let hasApproval = status.contains("approved") || hasCheckedOut || hasCheckedIn
            let hasRejection = status.contains("declined") || status.contains("canceled") || status.contains("cancelled") || status.contains("no show")
            
            if !(hasApproval && !hasRejection) {
                raw[i].filteredOut = true
                raw[i].filterReason += "Status: \(res.endEventStatus); "
            }
            
            // Maintenance filter
            let type = res.bookingType.lowercased()
            let title = res.reservationTitle.lowercased()
            if type.contains("maintenance") || title.contains("maintenance") {
                raw[i].filteredOut = true
                raw[i].filterReason += "Maintenance; "
            }
            
            // Room 000
            if res.roomsStr.contains("000") {
                raw[i].filteredOut = true
                raw[i].filterReason += "Room 000; "
            }
            
            // Dates
            raw[i].semester = getSemester(date: res.bookingStartDate)
            if let sDate = res.bookingStartDate {
                if sDate < startDate || sDate > endDate {
                    raw[i].filteredOut = true
                    raw[i].filterReason += "Outside Selected Date Range; "
                }
            } else {
                raw[i].filteredOut = true
                raw[i].filterReason += "Invalid Date; "
            }
            
            // Override
            let overrideStr = res.manualOverrideFiltered.lowercased()
            if overrideStr == "true" {
                raw[i].filteredOut = true
                raw[i].filterReason = "Manual Override; "
            } else if overrideStr == "false" {
                raw[i].filteredOut = false
                raw[i].filterReason = ""
            }
        }
        
        let validOverall = raw.filter { !$0.filteredOut }
        var overall = validOverall
        
        // Populate calcHours and All Depts
        for i in 0..<overall.count {
            overall[i].calcHours = calcCappedHours(res: overall[i])
            overall[i].allDepts = extractDepartments(deptStr: overall[i].department, title: overall[i].reservationTitle)
            
            let schools = overall[i].allDepts.map { mapSchool(deptStr: $0, titleStr: overall[i].reservationTitle) }
            overall[i].rawData["School"] = Array(Set(schools)).sorted().joined(separator: ", ")
        }
        
        // Rooms split
        var roomsSplit = [Reservation]()
        for res in overall {
            let rStr = res.roomsStr.isEmpty || res.roomsStr.lowercased() == "nan" ? "Other" : res.roomsStr
            let rList = rStr.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            
            let totalRooms = max(1, res.numRoomsUsed)
            
            for r in rList {
                var newRow = res
                newRow.rawData["Clean Room"] = cleanRoom(r)
                newRow.calcHours = res.calcHours / Double(totalRooms)
                roomsSplit.append(newRow)
            }
        }
        
        // Dept/School split
        var deptsSchools = [Reservation]()
        for res in overall {
            for d in res.allDepts {
                var newRow = res
                newRow.rawData["Clean Department"] = d
                let school = mapSchool(deptStr: d, titleStr: res.reservationTitle)
                newRow.rawData["Clean School"] = school
                newRow.rawData["School"] = school
                deptsSchools.append(newRow)
            }
        }
        
        let sems = Array(Set(overall.map { $0.semester })).filter { $0 != "Other" }.sorted()
        
        return (overall, roomsSplit, deptsSchools, raw, sems)
    }
    
    static func applyEdits(edits: [(id: Int, column: String, value: String)], to raw: inout [Reservation]) {
        for edit in edits {
            if let idx = raw.firstIndex(where: { $0.id == edit.id }) {
                var mappedCol = edit.column
                if mappedCol == "Clean Department" { mappedCol = "Department" }
                else if mappedCol == "Clean Room" { mappedCol = "Room(s)" }
                else if mappedCol == "Clean School" { continue } // Derived from Dept
                
                raw[idx].rawData[mappedCol] = edit.value
            }
        }
    }
    
    static func generateOneSheet(pack: (overall: [Reservation], rooms: [Reservation], deptsSchools: [Reservation], raw: [Reservation], semesters: [String]), historicCSVRows: [[String]], startDate: Date) -> [[String]] {
        let df_overall = pack.overall
        let df_rooms = pack.rooms
        let df_deptsSchools = pack.deptsSchools
        
        let cal = Calendar.current
        let year = cal.component(.year, from: startDate)
        let month = cal.component(.month, from: startDate)
        let ayStartYear = month >= 9 ? year : year - 1
        
        let ayCode = "AY\(String(ayStartYear + 1).suffix(2))"
        let prevAyCode = "AY\(String(ayStartYear).suffix(2))"
        
        var outputLines = [[String]]()
        
        for line in historicCSVRows {
            outputLines.append(line)
            
            if line.count > 1 && line[1].trimmingCharacters(in: .whitespaces) == prevAyCode {
                let entity = line.count > 2 ? line[2].trimmingCharacters(in: .whitespaces) : ""
                
                var catCol = ""
                if entity == "All of Media Commons" { catCol = "Overall" }
                else if ["ALT", "ALT ", "IDM", "ITP / IMA / Low Res", "CDI / Recorded Music", "Music Tech", "MARL", "Game Center", "Community Partner", "Other Group(s)"].contains(entity) { catCol = "Clean Department" }
                else if ["Tandon", "Tisch", "Steinhardt", "Other School"].contains(entity) { catCol = "Clean School" }
                else { catCol = "Clean Room" }
                
                var resCount = 0
                var hsCount = 0.0
                
                if catCol == "Overall" {
                    resCount = df_overall.count
                    hsCount = df_overall.reduce(0.0) { $0 + $1.calcHours }
                } else if catCol == "Clean Department" {
                    let searchEntity = (entity == "ALT" || entity == "ALT ") ? "ALT (Ed Leadership, ECT, and Higher and Post Secondary Education)" : entity
                    let subset = df_deptsSchools.filter { $0.rawData["Clean Department"] == searchEntity }
                    resCount = subset.count
                    hsCount = subset.reduce(0.0) { $0 + $1.calcHours }
                } else if catCol == "Clean School" {
                    let searchEntity = entity == "Other School" ? "Other Schools" : entity
                    let subset = df_deptsSchools.filter { $0.rawData["Clean School"] == searchEntity }
                    resCount = subset.count
                    hsCount = subset.reduce(0.0) { $0 + $1.calcHours }
                } else {
                    let subset = df_rooms.filter { $0.rawData["Clean Room"] == entity.trimmingCharacters(in: .whitespaces) }
                    resCount = subset.count
                    hsCount = subset.reduce(0.0) { $0 + $1.calcHours }
                }
                
                let prevResStr = line.count > 3 ? line[3].replacingOccurrences(of: ",", with: "") : "0"
                let prevRes = Double(prevResStr) ?? 0.0
                
                var pctStr = ""
                if prevRes > 0 {
                    let pctChange = ((Double(resCount) - prevRes) / prevRes) * 100
                    pctStr = String(format: "%.2f%%", pctChange)
                }
                
                var newRow = ["", ayCode, entity, "\(resCount)", String(format: "%.2f", hsCount), pctStr, "", "", ""]
                while newRow.count < line.count { newRow.append("") }
                outputLines.append(newRow)
            }
        }
        return outputLines
    }
}
