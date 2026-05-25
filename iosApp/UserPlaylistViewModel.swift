import Foundation
import Han1meShared

@MainActor
final class UserPlaylistViewModel: PaginatedViewModel<UserPlaylistScreenSnapshot> {
    private let feature: UserPlaylistFeature

    init(feature: UserPlaylistFeature) {
        self.feature = feature
    }

    override func executeLoad(page: Int32, appendingTo existingSnapshot: UserPlaylistScreenSnapshot?, generation: Int) async {
        do {
            let snapshot = try await feature.load(page: page)
            guard !Task.isCancelled, generation == currentGeneration else { return }
            if snapshot.authRequired {
                setFailed(String(localized: "playlist.auth.required"))
                return
            }
            let screenSnapshot = UserPlaylistScreenSnapshot(snapshot, appendingTo: existingSnapshot)
            applyLoadResult(screenSnapshot)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, generation == currentGeneration else { return }
            applyLoadError(error, appendingTo: existingSnapshot)
        }
    }
}

struct UserPlaylistScreenSnapshot: PaginatedSnapshot {
    let page: Int32
    let hasNext: Bool
    let playlists: [UserPlaylistRow]
    let loadMoreError: String?

    var lastItemID: String? { playlists.last?.id }

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

        playlists = mergeByIdentifiable(existingSnapshot?.playlists ?? [], with: newPlaylists)
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
}

struct UserPlaylistRow: Identifiable {
    let listCode: String
    let title: String
    let total: Int32
    let coverUrl: String?

    var id: String { listCode }
}
