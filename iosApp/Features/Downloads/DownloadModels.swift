import Foundation

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

    var localCoverURL: URL {
        DownloadFileStore.coverURL(videoCode: videoCode, quality: quality)
    }
}
