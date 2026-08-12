import Foundation
import Han1meShared

struct VideoArtistRow: Hashable {
    let name: String
    let avatarUrl: String?
    let genre: String?
    let isSubscribed: Bool
    let subscriptionUserId: String?
    let subscriptionArtistId: String?

    func updatingSubscription(isSubscribed: Bool) -> VideoArtistRow {
        VideoArtistRow(
            name: name,
            avatarUrl: avatarUrl,
            genre: genre,
            isSubscribed: isSubscribed,
            subscriptionUserId: subscriptionUserId,
            subscriptionArtistId: subscriptionArtistId
        )
    }
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
            .joined(separator: " · ")
    }
}

struct VideoMyListRow: Identifiable, Hashable {
    let code: String
    let title: String
    let isSelected: Bool

    var id: String { code }

    func updatingSelection(_ isSelected: Bool) -> VideoMyListRow {
        VideoMyListRow(code: code, title: title, isSelected: isSelected)
    }
}
