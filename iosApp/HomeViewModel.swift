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
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0

    init(homeFeature: HomeFeature) {
        self.homeFeature = homeFeature
    }

    deinit {
        loadTask?.cancel()
    }

    func loadIfNeeded() {
        switch state {
        case .idle, .failed:
            load()
        case .loading, .loaded:
            return
        }
    }

    func load() {
        loadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        state = .loading
        loadTask = Task { [weak self] in
            await self?.loadHome(generation: generation)
        }
    }

    func refresh() async {
        loadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        await loadHome(generation: generation)
    }

    private func loadHome(generation: Int) async {
        do {
            let snapshot = try await homeFeature.loadHome()
            guard !Task.isCancelled, generation == loadGeneration else { return }
            state = .loaded(HomeScreenSnapshot(snapshot))
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, generation == loadGeneration else { return }
            CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
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
                    coverUrl: video.coverUrl,
                    duration: video.duration,
                    views: video.views,
                    uploadTime: video.uploadTime,
                    artist: video.artist,
                    reviews: video.reviews
                )
            }

            guard !videos.isEmpty else {
                return nil
            }

            return HomeSectionRow(
                key: section.key,
                title: HomeSectionRow.localizedTitle(for: section.key),
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

    static func localizedTitle(for key: String) -> String {
        switch key {
        case "latestRelease":
            return String(localized: "home.section.latest_release")
        case "latestHanime":
            return String(localized: "home.section.latest_hanime")
        case "ecchiAnime":
            return String(localized: "home.section.ecchi_anime")
        case "shortEpisodeAnime":
            return String(localized: "home.section.short_episode_anime")
        case "motionAnime":
            return String(localized: "home.section.motion_anime")
        case "threeDCG":
            return String(localized: "home.section.three_d_cg")
        case "twoPointFiveDAnime":
            return String(localized: "home.section.two_point_five_d")
        case "twoDAnime":
            return String(localized: "home.section.two_d")
        case "aiGenerated":
            return String(localized: "home.section.ai_generated")
        case "mmd":
            return String(localized: "home.section.mmd")
        case "cosplay":
            return String(localized: "home.section.cosplay")
        case "watchingNow":
            return String(localized: "home.section.watching_now")
        default:
            return key
        }
    }
}

struct HomeVideoRow: Identifiable {
    let videoCode: String
    let title: String
    let coverUrl: String?
    let duration: String?
    let views: String?
    let uploadTime: String?
    let artist: String?
    let reviews: String?

    var id: String { videoCode }

    var footerMetadata: String {
        [reviews, uploadTime]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
    }
}
