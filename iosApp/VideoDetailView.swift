import SwiftUI

struct VideoDetailView: View {
    let videoCode: String

    var body: some View {
        List {
            Section("Video") {
                Text(videoCode)
                NavigationLink("Play") {
                    PlayerView()
                }
            }
        }
        .navigationTitle("Detail")
    }
}
