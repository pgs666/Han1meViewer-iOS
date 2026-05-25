import Foundation
import Han1meShared

@MainActor
final class FollowingViewModel: PaginatedViewModel<FollowingScreenSnapshot> {
    private let followingFeature: FollowingFeature

    init(followingFeature: FollowingFeature) {
        self.followingFeature = followingFeature
    }

    override func executeLoad(page: Int32, appendingTo existingSnapshot: FollowingScreenSnapshot?, generation: Int) async {
        do {
            let snapshot = try await followingFeature.loadFollowing(page: page)
            guard !Task.isCancelled, generation == currentGeneration else { return }
            if snapshot.authRequired {
                setFailed(String(localized: "following.auth.required"))
                return
            }
            let screenSnapshot = FollowingScreenSnapshot(snapshot, appendingTo: existingSnapshot)
            applyLoadResult(screenSnapshot)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, generation == currentGeneration else { return }
            applyLoadError(error, appendingTo: existingSnapshot)
        }
    }
}

struct FollowingScreenSnapshot: PaginatedSnapshot {
    let page: Int32
    let hasNext: Bool
    let artists: [FollowingArtistRow]
    let videos: [FollowingVideoRow]
    let loadMoreError: String?

    var lastItemID: String? { videos.last?.id }

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

        artists = mergeByIdentifiable(existingSnapshot?.artists ?? [], with: newArtists)
        videos = mergeByIdentifiable(existingSnapshot?.videos ?? [], with: newVideos)
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
            .joined(separator: " · ")
    }
}
