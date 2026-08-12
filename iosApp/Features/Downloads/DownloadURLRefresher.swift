import Foundation
import Han1meShared

@MainActor
final class DownloadURLRefresher {
    private var videoFeature: VideoFeature?

    func configure(videoFeature: VideoFeature) {
        self.videoFeature = videoFeature
    }

    func freshURL(videoCode: String, quality: String) async throws -> String? {
        guard let videoFeature else { return nil }
        let snapshot = try await videoFeature.loadVideo(videoCode: videoCode)
        let sources = (0..<Int(snapshot.playbackSourceCount())).compactMap {
            snapshot.playbackSourceAt(index: Int32($0))
        }
        return sources.first(where: { $0.label == quality })?.url ?? sources.first?.url
    }

    nonisolated static func isLinkExpiry(status: Int?, error: NSError) -> Bool {
        if let status, status == 403 || status == 404 || status == 410 {
            return true
        }
        switch error.code {
        case NSURLErrorResourceUnavailable,
             NSURLErrorFileDoesNotExist,
             NSURLErrorBadServerResponse,
             NSURLErrorTimedOut:
            return true
        default:
            return false
        }
    }
}
