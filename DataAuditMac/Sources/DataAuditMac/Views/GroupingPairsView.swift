import SwiftUI

struct GroupingPairsView: View {
    let pack: (overall: [Reservation], rooms: [Reservation], deptsSchools: [Reservation], raw: [Reservation], semesters: [String])
    let onUpdate: () -> Void
    
    var body: some View {
        VStack {
            Text("Grouping Pairs")
                .font(.largeTitle)
            Text("In a full implementation, this view will show data tables for Schools, Departments, and Rooms.")
                .foregroundColor(.secondary)
            
            // To be implemented fully with editable data tables.
            List {
                ForEach(pack.semesters, id: \.self) { sem in
                    Section(header: Text(sem).font(.headline)) {
                        Text("\(pack.deptsSchools.filter({ $0.semester == sem }).count) Department/School entries")
                        Text("\(pack.rooms.filter({ $0.semester == sem }).count) Room entries")
                    }
                }
            }
            
            Button("Recalculate Totals") {
                onUpdate()
            }
            .padding()
        }
        .padding()
    }
}
