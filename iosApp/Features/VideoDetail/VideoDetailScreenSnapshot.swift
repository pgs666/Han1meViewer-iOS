import Foundation
import Han1meShared

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
    private(set) var artist: VideoArtistRow?
    private(set) var favTimes: Int?
    private(set) var isFav: Bool
    let csrfToken: String?
    let currentUserId: String?
    private(set) var isWatchLater: Bool
    let originalComic: String?
    let playbackPositionMillis: Int64
    let tags: [String]
    let playbackSources: [VideoPlaybackSourceRow]
    let playlistName: String?
    let relatedVideosUsePortraitCovers: Bool
    let playlistVideos: [VideoRelatedRow]
    private(set) var myListItems: [VideoMyListRow]
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
        csrfToken = snapshot.csrfToken
        currentUserId = snapshot.currentUserId
        isWatchLater = snapshot.isWatchLater
        originalComic = snapshot.originalComic
        playbackPositionMillis = snapshot.playbackPositionMillis
        artist = Self.makeArtist(snapshot)
        playbackSources = Self.makePlaybackSources(snapshot)
        tags = Self.makeTags(snapshot)
        playlistName = snapshot.playlistName
        relatedVideosUsePortraitCovers = snapshot.relatedVideosUsePortraitCovers
        playlistVideos = Self.makePlaylistVideos(snapshot)
        myListItems = Self.makeMyListItems(snapshot)
        relatedVideos = Self.makeRelatedVideos(snapshot)
    }

    static func local(
        videoCode: String,
        title: String,
        fileURL: URL,
        coverUrl: String?,
        playbackPositionMillis: Int64
    ) -> VideoDetailScreenSnapshot {
        VideoDetailScreenSnapshot(
            videoCode: videoCode,
            title: title,
            coverUrl: coverUrl,
            playbackPositionMillis: playbackPositionMillis,
            playbackSources: [
                VideoPlaybackSourceRow(
                    label: "本地",
                    url: fileURL.absoluteString,
                    contentType: "video/mp4",
                    isDefault: true
                )
            ]
        )
    }

    private init(
        videoCode: String,
        title: String,
        coverUrl: String?,
        playbackPositionMillis: Int64,
        playbackSources: [VideoPlaybackSourceRow]
    ) {
        self.videoCode = videoCode
        self.title = title
        self.chineseTitle = nil
        self.videoDescription = nil
        self.views = nil
        self.tagSummary = ""
        self.sourceCount = Int32(playbackSources.count)
        self.defaultSourceLabel = playbackSources.first?.label
        self.defaultSourceUrl = playbackSources.first?.url
        self.uploadDate = nil
        self.coverUrl = coverUrl
        self.artist = nil
        self.favTimes = nil
        self.isFav = false
        self.csrfToken = nil
        self.currentUserId = nil
        self.isWatchLater = false
        self.originalComic = nil
        self.playbackPositionMillis = playbackPositionMillis
        self.tags = []
        self.playbackSources = playbackSources
        self.playlistName = nil
        self.relatedVideosUsePortraitCovers = false
        self.playlistVideos = []
        self.myListItems = []
        self.relatedVideos = []
    }

    func updatingFavorite(isFavorite: Bool) -> VideoDetailScreenSnapshot {
        var updated = self
        updated.isFav = isFavorite
        if let favTimes {
            updated.favTimes = max(0, favTimes + (isFavorite ? 1 : -1))
        }
        return updated
    }

    func updatingWatchLater(isSelected: Bool) -> VideoDetailScreenSnapshot {
        var updated = self
        updated.isWatchLater = isSelected
        return updated
    }

    func updatingMyListItem(code: String, isSelected: Bool) -> VideoDetailScreenSnapshot {
        var updated = self
        updated.myListItems = myListItems.map { item in
            item.code == code ? item.updatingSelection(isSelected) : item
        }
        return updated
    }

    func updatingArtistSubscription(isSubscribed: Bool) -> VideoDetailScreenSnapshot {
        var updated = self
        updated.artist = artist?.updatingSubscription(isSubscribed: isSubscribed)
        return updated
    }

    private static func makeArtist(_ snapshot: VideoDetailSnapshot) -> VideoArtistRow? {
        guard let name = snapshot.artistName, !name.isEmpty else { return nil }
        return VideoArtistRow(
            name: name,
            avatarUrl: snapshot.artistAvatarUrl,
            genre: snapshot.artistGenre,
            isSubscribed: snapshot.isArtistSubscribed,
            subscriptionUserId: snapshot.artistSubscriptionUserId,
            subscriptionArtistId: snapshot.artistSubscriptionArtistId
        )
    }

    private static func makePlaybackSources(_ snapshot: VideoDetailSnapshot) -> [VideoPlaybackSourceRow] {
        (0..<Int(snapshot.playbackSourceCount())).compactMap { index in
            guard let source = snapshot.playbackSourceAt(index: Int32(index)) else { return nil }
            return VideoPlaybackSourceRow(
                label: source.label,
                url: source.url,
                contentType: source.contentType,
                isDefault: source.isDefault
            )
        }
    }

    private static func makeTags(_ snapshot: VideoDetailSnapshot) -> [String] {
        (0..<Int(snapshot.tagCount())).compactMap { snapshot.tagAt(index: Int32($0)) }
    }

    private static func makePlaylistVideos(_ snapshot: VideoDetailSnapshot) -> [VideoRelatedRow] {
        (0..<Int(snapshot.playlistVideoCount())).compactMap { index in
            snapshot.playlistVideoAt(index: Int32(index)).map(VideoRelatedRow.init)
        }
    }

    private static func makeMyListItems(_ snapshot: VideoDetailSnapshot) -> [VideoMyListRow] {
        (0..<Int(snapshot.myListItemCount())).compactMap { index in
            guard let item = snapshot.myListItemAt(index: Int32(index)) else { return nil }
            return VideoMyListRow(code: item.code, title: item.title, isSelected: item.isSelected)
        }
    }

    private static func makeRelatedVideos(_ snapshot: VideoDetailSnapshot) -> [VideoRelatedRow] {
        (0..<Int(snapshot.relatedVideoCount())).compactMap { index in
            snapshot.relatedVideoAt(index: Int32(index)).map(VideoRelatedRow.init)
        }
    }
}
