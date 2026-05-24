import Foundation
import Han1meShared

@MainActor
final class OnlineWatchHistoryViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(OnlineWatchHistoryScreenSnapshot)
        case loadingMore(OnlineWatchHistoryScreenSnapshot)
        case failed(String)
    }

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

    @Published private(set) var state: State = .idle
    @Published var sortMode: SortMode = .latest
    @Published var actionErrorMessage: String?

    private let feature: OnlineWatchHistoryFeature
    private var currentPage: Int32 = 0
    private var hasNextPage = false
    private var loadTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var mutationTask: Task<Void, Never>?
    private var requestGeneration = 0

    init(feature: OnlineWatchHistoryFeature) {
        self.feature = feature
    }

    deinit {
        loadTask?.cancel()
        loadMoreTask?.cancel()
        mutationTask?.cancel()
    }

    func load() {
        loadTask?.cancel()
        loadMoreTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        currentPage = 0
        hasNextPage = false
        state = .loading
        loadTask = Task { [weak self] in
            await self?.load(page: 1, appendingTo: nil, generation: generation)
        }
    }

    func changeSortMode(_ mode: SortMode) {
        guard sortMode != mode else {
            return
        }
        sortMode = mode
        load()
    }

    func loadMoreIfNeeded(currentVideoID: String?) {
        guard hasNextPage, !isLoading else {
            return
        }
        guard case .loaded(let snapshot) = state else {
            return
        }
        guard snapshot.videos.last?.id == currentVideoID else {
            return
        }

        let nextPage = currentPage + 1
        let generation = requestGeneration
        state = .loadingMore(snapshot)
        loadMoreTask = Task { [weak self] in
            await self?.load(page: nextPage, appendingTo: snapshot, generation: generation)
        }
    }

    func delete(at offsets: IndexSet) {
        guard case .loaded(let snapshot) = state else {
            return
        }

        let videoCodes = offsets.map { snapshot.videos[$0].videoCode }
        state = .loaded(snapshot.removing(videoCodes: videoCodes))
        actionErrorMessage = nil

        mutationTask?.cancel()
        mutationTask = Task { [weak self] in
            guard let self else { return }
            for videoCode in videoCodes {
                do {
                    _ = try await feature.remove(videoCode: videoCode, csrfToken: snapshot.csrfToken)
                } catch {
                    CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
                    actionErrorMessage = ErrorMessage.userFriendly(error)
                    load()
                    return
                }
            }
        }
    }

    private var isLoading: Bool {
        switch state {
        case .loading, .loadingMore:
            return true
        case .idle, .loaded, .failed:
            return false
        }
    }

    private func load(page: Int32, appendingTo existingSnapshot: OnlineWatchHistoryScreenSnapshot?, generation: Int) async {
        do {
            let snapshot: OnlineWatchHistorySnapshot
            switch sortMode {
            case .latest:
                snapshot = try await feature.loadLatest(page: page)
            case .oldest:
                snapshot = try await feature.loadOldest(page: page)
            }

            guard !Task.isCancelled, generation == requestGeneration else { return }
            if snapshot.authRequired {
                state = .failed(String(localized: "online_history.auth.required"))
                currentPage = 0
                hasNextPage = false
                return
            }

            let screenSnapshot = OnlineWatchHistoryScreenSnapshot(snapshot, appendingTo: existingSnapshot)
            currentPage = screenSnapshot.page
            hasNextPage = screenSnapshot.hasNext
            state = .loaded(screenSnapshot)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, generation == requestGeneration else { return }
            CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
            if let existingSnapshot {
                state = .loaded(existingSnapshot.withLoadMoreError(ErrorMessage.userFriendly(error)))
            } else {
                state = .failed(ErrorMessage.userFriendly(error))
            }
        }
    }
}

struct OnlineWatchHistoryScreenSnapshot {
    let page: Int32
    let hasNext: Bool
    let csrfToken: String?
    let videos: [OnlineWatchHistoryRow]
    let loadMoreError: String?

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

        videos = OnlineWatchHistoryScreenSnapshot.merging(existingSnapshot?.videos ?? [], with: newVideos)
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
        let removed = Set(videoCodes)
        return OnlineWatchHistoryScreenSnapshot(
            page: page,
            hasNext: hasNext,
            csrfToken: csrfToken,
            videos: videos.filter { !removed.contains($0.videoCode) },
            loadMoreError: loadMoreError
        )
    }

    private static func merging(_ existing: [OnlineWatchHistoryRow], with newRows: [OnlineWatchHistoryRow]) -> [OnlineWatchHistoryRow] {
        var seenIDs = Set(existing.map(\.id))
        var merged = existing
        for row in newRows where seenIDs.insert(row.id).inserted {
            merged.append(row)
        }
        return merged
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
            .joined(separator: " / ")
    }
}
