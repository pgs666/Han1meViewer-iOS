import Foundation
import Han1meShared

@MainActor
final class OnlineWatchHistoryViewModel: PaginatedViewModel<OnlineWatchHistoryScreenSnapshot> {
    enum SortMode: String, CaseIterable, Identifiable {
        case latest
        case oldest

        var id: String { rawValue }

        var title: String {
            switch self {
            case .latest:
                return String(localized: "online_history.sort.latest")
            case .oldest:
                return String(localized: "online_history.sort.oldest")
            }
        }
    }

    @Published var sortMode: SortMode = .latest
    @Published var actionErrorMessage: String?

    private let feature: OnlineWatchHistoryFeature
    private var mutationTask: Task<Void, Never>?

    init(feature: OnlineWatchHistoryFeature) {
        self.feature = feature
    }

    func changeSortMode(_ mode: SortMode) {
        guard sortMode != mode else { return }
        sortMode = mode
        load()
    }

    func delete(at offsets: IndexSet) {
        guard case .loaded(let snapshot) = state else { return }

        let videoCodes = offsets.map { snapshot.videos[$0].videoCode }
        state = .loaded(snapshot.removing(videoCodes: videoCodes))
        actionErrorMessage = nil

        let feature = feature
        let csrfToken = snapshot.csrfToken
        mutationTask?.cancel()
        mutationTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for videoCode in videoCodes {
                        group.addTask {
                            _ = try await feature.remove(videoCode: videoCode, csrfToken: csrfToken)
                        }
                    }
                    try await group.waitForAll()
                }
            } catch {
                CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
                actionErrorMessage = ErrorMessage.userFriendly(error)
                load()
            }
        }
    }

    override func executeLoad(page: Int32, appendingTo existingSnapshot: OnlineWatchHistoryScreenSnapshot?, generation: Int) async {
        do {
            let snapshot: OnlineWatchHistorySnapshot
            switch sortMode {
            case .latest:
                snapshot = try await feature.loadLatest(page: page)
            case .oldest:
                snapshot = try await feature.loadOldest(page: page)
            }

            guard !Task.isCancelled, generation == currentGeneration else { return }
            if snapshot.authRequired {
                setFailed(String(localized: "online_history.auth.required"))
                return
            }

            let screenSnapshot = OnlineWatchHistoryScreenSnapshot(snapshot, appendingTo: existingSnapshot)
            applyLoadResult(screenSnapshot)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, generation == currentGeneration else { return }
            applyLoadError(error, appendingTo: existingSnapshot)
        }
    }
}

struct OnlineWatchHistoryScreenSnapshot: PaginatedSnapshot {
    let page: Int32
    let hasNext: Bool
    let csrfToken: String?
    let videos: [OnlineWatchHistoryRow]
    let loadMoreError: String?

    var lastItemID: String? { videos.last?.id }

    init(_ snapshot: OnlineWatchHistorySnapshot, appendingTo existingSnapshot: OnlineWatchHistoryScreenSnapshot? = nil) {
        page = snapshot.page
        hasNext = snapshot.hasNext
        csrfToken = snapshot.csrfToken ?? existingSnapshot?.csrfToken

        let videoCount = Int(snapshot.videoCount())
        let newVideos: [OnlineWatchHistoryRow] = (0..<videoCount).compactMap { index in
            guard let video = snapshot.videoAt(index: Int32(index)) else {
                return nil
            }
            return OnlineWatchHistoryRow(
                videoCode: video.videoCode,
                title: video.title,
                coverUrl: video.coverUrl,
                duration: video.duration,
                views: video.views,
                artist: video.artist,
                uploadTime: video.uploadTime
            )
        }

        videos = mergeByIdentifiable(existingSnapshot?.videos ?? [], with: newVideos)
        loadMoreError = nil
    }

    private init(
        page: Int32,
        hasNext: Bool,
        csrfToken: String?,
        videos: [OnlineWatchHistoryRow],
        loadMoreError: String?
    ) {
        self.page = page
        self.hasNext = hasNext
        self.csrfToken = csrfToken
        self.videos = videos
        self.loadMoreError = loadMoreError
    }

    func withLoadMoreError(_ message: String) -> OnlineWatchHistoryScreenSnapshot {
        OnlineWatchHistoryScreenSnapshot(
            page: page,
            hasNext: hasNext,
            csrfToken: csrfToken,
            videos: videos,
            loadMoreError: message
        )
    }

    func removing(videoCodes: [String]) -> OnlineWatchHistoryScreenSnapshot {
        OnlineWatchHistoryScreenSnapshot(
            page: page,
            hasNext: hasNext,
            csrfToken: csrfToken,
            videos: videos.filter { !videoCodes.contains($0.videoCode) },
            loadMoreError: loadMoreError
        )
    }
}

struct OnlineWatchHistoryRow: Identifiable {
    let videoCode: String
    let title: String
    let coverUrl: String?
    let duration: String?
    let views: String?
    let artist: String?
    let uploadTime: String?

    var id: String { videoCode }

    var metadata: String {
        [artist, uploadTime, duration, views]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
    }
}
