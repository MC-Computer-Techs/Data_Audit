import SwiftUI

struct FilteredBookingsView: View {
    let pack: (overall: [Reservation], rooms: [Reservation], deptsSchools: [Reservation], raw: [Reservation], semesters: [String])
    let onUpdate: () -> Void
    
    var body: some View {
        VStack {
            Text("Filtered Bookings")
                .font(.largeTitle)
            Text("This view will show all bookings that were filtered out of the audit.")
                .foregroundColor(.secondary)
            
            let filtered = pack.raw.filter { $0.filteredOut }
            
            List(filtered) { res in
                VStack(alignment: .leading) {
                    Text(res.reservationTitle).font(.headline)
                    Text("Reason: \(res.filterReason)").foregroundColor(.red)
                }
            }
        }
        .padding()
    }
}
