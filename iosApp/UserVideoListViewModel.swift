import Foundation
import Han1meShared

@MainActor
final class UserVideoListViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(UserVideoListScreenSnapshot)
        case loadingMore(UserVideoListScreenSnapshot)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published var actionErrorMessage: String?

    private let loadPage: (Int32) async throws -> UserVideoListSnapshot
    private let removeVideo: ((String) async throws -> UserVideoListMutationSnapshot)?
    private var currentPage: Int32 = 0
    private var hasNextPage = false

    init(feature: UserVideoListFeature) {
        self.loadPage = { page in
            try await feature.load(page: page)
        }
        self.removeVideo = { videoCode in
            try await feature.remove(videoCode: videoCode)
        }
    }

    init(feature: PlaylistVideoListFeature) {
        self.loadPage = { page in
            try await feature.load(page: page)
        }
        self.removeVideo = nil
    }

    var canRemoveItems: Bool {
        removeVideo != nil
    }

    func load() {
        guard !isLoading else {
            return
        }
        currentPage = 0
        hasNextPage = false
        state = .loading
        Task {
            await load(page: 1, appendingTo: nil)
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
        state = .loadingMore(snapshot)
        Task {
            await load(page: nextPage, appendingTo: snapshot)
        }
    }

    func delete(at offsets: IndexSet) {
        guard let removeVideo else {
            return
        }
        guard case .loaded(let snapshot) = state else {
            return
        }

        let videoCodes = offsets.map { snapshot.videos[$0].videoCode }
        state = .loaded(snapshot.removing(videoCodes: videoCodes))
        actionErrorMessage = nil

        Task {
            for videoCode in videoCodes {
                do {
                    _ = try await removeVideo(videoCode)
                } catch {
                    actionErrorMessage = ErrorMessage.userFriendly(error)
                    await load(page: 1, appendingTo: nil)
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

    private func load(page: Int32, appendingTo existingSnapshot: UserVideoListScreenSnapshot?) async {
        do {
            let snapshot = try await loadPage(page)
            let screenSnapshot = UserVideoListScreenSnapshot(snapshot, appendingTo: existingSnapshot)
            currentPage = screenSnapshot.page
            hasNextPage = screenSnapshot.hasNext
            state = .loaded(screenSnapshot)
        } catch {
            if let existingSnapshot {
                state = .loaded(existingSnapshot.withLoadMoreError(ErrorMessage.userFriendly(error)))
            } else {
                state = .failed(ErrorMessage.userFriendly(error))
            }
        }
    }
}

struct UserVideoListScreenSnapshot {
    let page: Int32
    let hasNext: Bool
    let listDescription: String?
    let videos: [UserVideoListRow]
    let loadMoreError: String?

    init(_ snapshot: UserVideoListSnapshot, appendingTo existingSnapshot: UserVideoListScreenSnapshot? = nil) {
        page = snapshot.page
        hasNext = snapshot.hasNext
        listDescription = snapshot.listDescription ?? existingSnapshot?.listDescription

        let videoCount = Int(snapshot.videoCount())
        let newVideos: [UserVideoListRow] = (0..<videoCount).compactMap { index in
            guard let video = snapshot.videoAt(index: Int32(index)) else {
                return nil
            }
            return UserVideoListRow(
                videoCode: video.videoCode,
                title: video.title,
                coverUrl: video.coverUrl,
                duration: video.duration,
                views: video.views,
                artist: video.artist,
                uploadTime: video.uploadTime
            )
        }

        videos = UserVideoListScreenSnapshot.merging(existingSnapshot?.videos ?? [], with: newVideos)
        loadMoreError = nil
    }

    private init(
        page: Int32,
        hasNext: Bool,
        listDescription: String?,
        videos: [UserVideoListRow],
        loadMoreError: String?
    ) {
        self.page = page
        self.hasNext = hasNext
        self.listDescription = listDescription
        self.videos = videos
        self.loadMoreError = loadMoreError
    }

    func withLoadMoreError(_ message: String) -> UserVideoListScreenSnapshot {
        UserVideoListScreenSnapshot(
            page: page,
            hasNext: hasNext,
            listDescription: listDescription,
            videos: videos,
            loadMoreError: message
        )
    }

    func removing(videoCodes: [String]) -> UserVideoListScreenSnapshot {
        let removed = Set(videoCodes)
        return UserVideoListScreenSnapshot(
            page: page,
            hasNext: hasNext,
            listDescription: listDescription,
            videos: videos.filter { !removed.contains($0.videoCode) },
            loadMoreError: loadMoreError
        )
    }

    private static func merging(_ existing: [UserVideoListRow], with newRows: [UserVideoListRow]) -> [UserVideoListRow] {
        var seenIDs = Set(existing.map(\.id))
        var merged = existing
        for row in newRows where seenIDs.insert(row.id).inserted {
            merged.append(row)
        }
        return merged
    }
}

struct UserVideoListRow: Identifiable {
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
