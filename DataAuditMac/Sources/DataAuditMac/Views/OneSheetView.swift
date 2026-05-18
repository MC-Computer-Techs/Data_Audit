import SwiftUI

struct OneSheetView: View {
    var body: some View {
        VStack {
            Text("One Sheet")
                .font(.largeTitle)
            Text("This view will show the historical metrics tracking.")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
