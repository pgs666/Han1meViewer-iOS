import AVKit
import SwiftUI

struct PlayerView: View {
    let title: String
    let sources: [VideoPlaybackSourceRow]

    @State private var selectedSourceID: String
    @State private var player: AVPlayer?

    init(title: String, sources: [VideoPlaybackSourceRow]) {
        self.title = title
        self.sources = sources
        let defaultSource = sources.first { $0.isDefault } ?? sources.first
        _selectedSourceID = State(initialValue: defaultSource?.id ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            if let player {
                VideoPlayer(player: player)
                    .background(Color.black)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "play.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("\u{65E0}\u{6CD5}\u{6253}\u{5F00}\u{64AD}\u{653E}\u{6E90}")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if sources.count > 1 {
                Picker("\u{6E05}\u{6670}\u{5EA6}", selection: $selectedSourceID) {
                    ForEach(sources) { source in
                        Text(source.label).tag(source.id)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            configurePlayer(preservePosition: false)
        }
        .onDisappear {
            player?.pause()
        }
        .onChange(of: selectedSourceID) { _ in
            configurePlayer(preservePosition: true)
        }
    }

    private var selectedSource: VideoPlaybackSourceRow? {
        sources.first { $0.id == selectedSourceID } ?? sources.first
    }

    private func configurePlayer(preservePosition: Bool) {
        guard let source = selectedSource, let url = URL(string: source.url) else {
            player = nil
            return
        }

        let previousPlayer = player
        let previousTime = preservePosition ? previousPlayer?.currentTime() : nil
        let shouldResume = previousPlayer?.timeControlStatus == .playing
        let nextPlayer = AVPlayer(url: url)
        player = nextPlayer

        if let previousTime {
            nextPlayer.seek(to: previousTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                if shouldResume {
                    nextPlayer.play()
                }
            }
        } else if shouldResume {
            nextPlayer.play()
        }
    }
}
