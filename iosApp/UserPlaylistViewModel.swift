import Foundation
import Han1meShared

@MainActor
final class UserPlaylistViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(UserPlaylistScreenSnapshot)
        case loadingMore(UserPlaylistScreenSnapshot)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let feature: UserPlaylistFeature
    private var currentPage: Int32 = 0
    private var hasNextPage = false
    private var loadTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var requestGeneration = 0

    init(feature: UserPlaylistFeature) {
        self.feature = feature
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
            await self?.load(page: 1, appendingTo: nil, generation: generation)
        }
    }

    func loadMoreIfNeeded(currentPlaylistID: String?) {
        guard hasNextPage, !isLoading else {
            return
        }
        guard case .loaded(let snapshot) = state else {
            return
        }
        guard snapshot.playlists.last?.id == currentPlaylistID else {
            return
        }

        let nextPage = currentPage + 1
        let generation = requestGeneration
        state = .loadingMore(snapshot)
        loadMoreTask = Task { [weak self] in
            await self?.load(page: nextPage, appendingTo: snapshot, generation: generation)
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

    private func load(page: Int32, appendingTo existingSnapshot: UserPlaylistScreenSnapshot?, generation: Int) async {
        do {
            let snapshot = try await feature.load(page: page)
            guard !Task.isCancelled, generation == requestGeneration else { return }
            if snapshot.authRequired {
                state = .failed(String(localized: "playlist.auth.required"))
                currentPage = 0
                hasNextPage = false
                return
            }
            let screenSnapshot = UserPlaylistScreenSnapshot(snapshot, appendingTo: existingSnapshot)
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

struct UserPlaylistScreenSnapshot {
    let page: Int32
    let hasNext: Bool
    let playlists: [UserPlaylistRow]
    let loadMoreError: String?

    init(_ snapshot: UserPlaylistSnapshot, appendingTo existingSnapshot: UserPlaylistScreenSnapshot? = nil) {
        page = snapshot.page
        hasNext = snapshot.hasNext

        let playlistCount = Int(snapshot.playlistCount())
        let newPlaylists: [UserPlaylistRow] = (0..<playlistCount).compactMap { index in
            guard let playlist = snapshot.playlistAt(index: Int32(index)) else {
                return nil
            }
            return UserPlaylistRow(
                listCode: playlist.listCode,
                title: playlist.title,
                total: playlist.total,
                coverUrl: playlist.coverUrl
            )
        }

        playlists = UserPlaylistScreenSnapshot.merging(existingSnapshot?.playlists ?? [], with: newPlaylists)
        loadMoreError = nil
    }

    private init(
        page: Int32,
        hasNext: Bool,
        playlists: [UserPlaylistRow],
        loadMoreError: String?
    ) {
        self.page = page
        self.hasNext = hasNext
        self.playlists = playlists
        self.loadMoreError = loadMoreError
    }

    func withLoadMoreError(_ message: String) -> UserPlaylistScreenSnapshot {
        UserPlaylistScreenSnapshot(
            page: page,
            hasNext: hasNext,
            playlists: playlists,
            loadMoreError: message
        )
    }

    private static func merging(_ existing: [UserPlaylistRow], with newRows: [UserPlaylistRow]) -> [UserPlaylistRow] {
        var seenIDs = Set(existing.map(\.id))
        var merged = existing
        for row in newRows where seenIDs.insert(row.id).inserted {
            merged.append(row)
        }
        return merged
    }
}

struct UserPlaylistRow: Identifiable {
    let listCode: String
    let title: String
    let total: Int32
    let coverUrl: String?

    var id: String { listCode }
}
