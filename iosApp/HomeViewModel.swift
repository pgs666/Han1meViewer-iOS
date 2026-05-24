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

    func loadIfNeeded() {
        guard case .idle = state else {
            return
        }
        load()
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
    let banner: HomeBannerRow?
    let sections: [HomeSectionRow]

    init(_ snapshot: HomeFeedSnapshot) {
        if let title = snapshot.bannerTitle {
            banner = HomeBannerRow(
                title: title,
                description: snapshot.bannerDescription,
                imageUrl: snapshot.bannerImageUrl,
                videoCode: snapshot.bannerVideoCode
            )
        } else {
            banner = nil
        }

        let sectionCount = Int(snapshot.homeSectionCount())
        sections = (0..<sectionCount).compactMap { sectionIndex -> HomeSectionRow? in
            guard let section = snapshot.homeSectionAt(index: Int32(sectionIndex)) else {
                return nil
            }

            let videoCount = Int(section.videoCount())
            let videos = (0..<videoCount).compactMap { videoIndex -> HomeVideoRow? in
                guard let video = section.videoAt(index: Int32(videoIndex)) else {
                    return nil
                }
                return HomeVideoRow(
                    videoCode: video.videoCode,
                    title: video.title,
                    coverUrl: video.coverUrl
                )
            }

            guard !videos.isEmpty else {
                return nil
            }

            return HomeSectionRow(
                key: section.key,
                title: section.title,
                videos: videos
            )
        }
    }
}

struct HomeBannerRow {
    let title: String
    let description: String?
    let imageUrl: String?
    let videoCode: String?

    var canOpenVideo: Bool {
        videoCode?.isEmpty == false
    }
}

struct HomeSectionRow: Identifiable {
    let key: String
    let title: String
    let videos: [HomeVideoRow]

    var id: String { key }
}

struct HomeVideoRow: Identifiable {
    let videoCode: String
    let title: String
    let coverUrl: String?

    var id: String { videoCode }
}
