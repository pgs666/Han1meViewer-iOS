import Foundation
import Han1meShared

@MainActor
final class VideoDetailViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(VideoDetailScreenSnapshot)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let videoFeature: VideoFeature
    private var loadedVideoCode: String?

    init(videoFeature: VideoFeature) {
        self.videoFeature = videoFeature
    }

    func loadIfNeeded(videoCode: String) {
        if loadedVideoCode == videoCode {
            return
        }
        load(videoCode: videoCode)
    }

    func load(videoCode: String) {
        guard case .loading = state else {
            loadedVideoCode = videoCode
            state = .loading
            Task {
                await loadVideo(videoCode: videoCode)
            }
            return
        }
    }

    private func loadVideo(videoCode: String) async {
        do {
            let snapshot = try await videoFeature.loadVideo(videoCode: videoCode)
            state = .loaded(VideoDetailScreenSnapshot(snapshot))
        } catch {
            CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
            state = .failed(ErrorMessage.userFriendly(error))
        }
    }
}

struct VideoDetailScreenSnapshot {
    let videoCode: String
    let title: String
    let chineseTitle: String?
    let videoDescription: String?
    let views: String?
    let tagSummary: String
    let sourceCount: Int32
    let defaultSourceLabel: String?
    let defaultSourceUrl: String?
    let uploadDate: String?
    let coverUrl: String?
    let artist: VideoArtistRow?
    let favTimes: Int?
    let isFav: Bool
    let isWatchLater: Bool
    let originalComic: String?
    let tags: [String]
    let playbackSources: [VideoPlaybackSourceRow]
    let playlistName: String?
    let playlistVideos: [VideoRelatedRow]
    let myListItems: [VideoMyListRow]
    let relatedVideos: [VideoRelatedRow]

    init(_ snapshot: VideoDetailSnapshot) {
        videoCode = snapshot.videoCode
        title = snapshot.title
        chineseTitle = snapshot.chineseTitle
        videoDescription = snapshot.videoDescription
        views = snapshot.views
        tagSummary = snapshot.tagSummary
        sourceCount = snapshot.sourceCount
        defaultSourceLabel = snapshot.defaultSourceLabel
        defaultSourceUrl = snapshot.defaultSourceUrl
        uploadDate = snapshot.uploadDate
        coverUrl = snapshot.coverUrl
        favTimes = snapshot.favTimes?.intValue
        isFav = snapshot.isFav
        isWatchLater = snapshot.isWatchLater
        originalComic = snapshot.originalComic

        if let name = snapshot.artistName, !name.isEmpty {
            artist = VideoArtistRow(
                name: name,
                avatarUrl: snapshot.artistAvatarUrl,
                genre: snapshot.artistGenre,
                isSubscribed: snapshot.isArtistSubscribed
            )
        } else {
            artist = nil
        }

        let playbackSourceCount = Int(snapshot.playbackSourceCount())
        playbackSources = (0..<playbackSourceCount).compactMap { index in
            guard let source = snapshot.playbackSourceAt(index: Int32(index)) else {
                return nil
            }
            return VideoPlaybackSourceRow(
                label: source.label,
                url: source.url,
                contentType: source.contentType,
                isDefault: source.isDefault
            )
        }

        let tagCount = Int(snapshot.tagCount())
        tags = (0..<tagCount).compactMap { index in
            snapshot.tagAt(index: Int32(index))
        }

        let playlistCount = Int(snapshot.playlistVideoCount())
        playlistName = snapshot.playlistName
        playlistVideos = (0..<playlistCount).compactMap { index in
            guard let item = snapshot.playlistVideoAt(index: Int32(index)) else {
                return nil
            }
            return VideoRelatedRow(item)
        }

        let myListCount = Int(snapshot.myListItemCount())
        myListItems = (0..<myListCount).compactMap { index in
            guard let item = snapshot.myListItemAt(index: Int32(index)) else {
                return nil
            }
            return VideoMyListRow(
                code: item.code,
                title: item.title,
                isSelected: item.isSelected
            )
        }

        let count = Int(snapshot.relatedVideoCount())
        relatedVideos = (0..<count).compactMap { index in
            guard let item = snapshot.relatedVideoAt(index: Int32(index)) else {
                return nil
            }
            return VideoRelatedRow(item)
        }
    }
}

struct VideoArtistRow: Hashable {
    let name: String
    let avatarUrl: String?
    let genre: String?
    let isSubscribed: Bool
}

struct VideoPlaybackSourceRow: Identifiable, Hashable {
    let label: String
    let url: String
    let contentType: String?
    let isDefault: Bool

    var id: String { "\(label)-\(url)" }
}

struct VideoRelatedRow: Identifiable {
    let videoCode: String
    let title: String
    let coverUrl: String?
    let duration: String?
    let views: String?
    let artist: String?
    let uploadTime: String?
    let isPlaying: Bool

    var id: String { videoCode }

    init(_ item: VideoRelatedSnapshot) {
        videoCode = item.videoCode
        title = item.title
        coverUrl = item.coverUrl
        duration = item.duration
        views = item.views
        artist = item.artist
        uploadTime = item.uploadTime
        isPlaying = item.isPlaying
    }

    var metadata: String {
        [artist, uploadTime, duration, views]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " / ")
    }
}

struct VideoMyListRow: Identifiable, Hashable {
    let code: String
    let title: String
    let isSelected: Bool

    var id: String { code }
}
