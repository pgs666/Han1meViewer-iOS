import Foundation
import Han1meShared

/// Coordinates foreground URLSession transfers, persistence, and the
/// observable download list. File paths, cover loading, queue selection,
/// and expired-URL resolution live in dedicated collaborators.
///
/// Security note: downloads hit the site's public CDN URLs over HTTPS
/// using the same UA as the player; no auth tokens are transmitted to any
/// third party.
@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    /// Published task list, newest first. Reloaded from the store after
    /// every mutation; progress ticks patch entries in place.
    @Published private(set) var items: [DownloadUIItem] = []

    private var environment: SharedAppEnvironment?
    private var store: DownloadStore?
    private let coverLoader = DownloadCoverLoader()
    private let urlRefresher = DownloadURLRefresher()

    /// videoCode|quality -> in-flight task.
    private var activeTasks: [String: URLSessionDownloadTask] = [:]

    /// videoCode|quality -> number of CDN-link-expiry refetch attempts so
    /// far. Capped at `maxRefetchAttempts` to avoid an infinite
    /// fail→refetch→requeue→fail loop when a URL is permanently dead.
    private var refetchCounts: [String: Int] = [:]
    private let maxRefetchAttempts = 2

    /// Dedicated delegate so the URLSession callbacks (which arrive on a
    /// background queue) run on a `nonisolated` type that holds only a
    /// `weak` reference to this `@MainActor` manager. That makes it
    /// impossible — by construction, enforced at compile time — to touch
    /// the store / activeTasks / refetchCounts off the main actor: the
    /// delegate can only reach them through the manager's `@MainActor`
    /// handler methods below.
    private lazy var sessionDelegate = DownloadSessionDelegate(manager: self)

    private lazy var session: URLSession = {
        // FIX: previously URLSessionConfiguration.background(withIdentifier:),
        // but on iOS 16 (esp. sideloaded IPAs) the sandbox extension that
        // would let our app read nsurlsessiond's temp file in
        // didFinishDownloadingTo is not granted — copyItem fails with
        // NSCocoaErrorDomain#257 (read-no-permission) and the file is
        // lost. Switch to a foreground session: the download runs in our
        // own process and the temp file lands in this app's sandbox,
        // sidestepping the cross-sandbox dance entirely.
        // Trade-off: downloads pause when the app is suspended long
        // enough; resumes when the user re-opens it. Acceptable for the
        // interactive video-download use case.
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        return URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)
    }()

    private var maxConcurrent: Int {
        max(1, Int(environment?.preferences().maxConcurrentDownloads.get() ?? 2))
    }

    private override init() {
        super.init()
    }

    /// Wire up the shared environment. Foreground session tasks only live for
    /// the current process; persisted orphan rows are re-queued below.
    func configure(environment: SharedAppEnvironment) {
        guard self.environment == nil else { return }
        self.environment = environment
        self.store = environment.downloadStore()
        urlRefresher.configure(videoFeature: environment.videoFeature())
        reloadItems()
        restoreMissingCovers()
        reattachRunningTasks()
        // Anything left 'downloading' in the DB without a live task (app
        // was killed) is reset to queued so the scheduler picks it up.
        resetOrphanedDownloadingRows()
        startNextIfPossible()
    }

    // MARK: - Public actions

    func enqueue(videoCode: String, quality: String, title: String, coverUrl: String?, remoteUrl: String) {
        guard let store else { return }
        let localPath = DownloadFileStore.videoURL(videoCode: videoCode, quality: quality).path
        // Already present? Re-queue it (e.g. retry a failed one).
        let existing = store.find(videoCode: videoCode, quality: quality)
        let item = DownloadItem(
            videoCode: videoCode,
            quality: quality,
            title: title,
            coverUrl: coverUrl,
            remoteUrl: remoteUrl,
            localPath: localPath,
            totalBytes: existing?.totalBytes ?? 0,
            downloadedBytes: 0,
            state: Int32(DownloadState.queued.rawValue),
            addedAtEpochMillis: existing?.addedAtEpochMillis ?? Int64(Date().timeIntervalSince1970 * 1000),
            playbackPositionMillis: existing?.playbackPositionMillis ?? 0
        )
        store.upsert(item: item)
        scheduleCoverDownload(for: item)
        AppLogger.log("download enqueue v=\(videoCode) q=\(quality)")
        reloadItems()
        startNextIfPossible()
    }

    /// Persist the local-playback resume position for a downloaded item.
    func updatePlaybackPosition(videoCode: String, quality: String, positionMillis: Int64) {
        store?.updatePlaybackPosition(videoCode: videoCode, quality: quality, positionMillis: positionMillis)
    }

    /// Resume position (ms) previously saved for local playback, 0 if none.
    func playbackPosition(videoCode: String, quality: String) -> Int64 {
        store?.find(videoCode: videoCode, quality: quality)?.playbackPositionMillis ?? 0
    }

    func pause(_ item: DownloadUIItem) {
        guard let task = activeTasks[item.id] else {
            setState(item, .paused)
            return
        }
        task.cancel(byProducingResumeData: { [weak self] data in
            guard let self else { return }
            if let data {
                DownloadFileStore.saveResumeData(data, videoCode: item.videoCode, quality: item.quality)
            }
            Task { @MainActor in
                self.activeTasks[item.id] = nil
                self.setState(item, .paused)
                self.startNextIfPossible()
            }
        })
    }

    func resume(_ item: DownloadUIItem) {
        setState(item, .queued)
        startNextIfPossible()
    }

    func delete(_ item: DownloadUIItem) {
        if let task = activeTasks[item.id] {
            task.cancel()
            activeTasks[item.id] = nil
        }
        refetchCounts[item.id] = nil
        coverLoader.cancel(key: item.id)
        DownloadFileStore.removeFiles(videoCode: item.videoCode, quality: item.quality)
        store?.delete(videoCode: item.videoCode, quality: item.quality)
        reloadItems()
        startNextIfPossible()
    }

    // MARK: - Scheduling

    private func startNextIfPossible() {
        guard let store else { return }
        while activeTasks.count < maxConcurrent {
            // Pick the oldest queued row that isn't already active.
            guard let next = DownloadScheduler.nextQueuedItem(
                from: store.all(),
                excluding: Set(activeTasks.keys)
            ) else { return }
            start(next)
        }
    }

    private func start(_ item: DownloadItem) {
        let key = "\(item.videoCode)|\(item.quality)"
        let task: URLSessionDownloadTask
        if let resumeData = DownloadFileStore.consumeResumeData(videoCode: item.videoCode, quality: item.quality) {
            task = session.downloadTask(withResumeData: resumeData)
        } else {
            guard let url = URL(string: item.remoteUrl) else {
                store?.updateState(videoCode: item.videoCode, quality: item.quality, state: Int32(DownloadState.failed.rawValue))
                reloadItems()
                return
            }
            var request = URLRequest(url: url)
            DownloadRequestHeaders.apply(to: &request)
            task = session.downloadTask(with: request)
        }
        task.taskDescription = key
        activeTasks[key] = task
        store?.updateState(videoCode: item.videoCode, quality: item.quality, state: Int32(DownloadState.downloading.rawValue))
        reloadItems()
        task.resume()
    }

    /// Rebind any tasks already created by this foreground session instance.
    private func reattachRunningTasks() {
        session.getAllTasks { [weak self] tasks in
            Task { @MainActor in
                guard let self else { return }
                for case let dl as URLSessionDownloadTask in tasks {
                    if let key = dl.taskDescription {
                        self.activeTasks[key] = dl
                    }
                }
            }
        }
    }

    private func resetOrphanedDownloadingRows() {
        guard let store else { return }
        for row in store.all() where row.state == Int32(DownloadState.downloading.rawValue) {
            let key = "\(row.videoCode)|\(row.quality)"
            if activeTasks[key] == nil {
                store.updateState(videoCode: row.videoCode, quality: row.quality, state: Int32(DownloadState.queued.rawValue))
            }
        }
        reloadItems()
    }

    // MARK: - Persistent covers

    private func restoreMissingCovers() {
        guard let store else { return }
        for item in store.all() where !FileManager.default.fileExists(
            atPath: DownloadFileStore.coverURL(videoCode: item.videoCode, quality: item.quality).path
        ) {
            scheduleCoverDownload(for: item)
        }
    }

    private func scheduleCoverDownload(for item: DownloadItem) {
        coverLoader.schedule(
            item: item,
            isStillPresent: { [weak self] in
                self?.store?.find(videoCode: item.videoCode, quality: item.quality) != nil
            },
            onSaved: { [weak self] in self?.reloadItems() }
        )
    }

    // MARK: - URL re-fetch (CDN link expiry fallback)

    /// Re-resolves the video page to get a fresh CDN URL for the given
    /// quality, updates the stored remote_url, and re-queues. Used when a
    /// download fails (e.g. the cached URL's token expired during a long
    /// pause).
    private func refetchAndRequeue(_ key: String) {
        guard let store else { return }
        let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let (videoCode, quality) = (parts[0], parts[1])
        Task {
            do {
                guard let freshURL = try await urlRefresher.freshURL(
                    videoCode: videoCode,
                    quality: quality
                ) else {
                    store.updateState(videoCode: videoCode, quality: quality, state: Int32(DownloadState.failed.rawValue))
                    reloadItems()
                    return
                }
                store.updateRemoteUrl(videoCode: videoCode, quality: quality, remoteUrl: freshURL)
                store.updateState(videoCode: videoCode, quality: quality, state: Int32(DownloadState.queued.rawValue))
                reloadItems()
                startNextIfPossible()
            } catch {
                store.updateState(videoCode: videoCode, quality: quality, state: Int32(DownloadState.failed.rawValue))
                reloadItems()
            }
        }
    }

    // MARK: - Store sync

    private func setState(_ item: DownloadUIItem, _ state: DownloadState) {
        store?.updateState(videoCode: item.videoCode, quality: item.quality, state: Int32(state.rawValue))
        reloadItems()
    }

    private func reloadItems() {
        guard let store else { return }
        items = store.all().map { row in
            DownloadUIItem(
                videoCode: row.videoCode,
                quality: row.quality,
                title: row.title,
                coverUrl: row.coverUrl,
                localPath: row.localPath,
                totalBytes: row.totalBytes,
                downloadedBytes: row.downloadedBytes,
                state: DownloadState(rawValue: Int(row.state)) ?? .queued,
                addedAtEpochMillis: row.addedAtEpochMillis
            )
        }
    }

}

// MARK: - MainActor handlers (called from the URLSession delegate queue)

extension DownloadManager {
    /// Progress tick. MainActor-only; touches the store + published list.
    func handleProgress(key: String, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        store?.updateProgress(
            videoCode: parts[0],
            quality: parts[1],
            downloadedBytes: totalBytesWritten,
            totalBytes: max(totalBytesExpectedToWrite, 0),
            state: Int32(DownloadState.downloading.rawValue)
        )
        reloadItems()
    }

    /// Task completion. MainActor-only.
    func handleCompletion(key: String, httpStatus: Int?, error: NSError?) {
        let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        activeTasks[key] = nil
        if let error {
            // Explicit user-cancel produced resume data → already paused;
            // don't overwrite that state.
            if error.code == NSURLErrorCancelled {
                startNextIfPossible()
                return
            }
            // Only a CDN-link-expiry-class failure warrants re-resolving
            // the video page. Other failures (no network, etc.) just fail
            // so we don't loop. Cap refetches per item.
            let count = refetchCounts[key] ?? 0
            if DownloadURLRefresher.isLinkExpiry(status: httpStatus, error: error) && count < maxRefetchAttempts {
                refetchCounts[key] = count + 1
                AppLogger.log("download link-expiry v=\(parts[0]) q=\(parts[1]) status=\(httpStatus ?? -1) attempt=\(count + 1); refetching")
                refetchAndRequeue(key)
            } else {
                AppLogger.log("download failed v=\(parts[0]) q=\(parts[1]) status=\(httpStatus ?? -1) code=\(error.code); giving up")
                store?.updateState(
                    videoCode: parts[0],
                    quality: parts[1],
                    state: Int32(DownloadState.failed.rawValue)
                )
                reloadItems()
                startNextIfPossible()
            }
        } else {
            AppLogger.log("download finished v=\(parts[0]) q=\(parts[1])")
            refetchCounts[key] = nil
            store?.updateState(
                videoCode: parts[0],
                quality: parts[1],
                state: Int32(DownloadState.finished.rawValue)
            )
            reloadItems()
            startNextIfPossible()
        }
    }

}
