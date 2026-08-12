import Foundation
import ImageIO
import Han1meShared

enum DownloadRequestHeaders {
    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    static func apply(to request: inout URLRequest) {
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("\(AppDomain.currentBaseURL)/", forHTTPHeaderField: "Referer")
    }
}

@MainActor
final class DownloadCoverLoader {
    private var tasks: [String: Task<Void, Never>] = [:]

    func schedule(
        item: DownloadItem,
        isStillPresent: @escaping @MainActor () -> Bool,
        onSaved: @escaping @MainActor () -> Void
    ) {
        let key = "\(item.videoCode)|\(item.quality)"
        guard tasks[key] == nil,
              let coverUrl = item.coverUrl,
              let url = URL(string: coverUrl) else { return }

        tasks[key] = Task { [weak self] in
            defer { self?.tasks[key] = nil }
            do {
                var request = URLRequest(url: url)
                DownloadRequestHeaders.apply(to: &request)
                let (data, response) = try await URLSession.shared.data(for: request)
                try Task.checkCancellation()
                if let http = response as? HTTPURLResponse,
                   !(200...299).contains(http.statusCode) {
                    throw URLError(.badServerResponse)
                }
                guard !data.isEmpty,
                      CGImageSourceCreateWithData(data as CFData, nil) != nil,
                      isStillPresent() else { return }

                try data.write(
                    to: DownloadFileStore.coverURL(videoCode: item.videoCode, quality: item.quality),
                    options: .atomic
                )
                AppLogger.log("download cover saved v=\(item.videoCode) q=\(item.quality)")
                onSaved()
            } catch is CancellationError {
                return
            } catch {
                AppLogger.log("download cover failed v=\(item.videoCode) q=\(item.quality): \(ErrorMessage.userFriendly(error))")
            }
        }
    }

    func cancel(key: String) {
        tasks[key]?.cancel()
        tasks[key] = nil
    }
}
