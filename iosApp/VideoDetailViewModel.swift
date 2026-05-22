import Foundation
import Han1meShared

@MainActor
final class VideoDetailViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(VideoDetailSnapshot)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let videoFeature: VideoFeature

    init(videoFeature: VideoFeature) {
        self.videoFeature = videoFeature
    }

    func load(videoCode: String) {
        guard case .loading = state else {
            state = .loading
            Task {
                await loadVideo(videoCode: videoCode)
            }
            return
        }
    }

    private func loadVideo(videoCode: String) async {
        do {
            let snapshot = try await videoFeature.loadVideo(videoCode: videoCode)
            state = .loaded(snapshot)
        } catch {
            state = .failed(ErrorMessage.userFriendly(error))
        }
    }
}
