import Foundation
import Han1meShared

/// Mirror of the shared DownloadStore's integer state mapping.
enum DownloadState: Int {
    case queued = 0
    case downloading = 1
    case paused = 2
    case finished = 3
    case failed = 4
}

/// Swift-side view of a download row. Decoupled from the KMP `DownloadItem`
/// so SwiftUI views don't import shared types directly.
struct DownloadUIItem: Identifiable, Equatable {
    let videoCode: String
    let quality: String
    let title: String
    let coverUrl: String?
    let localPath: String
    var totalBytes: Int64
    var downloadedBytes: Int64
    var state: DownloadState
    let addedAtEpochMillis: Int64

    var id: String { "\(videoCode)|\(quality)" }

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, Double(downloadedBytes) / Double(totalBytes))
    }

    var isFinished: Bool { state == .finished }

    var localFileURL: URL { URL(fileURLWithPath: localPath) }
}

/// Owns the actual byte transfer for downloads via a background
/// URLSession, persists metadata to the KMP-shared DownloadStore, limits
/// concurrency, and exposes an observable list for the UI.
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

    /// Background-session completion handler handed to us by the
    /// AppDelegate; invoked once all background events are processed.
    var backgroundCompletionHandler: (() -> Void)?

    private var environment: SharedAppEnvironment?
    private var store: DownloadStore?
    private var videoFeature: VideoFeature?

    /// videoCode|quality -> in-flight task.
    private var activeTasks: [String: URLSessionDownloadTask] = [:]

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.han1meviewer.downloads")
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private var maxConcurrent: Int {
        max(1, Int(environment?.preferences().maxConcurrentDownloads.get() ?? 2))
    }

    private override init() {
        super.init()
    }

    /// Wire up the shared environment. Called once at app launch. Also
    /// reattaches to any tasks the background session is still running
    /// from a previous launch.
    func configure(environment: SharedAppEnvironment) {
        guard self.environment == nil else { return }
        self.environment = environment
        self.store = environment.downloadStore()
        self.videoFeature = environment.videoFeature()
        reloadItems()
        reattachRunningTasks()
        // Anything left 'downloading' in the DB without a live task (app
        // was killed) is reset to queued so the scheduler picks it up.
        resetOrphanedDownloadingRows()
        startNextIfPossible()
    }

    // MARK: - Public actions

    func enqueue(videoCode: String, quality: String, title: String, coverUrl: String?, remoteUrl: String) {
        guard let store else { return }
        let localPath = Self.localFileURL(videoCode: videoCode, quality: quality).path
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
                try? data.write(to: Self.resumeDataURL(videoCode: item.videoCode, quality: item.quality))
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
        try? FileManager.default.removeItem(at: item.localFileURL)
        try? FileManager.default.removeItem(at: Self.resumeDataURL(videoCode: item.videoCode, quality: item.quality))
        store?.delete(videoCode: item.videoCode, quality: item.quality)
        reloadItems()
        startNextIfPossible()
    }

    // MARK: - Scheduling

    private func startNextIfPossible() {
        guard let store else { return }
        while activeTasks.count < maxConcurrent {
            // Pick the oldest queued row that isn't already active.
            let queued = store.all()
                .filter { $0.state == Int32(DownloadState.queued.rawValue) && activeTasks["\($0.videoCode)|\($0.quality)"] == nil }
                .sorted { $0.addedAtEpochMillis < $1.addedAtEpochMillis }
            guard let next = queued.first else { return }
            start(next)
        }
    }

    private func start(_ item: DownloadItem) {
        let key = "\(item.videoCode)|\(item.quality)"
        let task: URLSessionDownloadTask
        let resumeURL = Self.resumeDataURL(videoCode: item.videoCode, quality: item.quality)
        if let resumeData = try? Data(contentsOf: resumeURL) {
            task = session.downloadTask(withResumeData: resumeData)
            try? FileManager.default.removeItem(at: resumeURL)
        } else {
            guard let url = URL(string: item.remoteUrl) else {
                store?.updateState(videoCode: item.videoCode, quality: item.quality, state: Int32(DownloadState.failed.rawValue))
                reloadItems()
                return
            }
            var request = URLRequest(url: url)
            request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("https://hanime1.me/", forHTTPHeaderField: "Referer")
            task = session.downloadTask(with: request)
        }
        task.taskDescription = key
        activeTasks[key] = task
        store?.updateState(videoCode: item.videoCode, quality: item.quality, state: Int32(DownloadState.downloading.rawValue))
        reloadItems()
        task.resume()
    }

    /// On a finished/cancelled background task the system may have already
    /// recreated tasks; rebind them to our activeTasks map by taskDescription.
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

    // MARK: - URL re-fetch (CDN link expiry fallback)

    /// Re-resolves the video page to get a fresh CDN URL for the given
    /// quality, updates the stored remote_url, and re-queues. Used when a
    /// download fails (e.g. the cached URL's token expired during a long
    /// pause).
    private func refetchAndRequeue(_ key: String) {
        guard let store, let videoFeature else { return }
        let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let (videoCode, quality) = (parts[0], parts[1])
        Task {
            do {
                let snapshot = try await videoFeature.loadVideo(videoCode: videoCode)
                let count = Int(snapshot.playbackSourceCount())
                var match: VideoPlaybackSourceSnapshot?
                for i in 0..<count {
                    if let s = snapshot.playbackSourceAt(index: Int32(i)), s.label == quality {
                        match = s
                        break
                    }
                }
                if match == nil { match = snapshot.playbackSourceAt(index: 0) }
                guard let fresh = match else {
                    store.updateState(videoCode: videoCode, quality: quality, state: Int32(DownloadState.failed.rawValue))
                    reloadItems()
                    return
                }
                store.updateRemoteUrl(videoCode: videoCode, quality: quality, remoteUrl: fresh.url)
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

    // MARK: - Paths

    nonisolated static func downloadsRoot() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    nonisolated static func localFileURL(videoCode: String, quality: String) -> URL {
        downloadsRoot().appendingPathComponent("\(videoCode)_\(quality).mp4")
    }

    nonisolated static func resumeDataURL(videoCode: String, quality: String) -> URL {
        downloadsRoot().appendingPathComponent("\(videoCode)_\(quality).resume")
    }

    nonisolated private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let key = downloadTask.taskDescription else { return }
        let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        Task { @MainActor in
            self.store?.updateProgress(
                videoCode: parts[0],
                quality: parts[1],
                downloadedBytes: totalBytesWritten,
                totalBytes: max(totalBytesExpectedToWrite, 0),
                state: Int32(DownloadState.downloading.rawValue)
            )
            self.reloadItems()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let key = downloadTask.taskDescription else { return }
        let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let dest = Self.localFileURL(videoCode: parts[0], quality: parts[1])
        // Must move the file synchronously inside this callback — the temp
        // file is deleted as soon as we return.
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.moveItem(at: location, to: dest)
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let key = task.taskDescription else { return }
        let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        Task { @MainActor in
            self.activeTasks[key] = nil
            if let error = error as NSError? {
                // Explicit user-cancel produced resume data → already paused;
                // don't overwrite that state.
                if error.code == NSURLErrorCancelled {
                    self.startNextIfPossible()
                    return
                }
                // Other failure → try a URL re-fetch once (covers expired
                // CDN tokens after a long pause), which re-queues on success.
                self.refetchAndRequeue(key)
            } else {
                self.store?.updateState(
                    videoCode: parts[0],
                    quality: parts[1],
                    state: Int32(DownloadState.finished.rawValue)
                )
                self.reloadItems()
                self.startNextIfPossible()
            }
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}
