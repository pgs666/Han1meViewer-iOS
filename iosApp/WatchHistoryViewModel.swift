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

    init(watchHistoryFeature: WatchHistoryFeature) {
        self.watchHistoryFeature = watchHistoryFeature
    }

    func loadIfNeeded() {
        guard case .idle = state else {
            return
        }
        load()
    }

    func load() {
        do {
            let snapshot = watchHistoryFeature.loadRecent()
            state = .loaded(WatchHistoryScreenSnapshot(snapshot))
        } catch {
            state = .failed(ErrorMessage.userFriendly(error))
        }
    }

    func delete(videoCode: String) {
        do {
            let snapshot = watchHistoryFeature.delete(videoCode: videoCode)
            state = .loaded(WatchHistoryScreenSnapshot(snapshot))
        } catch {
            state = .failed(ErrorMessage.userFriendly(error))
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
