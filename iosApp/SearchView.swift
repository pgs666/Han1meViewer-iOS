import SwiftUI

struct SearchView: View {
    @State private var keyword = ""

    var body: some View {
        NavigationView {
            List {
                TextField("Search", text: $keyword)
                Text("Search repository wiring pending")
            }
            .navigationTitle("Search")
        }
        .navigationViewStyle(.stack)
    }
}
