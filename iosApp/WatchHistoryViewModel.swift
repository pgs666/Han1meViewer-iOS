import Foundation
import Han1meShared

@MainActor
final class WatchHistoryViewModel: ObservableObject {
    enum State {
        case idle
        case loaded(WatchHistoryScreenSnapshot)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let watchHistoryFeature: WatchHistoryFeature
    private var loadTask: Task<Void, Never>?
    private var requestGeneration = 0

    init(watchHistoryFeature: WatchHistoryFeature) {
        self.watchHistoryFeature = watchHistoryFeature
    }

    deinit {
        loadTask?.cancel()
    }

    func loadIfNeeded() {
        guard case .idle = state else {
            return
        }
        load()
    }

    func load() {
        loadTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        let feature = watchHistoryFeature
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = await Task.detached {
                    feature.loadRecent()
                }.value
                guard !Task.isCancelled, generation == requestGeneration else { return }
                state = .loaded(WatchHistoryScreenSnapshot(snapshot))
            } catch {
                guard !Task.isCancelled, generation == requestGeneration else { return }
                CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
                state = .failed(ErrorMessage.userFriendly(error))
            }
        }
    }

    func delete(videoCode: String) {
        loadTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        let feature = watchHistoryFeature
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = await Task.detached {
                    feature.delete(videoCode: videoCode)
                }.value
                guard !Task.isCancelled, generation == requestGeneration else { return }
                state = .loaded(WatchHistoryScreenSnapshot(snapshot))
            } catch {
                guard !Task.isCancelled, generation == requestGeneration else { return }
                CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
                state = .failed(ErrorMessage.userFriendly(error))
            }
        }
    }
}

struct WatchHistoryScreenSnapshot {
    let items: [WatchHistoryRow]

    init(_ snapshot: WatchHistorySnapshot) {
        let count = Int(snapshot.itemCount())
        items = (0..<count).compactMap { index in
            guard let item = snapshot.itemAt(index: Int32(index)) else {
                return nil
            }
            return WatchHistoryRow(
                videoCode: item.videoCode,
                title: item.title,
                coverUrl: item.coverUrl,
                watchedAtEpochMillis: item.watchedAtEpochMillis,
                playbackPositionMillis: item.playbackPositionMillis
            )
        }
    }
}

struct WatchHistoryRow: Identifiable {
    let videoCode: String
    let title: String
    let coverUrl: String?
    let watchedAtEpochMillis: Int64
    let playbackPositionMillis: Int64

    var id: String { videoCode }

    var watchedAtText: String {
        let date = Date(timeIntervalSince1970: TimeInterval(watchedAtEpochMillis) / 1000)
        return WatchHistoryRow.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
