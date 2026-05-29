import AVKit
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
    @Published private(set) var player: AVPlayer?
    @Published var playerError: String?
    @Published var selectedPlaybackSourceID = ""
    @Published private(set) var selectedPlaybackRate: Float = 1.0

    let playbackRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    private let videoFeature: VideoFeature
    private var loadedVideoCode: String?
    private var loadingVideoCode: String?
    private var loadTask: Task<Void, Never>?
    private var currentPlayerVideoCode: String?
    private var currentPlayerSourceID: String?
    private var didApplyRestoredPlaybackPosition = false
    private var playerItemStatusObservation: NSKeyValueObservation?
    private var failedToPlayObserver: NSObjectProtocol?
    /// 已写入 db 的最近一次播放进度（毫秒）。`recordPlaybackPosition(seconds:)` 用它做
    /// 大幅倒退保护，避免 KSPlayer 启动期 onPlay(0~少秒) 把已保存的 resume position
    /// 抹掉。每次 `load(videoCode:)` 时 reset；snapshot loaded 后用 db 已存值初始化。
    private var lastSavedPlaybackMillis: Int64?

    init(videoFeature: VideoFeature) {
        self.videoFeature = videoFeature
    }

    deinit {
        loadTask?.cancel()
    }

    func loadIfNeeded(videoCode: String) {
        if loadedVideoCode == videoCode, case .loaded = state {
            return
        }
        if loadingVideoCode == videoCode, case .loading = state {
            return
        }
        load(videoCode: videoCode)
    }

    func load(videoCode: String) {
        loadTask?.cancel()
        persistPlaybackPosition()
        releasePlayer()
        loadedVideoCode = nil
        lastSavedPlaybackMillis = nil
        loadingVideoCode = videoCode
        state = .loading
        loadTask = Task { [weak self] in
            await self?.loadVideo(videoCode: videoCode)
        }
    }

    private func loadVideo(videoCode: String) async {
        defer {
            if loadingVideoCode == videoCode {
                loadingVideoCode = nil
            }
        }

        do {
            let snapshot = try await CloudflareRetryCenter.retryOnCloudflare {
                try await self.videoFeature.loadVideo(videoCode: videoCode)
            }
            guard !Task.isCancelled, loadingVideoCode == videoCode else { return }
            loadedVideoCode = videoCode
            // Initialize the regression baseline to the value already in db so
            // early-stage onPlay (current=0..few seconds) cannot clobber it.
            lastSavedPlaybackMillis = snapshot.playbackPositionMillis
            state = .loaded(VideoDetailScreenSnapshot(snapshot))
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, loadingVideoCode == videoCode else { return }
            AppLogger.log("video load failed v=\(videoCode): \(ErrorMessage.userFriendly(error))")
            state = .failed(ErrorMessage.userFriendly(error))
        }
    }

    func preparePlayer(snapshot: VideoDetailScreenSnapshot) {
        let defaultSource = snapshot.playbackSources.first { $0.isDefault } ?? snapshot.playbackSources.first
        let source = snapshot.playbackSources.first { $0.id == selectedPlaybackSourceID } ?? defaultSource
        guard let source else {
            releasePlayer()
            return
        }

        if selectedPlaybackSourceID != source.id {
            selectedPlaybackSourceID = source.id
        }
        configurePlayer(snapshot: snapshot, sourceID: source.id, preservePosition: false)
    }

    func selectPlaybackSource(snapshot: VideoDetailScreenSnapshot, sourceID: String) {
        selectedPlaybackSourceID = sourceID
        configurePlayer(snapshot: snapshot, sourceID: sourceID, preservePosition: true)
    }

    func selectPlaybackRate(_ rate: Float) {
        guard playbackRates.contains(rate) else { return }
        selectedPlaybackRate = rate
        applyPlaybackRateIfNeeded()
    }

    func persistPlaybackPosition() {
        guard let currentPlayerVideoCode,
              case .loaded(let snapshot) = state,
              snapshot.videoCode == currentPlayerVideoCode,
              let currentTimeMillis = player?.currentTime().positiveMillis else {
            return
        }

        videoFeature.recordPlaybackPosition(
            videoCode: snapshot.videoCode,
            playbackPositionMillis: currentTimeMillis
        )
    }

    /// 由外部播放器（如 KSPlayer）回调当前播放时间时使用，
    /// 与 `persistPlaybackPosition()` 等价但不依赖 `self.player`。
    ///
    /// **No regression guard here on purpose.** Earlier we kept a 30s
    /// regression cap to defend against KSPlayer firing early-stage onPlay
    /// ticks (current=0..few seconds) before its startPlayTime seek had
    /// landed. That cap also blocked legitimate user-seek-backwards (e.g.
    /// jumping from 2:00 back to 1:00), so the saved resume position
    /// behaved like "highest point reached" instead of "last known
    /// position". The startup-phantom problem is now solved upstream in
    /// `KSPlayerView.onPlay` (hasReachedStartPlayTime gate), so this layer
    /// can faithfully mirror the player's current time and the user's
    /// rewind seeks survive across re-entry.
    func recordPlaybackPosition(seconds: TimeInterval) {
        guard case .loaded(let snapshot) = state else { return }
        let clampedSeconds = max(0, seconds)
        let millis = Int64(clampedSeconds * 1000)
        lastSavedPlaybackMillis = millis
        videoFeature.recordPlaybackPosition(
            videoCode: snapshot.videoCode,
            playbackPositionMillis: millis
        )
    }

    func pausePlayer() {
        persistPlaybackPosition()
        player?.pause()
    }

    func isActionRunning(_ id: String) -> Bool {
        runningActionIDs.contains(id)
    }

    func showActionMessage(_ message: String, kind: VideoActionMessage.Kind = .info) {
        actionMessage = VideoActionMessage(message: message, kind: kind)
    }

    func toggleFavorite(snapshot: VideoDetailScreenSnapshot) {
        guard snapshot.currentUserId != nil else {
            showActionMessage(String(localized: "video.action.login_required"), kind: .info)
            return
        }
        runAction(id: "favorite") {
            let nextValue = !snapshot.isFav
            try await self.videoFeature.setFavorite(
                videoCode: snapshot.videoCode,
                currentUserId: snapshot.currentUserId,
                csrfToken: snapshot.csrfToken,
                isFavorite: nextValue
            )
            self.updateLoadedSnapshot { $0.updatingFavorite(isFavorite: nextValue) }
            let messageKey = nextValue ? "video.action.favorite.added" : "video.action.favorite.removed"
            // Heart for added, slashed-heart for removed — Apple Music
            // uses the action-specific glyph (not a plain checkmark) so
            // the HUD reads as "this is what you just did" at a glance.
            let symbol = nextValue ? "heart.fill" : "heart.slash.fill"
            self.showActionMessage(NSLocalizedString(messageKey, comment: ""), kind: .success(systemImage: symbol))
        }
    }

    func toggleWatchLater(snapshot: VideoDetailScreenSnapshot) {
        guard snapshot.currentUserId != nil else {
            showActionMessage(String(localized: "video.action.login_required"), kind: .info)
            return
        }
        runAction(id: "watchLater") {
            let nextValue = !snapshot.isWatchLater
            try await self.videoFeature.setMyListItem(
                listCode: "save",
                videoCode: snapshot.videoCode,
                csrfToken: snapshot.csrfToken,
                isSelected: nextValue
            )
            self.updateLoadedSnapshot { $0.updatingWatchLater(isSelected: nextValue) }
            let messageKey = nextValue ? "video.action.watch_later.added" : "video.action.watch_later.removed"
            let symbol = nextValue ? "clock.fill" : "clock.badge.xmark.fill"
            self.showActionMessage(NSLocalizedString(messageKey, comment: ""), kind: .success(systemImage: symbol))
        }
    }

    func setMyListItem(snapshot: VideoDetailScreenSnapshot, item: VideoMyListRow, isSelected: Bool) {
        guard snapshot.currentUserId != nil else {
            showActionMessage(String(localized: "video.action.login_required"), kind: .info)
            return
        }
        runAction(id: "myList-\(item.code)") {
            try await self.videoFeature.setMyListItem(
                listCode: item.code,
                videoCode: snapshot.videoCode,
                csrfToken: snapshot.csrfToken,
                isSelected: isSelected
            )
            self.updateLoadedSnapshot { $0.updatingMyListItem(code: item.code, isSelected: isSelected) }
            let messageKey = isSelected ? "video.action.playlist.added" : "video.action.playlist.removed"
            let symbol = isSelected ? "text.badge.checkmark" : "text.badge.minus"
            self.showActionMessage(NSLocalizedString(messageKey, comment: ""), kind: .success(systemImage: symbol))
        }
    }

    func toggleArtistSubscription(snapshot: VideoDetailScreenSnapshot) {
        guard let artist = snapshot.artist,
              let userId = artist.subscriptionUserId,
              let artistId = artist.subscriptionArtistId else {
            showActionMessage(String(localized: "video.action.subscription.login_required"), kind: .info)
            return
        }

        runAction(id: "artistSubscription") {
            let nextValue = !artist.isSubscribed
            try await self.videoFeature.setArtistSubscription(
                userId: userId,
                artistId: artistId,
                csrfToken: snapshot.csrfToken,
                isSubscribed: nextValue
            )
            self.updateLoadedSnapshot { $0.updatingArtistSubscription(isSubscribed: nextValue) }
            let messageKey = nextValue ? "video.action.subscription.added" : "video.action.subscription.removed"
            let symbol = nextValue ? "person.badge.plus.fill" : "person.badge.minus.fill"
            self.showActionMessage(NSLocalizedString(messageKey, comment: ""), kind: .success(systemImage: symbol))
        }
    }

    private func runAction(id: String, operation: @escaping () async throws -> Void) {
        guard !runningActionIDs.contains(id) else { return }
        runningActionIDs.insert(id)
        Task { [weak self] in
            guard let self else { return }
            defer {
                runningActionIDs.remove(id)
            }

            do {
                try await operation()
                AppLogger.log("action ok id=\(id)")
            } catch {
                AppLogger.log("action failed id=\(id): \(ErrorMessage.userFriendly(error))")
                CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
                actionMessage = VideoActionMessage(
                    message: ErrorMessage.userFriendly(error),
                    kind: .failure
                )
            }
        }
    }

    private func updateLoadedSnapshot(_ transform: (VideoDetailScreenSnapshot) -> VideoDetailScreenSnapshot) {
        guard case .loaded(let snapshot) = state else { return }
        state = .loaded(transform(snapshot))
    }

    private func configurePlayer(
        snapshot: VideoDetailScreenSnapshot,
        sourceID: String,
        preservePosition: Bool
    ) {
        guard let source = snapshot.playbackSources.first(where: { $0.id == sourceID }) ?? snapshot.playbackSources.first,
              let url = URL(string: source.url) else {
            releasePlayer()
            return
        }

        if currentPlayerVideoCode == snapshot.videoCode,
           currentPlayerSourceID == source.id,
           player != nil {
            applyPlaybackRateIfNeeded()
            return
        }

        let previousPlayer = player
        let previousTime = preservePosition ? previousPlayer?.currentTime() : nil
        let shouldResume = previousPlayer?.timeControlStatus == .playing
        previousPlayer?.pause()

        let nextPlayer = AVPlayer(url: url)
        player = nextPlayer
        playerError = nil
        currentPlayerVideoCode = snapshot.videoCode
        currentPlayerSourceID = source.id
        observePlayerItemErrors(nextPlayer)

        let restoredTime = !preservePosition && !didApplyRestoredPlaybackPosition
            ? CMTime(positiveMilliseconds: snapshot.playbackPositionMillis)
            : nil
        let seekTime = previousTime ?? restoredTime
        didApplyRestoredPlaybackPosition = true

        if let seekTime {
            nextPlayer.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self, weak nextPlayer] _ in
                Task { @MainActor in
                    guard let self,
                          let nextPlayer,
                          self.player === nextPlayer,
                          shouldResume else {
                        return
                    }
                    self.resume(nextPlayer)
                }
            }
        } else if shouldResume {
            resume(nextPlayer)
        }
    }

    private func resume(_ player: AVPlayer) {
        player.playImmediately(atRate: selectedPlaybackRate)
    }

    private func applyPlaybackRateIfNeeded() {
        guard let player,
              player.timeControlStatus == .playing || player.rate != 0 else {
            return
        }
        player.rate = selectedPlaybackRate
    }

    private func releasePlayer() {
        removePlayerObservers()
        player?.pause()
        player = nil
        playerError = nil
        selectedPlaybackSourceID = ""
        currentPlayerVideoCode = nil
        currentPlayerSourceID = nil
        didApplyRestoredPlaybackPosition = false
    }

    private func observePlayerItemErrors(_ player: AVPlayer) {
        removePlayerObservers()

        // Observe player item status changes for errors
        if let item = player.currentItem {
            playerItemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                guard item.status == .failed else { return }
                let message = item.error?.localizedDescription ?? "Video playback failed."
                Task { @MainActor [weak self] in
                    self?.playerError = message
                }
            }
        }

        // Observe failedToPlayToEndTime notification
        failedToPlayObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] notification in
            let message = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?
                .localizedDescription ?? "Video playback failed to reach end."
            self?.playerError = message
        }
    }

    private func removePlayerObservers() {
        playerItemStatusObservation?.invalidate()
        playerItemStatusObservation = nil
        if let observer = failedToPlayObserver {
            NotificationCenter.default.removeObserver(observer)
            failedToPlayObserver = nil
        }
    }
}

struct VideoActionMessage: Identifiable {
    let id = UUID()
    let message: String
    let kind: Kind

    /// HUD style. Carries the SF Symbol that should be shown above the
    /// message text. Designed to read as the Apple Music / system-volume
    /// HUD family — a single big centred glyph plus a one-or-two-line
    /// caption.
    enum Kind {
        /// Action succeeded. Caller picks an action-appropriate symbol
        /// (heart.fill on like, clock.fill on watch-later, etc.). Falls
        /// back to a checkmark if nil.
        case success(systemImage: String?)
        /// Generic failure HUD with an xmark.
        case failure
        /// Plain informational HUD (e.g. login required) — uses the
        /// info.circle.fill glyph; no success/failure colouring.
        case info
    }

    var systemImage: String {
        switch kind {
        case .success(let symbol): return symbol ?? "checkmark"
        case .failure:             return "xmark"
        case .info:                return "info.circle.fill"
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
    let csrfToken: String?
    let currentUserId: String?
    let isWatchLater: Bool
    let originalComic: String?
    let playbackPositionMillis: Int64
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
        playbackPositionMillis = snapshot.playbackPositionMillis

        if let name = snapshot.artistName, !name.isEmpty {
            artist = VideoArtistRow(
                name: name,
                avatarUrl: snapshot.artistAvatarUrl,
                genre: snapshot.artistGenre,
                isSubscribed: snapshot.isArtistSubscribed,
                subscriptionUserId: snapshot.artistSubscriptionUserId,
                subscriptionArtistId: snapshot.artistSubscriptionArtistId
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

    /// Builds a minimal snapshot for playing a locally-downloaded file
    /// through the same KSPlayerView the streaming detail page uses, so
    /// downloaded videos get the full custom player (gestures, fullscreen
    /// orientation auto-rotate, resume seek, etc.). Only the fields
    /// KSPlayerView actually reads are meaningful here: title, the single
    /// local playback source, and the resume position.
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
            chineseTitle: nil,
            videoDescription: nil,
            views: nil,
            tagSummary: "",
            sourceCount: 1,
            defaultSourceLabel: "本地",
            defaultSourceUrl: fileURL.absoluteString,
            uploadDate: nil,
            coverUrl: coverUrl,
            artist: nil,
            favTimes: nil,
            isFav: false,
            csrfToken: nil,
            currentUserId: nil,
            isWatchLater: false,
            originalComic: nil,
            playbackPositionMillis: playbackPositionMillis,
            tags: [],
            playbackSources: [
                VideoPlaybackSourceRow(
                    label: "本地",
                    url: fileURL.absoluteString,
                    contentType: "video/mp4",
                    isDefault: true
                )
            ],
            playlistName: nil,
            playlistVideos: [],
            myListItems: [],
            relatedVideos: []
        )
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
        playbackPositionMillis: Int64,
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
        self.playbackPositionMillis = playbackPositionMillis
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

    func updatingArtistSubscription(isSubscribed: Bool) -> VideoDetailScreenSnapshot {
        copy(artist: artist?.updatingSubscription(isSubscribed: isSubscribed))
    }

    private func copy(
        favTimes: Int? = nil,
        isFav: Bool? = nil,
        isWatchLater: Bool? = nil,
        artist: VideoArtistRow? = nil,
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
            artist: artist ?? self.artist,
            favTimes: favTimes ?? self.favTimes,
            isFav: isFav ?? self.isFav,
            csrfToken: csrfToken,
            currentUserId: currentUserId,
            isWatchLater: isWatchLater ?? self.isWatchLater,
            originalComic: originalComic,
            playbackPositionMillis: playbackPositionMillis,
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

private extension CMTime {
    init?(positiveMilliseconds milliseconds: Int64) {
        guard milliseconds > 0 else {
            return nil
        }
        self.init(seconds: Double(milliseconds) / 1000, preferredTimescale: 600)
    }

    var positiveMillis: Int64? {
        guard isValid, isNumeric, seconds.isFinite, seconds > 0 else {
            return nil
        }
        return Int64(seconds * 1000)
    }
}
