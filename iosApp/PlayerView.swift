import AVKit
import SwiftUI

struct PlayerView: View {
    let sourceUrl: String
    let title: String

    var body: some View {
        if let url = URL(string: sourceUrl) {
            VideoPlayer(player: AVPlayer(url: url))
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            Text("Invalid playback URL")
                .navigationTitle("Player")
        }
    }
}
