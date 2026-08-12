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
    private var loadingVideoCode: String?
    private var loadTask: Task<Void, Never>?
    private var lastSavedPlaybackMillis: Int64?

    init(videoFeature: VideoFeature) {
        self.videoFeature = videoFeature
    }

    deinit {
        loadTask?.cancel()
    }

    func loadIfNeeded(videoCode: String) {
        if loadedVideoCode == videoCode, case .loaded = state { return }
        if loadingVideoCode == videoCode, case .loading = state { return }
        load(videoCode: videoCode)
    }

    func load(videoCode: String) {
        loadTask?.cancel()
        loadedVideoCode = nil
        lastSavedPlaybackMillis = nil
        loadingVideoCode = videoCode
        state = .loading
        loadTask = Task { [weak self] in
            await self?.loadVideo(videoCode: videoCode)
        }
    }

    func refresh(videoCode: String) async {
        loadTask?.cancel()
        loadedVideoCode = nil
        lastSavedPlaybackMillis = nil
        loadingVideoCode = videoCode
        await loadVideo(videoCode: videoCode)
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

    func recordPlaybackPosition(seconds: TimeInterval) {
        guard case .loaded(let snapshot) = state else { return }
        let millis = Int64(max(0, seconds) * 1000)
        lastSavedPlaybackMillis = millis
        videoFeature.recordPlaybackPosition(
            videoCode: snapshot.videoCode,
            playbackPositionMillis: millis
        )
    }

    func isActionRunning(_ id: String) -> Bool {
        runningActionIDs.contains(id)
    }

    func showActionMessage(_ message: String, kind: VideoActionMessage.Kind = .info) {
        actionMessage = VideoActionMessage(message: message, kind: kind)
    }

    func toggleFavorite(snapshot: VideoDetailScreenSnapshot) {
        guard snapshot.currentUserId != nil else {
            showActionMessage(String(localized: "video.action.login_required"))
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
            let key = nextValue ? "video.action.favorite.added" : "video.action.favorite.removed"
            let symbol = nextValue ? "heart.fill" : "heart.slash.fill"
            self.showActionMessage(NSLocalizedString(key, comment: ""), kind: .success(systemImage: symbol))
        }
    }

    func toggleWatchLater(snapshot: VideoDetailScreenSnapshot) {
        guard snapshot.currentUserId != nil else {
            showActionMessage(String(localized: "video.action.login_required"))
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
            let key = nextValue ? "video.action.watch_later.added" : "video.action.watch_later.removed"
            let symbol = nextValue ? "clock.fill" : "clock.badge.xmark.fill"
            self.showActionMessage(NSLocalizedString(key, comment: ""), kind: .success(systemImage: symbol))
        }
    }

    func setMyListItem(snapshot: VideoDetailScreenSnapshot, item: VideoMyListRow, isSelected: Bool) {
        guard snapshot.currentUserId != nil else {
            showActionMessage(String(localized: "video.action.login_required"))
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
            let key = isSelected ? "video.action.playlist.added" : "video.action.playlist.removed"
            let symbol = isSelected ? "text.badge.checkmark" : "text.badge.minus"
            self.showActionMessage(NSLocalizedString(key, comment: ""), kind: .success(systemImage: symbol))
        }
    }

    func toggleArtistSubscription(snapshot: VideoDetailScreenSnapshot) {
        guard let artist = snapshot.artist,
              let userId = artist.subscriptionUserId,
              let artistId = artist.subscriptionArtistId else {
            showActionMessage(String(localized: "video.action.subscription.login_required"))
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
            let key = nextValue ? "video.action.subscription.added" : "video.action.subscription.removed"
            let symbol = nextValue ? "person.badge.plus.fill" : "person.badge.minus.fill"
            self.showActionMessage(NSLocalizedString(key, comment: ""), kind: .success(systemImage: symbol))
        }
    }

    private func runAction(id: String, operation: @escaping () async throws -> Void) {
        guard !runningActionIDs.contains(id) else { return }
        runningActionIDs.insert(id)
        Task { [weak self] in
            guard let self else { return }
            defer { runningActionIDs.remove(id) }
            do {
                try await operation()
                AppLogger.log("action ok id=\(id)")
            } catch {
                AppLogger.log("action failed id=\(id): \(ErrorMessage.userFriendly(error))")
                CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
                actionMessage = VideoActionMessage(message: ErrorMessage.userFriendly(error), kind: .failure)
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
    let kind: Kind

    enum Kind {
        case success(systemImage: String?)
        case failure
        case info
    }

    var systemImage: String {
        switch kind {
        case .success(let symbol): return symbol ?? "checkmark"
        case .failure: return "xmark"
        case .info: return "info.circle.fill"
        }
    }
}
