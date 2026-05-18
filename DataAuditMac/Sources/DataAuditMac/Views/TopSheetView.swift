import SwiftUI

struct TopSheetView: View {
    let pack: (overall: [Reservation], rooms: [Reservation], deptsSchools: [Reservation], raw: [Reservation], semesters: [String])
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Top Sheet Overview")
                    .font(.title)
                
                let sems = pack.semesters
                
                HStack {
                    Spacer()
                    ForEach(sems, id: \.self) { sem in
                        Text(sem).bold().frame(width: 80, alignment: .trailing)
                    }
                    Text("Total:").bold().frame(width: 80, alignment: .trailing)
                }
                
                Divider()
                
                // Overall
                let totalRes = sems.map { s in pack.overall.filter({ $0.semester == s }).count }
                let totalHrs = sems.map { s in pack.overall.filter({ $0.semester == s }).reduce(0) { $0 + $1.calcHours } }
                
                rowView(title: "Total Reservations", values: totalRes.map { Double($0) }, isInt: true)
                rowView(title: "Total Hours", values: totalHrs, isInt: false)
                
                Divider()
                
                // Rooms
                Text("Reservations per room:").font(.headline)
                let roomOrder = ["1201 Seminar Room", "233 Co-Lab", "230 Audio Lab", "221-224 Ballrooms", "220 Blackbox", "202 Lecture Hall", "103 Garage", "260 Post Production Lab"]
                ForEach(roomOrder, id: \.self) { room in
                    let vals = sems.map { s in pack.rooms.filter({ $0.semester == s && $0.rawData["Clean Room"] == room }).count }
                    rowView(title: room, values: vals.map { Double($0) }, isInt: true)
                }
                
                Text("Hours per room:").font(.headline)
                ForEach(roomOrder, id: \.self) { room in
                    let vals = sems.map { s in pack.rooms.filter({ $0.semester == s && $0.rawData["Clean Room"] == room }).reduce(0) { $0 + $1.calcHours } }
                    rowView(title: room, values: vals, isInt: false)
                }
                
                Divider()
                
                // Departments
                Text("Reservations per program:").font(.headline)
                let progOrder = ["ALT (Ed Leadership, ECT, and Higher and Post Secondary Education)", "IDM", "ITP / IMA / Low Res", "CDI / Recorded Music", "Music Tech", "MARL", "MPAP", "Game Center", "Other Group(s)", "Community Partner"]
                ForEach(progOrder, id: \.self) { prog in
                    let vals = sems.map { s in pack.deptsSchools.filter({ $0.semester == s && $0.rawData["Clean Department"] == prog }).count }
                    rowView(title: prog, values: vals.map { Double($0) }, isInt: true)
                }
                
                Text("Hours per program:").font(.headline)
                ForEach(progOrder, id: \.self) { prog in
                    let vals = sems.map { s in pack.deptsSchools.filter({ $0.semester == s && $0.rawData["Clean Department"] == prog }).reduce(0) { $0 + $1.calcHours } }
                    rowView(title: prog, values: vals, isInt: false)
                }
                
                Divider()
                
                // Schools
                Text("Reservations per School:").font(.headline)
                let schoolOrder = ["Tandon", "Tisch", "Steinhardt", "Provost", "URPA / Community Partner", "Central", "Greater NYU", "Other Schools"]
                ForEach(schoolOrder, id: \.self) { school in
                    let vals = sems.map { s in pack.deptsSchools.filter({ $0.semester == s && $0.rawData["Clean School"] == school }).count }
                    rowView(title: school, values: vals.map { Double($0) }, isInt: true)
                }
                
                Text("Hours per School:").font(.headline)
                ForEach(schoolOrder, id: \.self) { school in
                    let vals = sems.map { s in pack.deptsSchools.filter({ $0.semester == s && $0.rawData["Clean School"] == school }).reduce(0) { $0 + $1.calcHours } }
                    rowView(title: school, values: vals, isInt: false)
                }
            }
            .padding()
        }
    }
    
    private func rowView(title: String, values: [Double], isInt: Bool) -> some View {
        HStack {
            Text(title).frame(maxWidth: .infinity, alignment: .leading)
            ForEach(0..<values.count, id: \.self) { i in
                Text(formatVal(values[i], isInt: isInt))
                    .frame(width: 80, alignment: .trailing)
            }
            Text(formatVal(values.reduce(0, +), isInt: isInt))
                .bold()
                .frame(width: 80, alignment: .trailing)
        }
    }
    
    private func formatVal(_ val: Double, isInt: Bool) -> String {
        if isInt {
            return "\(Int(val))"
        } else {
            return String(format: "%.2f", val)
        }
    }
}
