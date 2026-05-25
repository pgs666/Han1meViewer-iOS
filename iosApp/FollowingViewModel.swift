import Foundation
import Han1meShared

@MainActor
final class FollowingViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(FollowingScreenSnapshot)
        case loadingMore(FollowingScreenSnapshot)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let followingFeature: FollowingFeature
    private var currentPage: Int32 = 0
    private var hasNextPage = false
    private var loadTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var requestGeneration = 0

    init(followingFeature: FollowingFeature) {
        self.followingFeature = followingFeature
    }

    deinit {
        loadTask?.cancel()
        loadMoreTask?.cancel()
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
            await self?.loadFollowing(page: 1, appendingTo: nil, generation: generation)
        }
    }

    func loadIfNeeded() {
        if case .idle = state {
            load()
        }
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
            await self?.loadFollowing(page: nextPage, appendingTo: snapshot, generation: generation)
        }
    }

    func cancelLoading() {
        loadTask?.cancel()
        loadMoreTask?.cancel()
        switch state {
        case .loading:
            state = .idle
        case .loadingMore(let snapshot):
            state = .loaded(snapshot)
        case .idle, .loaded, .failed:
            break
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

    private func loadFollowing(page: Int32, appendingTo existingSnapshot: FollowingScreenSnapshot?, generation: Int) async {
        do {
            let snapshot = try await followingFeature.loadFollowing(page: page)
            guard !Task.isCancelled, generation == requestGeneration else { return }
            if snapshot.authRequired {
                state = .failed(String(localized: "following.auth.required"))
                currentPage = 0
                hasNextPage = false
                return
            }
            let screenSnapshot = FollowingScreenSnapshot(snapshot, appendingTo: existingSnapshot)
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

struct FollowingScreenSnapshot {
    let page: Int32
    let hasNext: Bool
    let artists: [FollowingArtistRow]
    let videos: [FollowingVideoRow]
    let loadMoreError: String?

    init(_ snapshot: FollowingSnapshot, appendingTo existingSnapshot: FollowingScreenSnapshot? = nil) {
        page = snapshot.page
        hasNext = snapshot.hasNext

        let artistCount = Int(snapshot.artistCount())
        let newArtists: [FollowingArtistRow] = (0..<artistCount).compactMap { index in
            guard let artist = snapshot.artistAt(index: Int32(index)) else {
                return nil
            }
            return FollowingArtistRow(
                name: artist.name,
                avatarUrl: artist.avatarUrl
            )
        }

        let videoCount = Int(snapshot.videoCount())
        let newVideos: [FollowingVideoRow] = (0..<videoCount).compactMap { index in
            guard let video = snapshot.videoAt(index: Int32(index)) else {
                return nil
            }
            return FollowingVideoRow(
                videoCode: video.videoCode,
                title: video.title,
                coverUrl: video.coverUrl,
                duration: video.duration,
                views: video.views,
                reviews: video.reviews,
                artist: video.artist,
                uploadTime: video.uploadTime
            )
        }

        artists = FollowingScreenSnapshot.merging(existingSnapshot?.artists ?? [], with: newArtists)
        videos = FollowingScreenSnapshot.merging(existingSnapshot?.videos ?? [], with: newVideos)
        loadMoreError = nil
    }

    private init(
        page: Int32,
        hasNext: Bool,
        artists: [FollowingArtistRow],
        videos: [FollowingVideoRow],
        loadMoreError: String?
    ) {
        self.page = page
        self.hasNext = hasNext
        self.artists = artists
        self.videos = videos
        self.loadMoreError = loadMoreError
    }

    func withLoadMoreError(_ message: String) -> FollowingScreenSnapshot {
        FollowingScreenSnapshot(
            page: page,
            hasNext: hasNext,
            artists: artists,
            videos: videos,
            loadMoreError: message
        )
    }

    private static func merging<T: Identifiable>(_ existing: [T], with newRows: [T]) -> [T] where T.ID == String {
        var seenIDs = Set(existing.map(\.id))
        var merged = existing
        for row in newRows where seenIDs.insert(row.id).inserted {
            merged.append(row)
        }
        return merged
    }
}

struct FollowingArtistRow: Identifiable {
    let name: String
    let avatarUrl: String

    var id: String { "\(name)|\(avatarUrl)" }
}

struct FollowingVideoRow: Identifiable {
    let videoCode: String
    let title: String
    let coverUrl: String
    let duration: String?
    let views: String?
    let reviews: String?
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
