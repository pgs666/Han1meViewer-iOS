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
    @Published var actionMessage: VideoActionMessage?
    @Published private(set) var runningActionIDs: Set<String> = []

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

    func isActionRunning(_ id: String) -> Bool {
        runningActionIDs.contains(id)
    }

    func showActionMessage(_ message: String) {
        actionMessage = VideoActionMessage(message: message)
    }

    func toggleFavorite(snapshot: VideoDetailScreenSnapshot) {
        runAction(id: "favorite") {
            let nextValue = !snapshot.isFav
            try await self.videoFeature.setFavorite(
                videoCode: snapshot.videoCode,
                currentUserId: snapshot.currentUserId,
                csrfToken: snapshot.csrfToken,
                isFavorite: nextValue
            )
            self.updateLoadedSnapshot { $0.updatingFavorite(isFavorite: nextValue) }
            self.showActionMessage(nextValue ? "Added to favorites" : "Removed from favorites")
        }
    }

    func toggleWatchLater(snapshot: VideoDetailScreenSnapshot) {
        runAction(id: "watchLater") {
            let nextValue = !snapshot.isWatchLater
            try await self.videoFeature.setMyListItem(
                listCode: "save",
                videoCode: snapshot.videoCode,
                csrfToken: snapshot.csrfToken,
                isSelected: nextValue
            )
            self.updateLoadedSnapshot { $0.updatingWatchLater(isSelected: nextValue) }
            self.showActionMessage(nextValue ? "Added to watch later" : "Removed from watch later")
        }
    }

    func setMyListItem(snapshot: VideoDetailScreenSnapshot, item: VideoMyListRow, isSelected: Bool) {
        runAction(id: "myList-\(item.code)") {
            try await self.videoFeature.setMyListItem(
                listCode: item.code,
                videoCode: snapshot.videoCode,
                csrfToken: snapshot.csrfToken,
                isSelected: isSelected
            )
            self.updateLoadedSnapshot { $0.updatingMyListItem(code: item.code, isSelected: isSelected) }
            self.showActionMessage(isSelected ? "Added to playlist" : "Removed from playlist")
        }
    }

    private func runAction(id: String, operation: @escaping () async throws -> Void) {
        guard !runningActionIDs.contains(id) else { return }
        runningActionIDs.insert(id)
        Task {
            defer {
                runningActionIDs.remove(id)
            }

            do {
                try await operation()
            } catch {
                CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
                actionMessage = VideoActionMessage(message: ErrorMessage.userFriendly(error))
            }
        }
    }

    private func updateLoadedSnapshot(_ transform: (VideoDetailScreenSnapshot) -> VideoDetailScreenSnapshot) {
        guard case .loaded(let snapshot) = state else { return }
        state = .loaded(transform(snapshot))
    }
}

struct VideoActionMessage: Identifiable {
    let id = UUID()
    let message: String
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
    let csrfToken: String?
    let currentUserId: String?
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
        csrfToken = snapshot.csrfToken
        currentUserId = snapshot.currentUserId
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

    private init(
        videoCode: String,
        title: String,
        chineseTitle: String?,
        videoDescription: String?,
        views: String?,
        tagSummary: String,
        sourceCount: Int32,
        defaultSourceLabel: String?,
        defaultSourceUrl: String?,
        uploadDate: String?,
        coverUrl: String?,
        artist: VideoArtistRow?,
        favTimes: Int?,
        isFav: Bool,
        csrfToken: String?,
        currentUserId: String?,
        isWatchLater: Bool,
        originalComic: String?,
        tags: [String],
        playbackSources: [VideoPlaybackSourceRow],
        playlistName: String?,
        playlistVideos: [VideoRelatedRow],
        myListItems: [VideoMyListRow],
        relatedVideos: [VideoRelatedRow]
    ) {
        self.videoCode = videoCode
        self.title = title
        self.chineseTitle = chineseTitle
        self.videoDescription = videoDescription
        self.views = views
        self.tagSummary = tagSummary
        self.sourceCount = sourceCount
        self.defaultSourceLabel = defaultSourceLabel
        self.defaultSourceUrl = defaultSourceUrl
        self.uploadDate = uploadDate
        self.coverUrl = coverUrl
        self.artist = artist
        self.favTimes = favTimes
        self.isFav = isFav
        self.csrfToken = csrfToken
        self.currentUserId = currentUserId
        self.isWatchLater = isWatchLater
        self.originalComic = originalComic
        self.tags = tags
        self.playbackSources = playbackSources
        self.playlistName = playlistName
        self.playlistVideos = playlistVideos
        self.myListItems = myListItems
        self.relatedVideos = relatedVideos
    }

    func updatingFavorite(isFavorite: Bool) -> VideoDetailScreenSnapshot {
        let nextFavTimes: Int?
        if let favTimes {
            nextFavTimes = max(0, favTimes + (isFavorite ? 1 : -1))
        } else {
            nextFavTimes = nil
        }

        return copy(favTimes: nextFavTimes, isFav: isFavorite)
    }

    func updatingWatchLater(isSelected: Bool) -> VideoDetailScreenSnapshot {
        copy(isWatchLater: isSelected)
    }

    func updatingMyListItem(code: String, isSelected: Bool) -> VideoDetailScreenSnapshot {
        copy(
            myListItems: myListItems.map { item in
                item.code == code ? item.updatingSelection(isSelected) : item
            }
        )
    }

    private func copy(
        favTimes: Int? = nil,
        isFav: Bool? = nil,
        isWatchLater: Bool? = nil,
        myListItems: [VideoMyListRow]? = nil
    ) -> VideoDetailScreenSnapshot {
        VideoDetailScreenSnapshot(
            videoCode: videoCode,
            title: title,
            chineseTitle: chineseTitle,
            videoDescription: videoDescription,
            views: views,
            tagSummary: tagSummary,
            sourceCount: sourceCount,
            defaultSourceLabel: defaultSourceLabel,
            defaultSourceUrl: defaultSourceUrl,
            uploadDate: uploadDate,
            coverUrl: coverUrl,
            artist: artist,
            favTimes: favTimes ?? self.favTimes,
            isFav: isFav ?? self.isFav,
            csrfToken: csrfToken,
            currentUserId: currentUserId,
            isWatchLater: isWatchLater ?? self.isWatchLater,
            originalComic: originalComic,
            tags: tags,
            playbackSources: playbackSources,
            playlistName: playlistName,
            playlistVideos: playlistVideos,
            myListItems: myListItems ?? self.myListItems,
            relatedVideos: relatedVideos
        )
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

    func updatingSelection(_ isSelected: Bool) -> VideoMyListRow {
        VideoMyListRow(code: code, title: title, isSelected: isSelected)
    }
}
