import Foundation
import Han1meShared

@MainActor
final class HomeViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(HomeScreenSnapshot)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let homeFeature: HomeFeature

    init(homeFeature: HomeFeature) {
        self.homeFeature = homeFeature
    }

    func load() {
        guard case .loading = state else {
            state = .loading
            Task {
                await loadHome()
            }
            return
        }
    }

    private func loadHome() async {
        do {
            let snapshot = try await homeFeature.loadHome()
            state = .loaded(HomeScreenSnapshot(snapshot))
        } catch {
            state = .failed(ErrorMessage.userFriendly(error))
        }
    }
}

struct HomeScreenSnapshot {
    let summary: String
    let baseUrl: String
    let bannerTitle: String?
    let videos: [HomeVideoRow]

    init(_ snapshot: HomeFeedSnapshot) {
        summary = snapshot.summary
        baseUrl = snapshot.baseUrl
        bannerTitle = snapshot.bannerTitle

        let count = Int(snapshot.videoCount())
        videos = (0..<count).compactMap { index in
            guard let video = snapshot.videoAt(index: Int32(index)) else {
                return nil
            }
            return HomeVideoRow(
                videoCode: video.videoCode,
                title: video.title,
                coverUrl: video.coverUrl,
                sectionTitle: video.sectionTitle
            )
        }
    }
}

struct HomeVideoRow: Identifiable {
    let videoCode: String
    let title: String
    let coverUrl: String?
    let sectionTitle: String

    var id: String { videoCode }
}
