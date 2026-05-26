import Foundation
import Han1meShared

enum CloudflareChallengeCenter {
    static let requestNotification = Notification.Name("Han1meViewerCloudflareChallengeRequested")
    static let urlKey = "url"
    private static let defaultChallengeURLString = "https://hanime1.me"

    static func requestChallengeIfNeeded(for error: Error) {
        let lowercased = error.localizedDescription.lowercased()
        if lowercased.contains("cloudflare") || lowercased.contains("cf-mitigated") {
            requestChallenge()
        }
    }

    static func requestChallenge() {
        guard let url = URL(string: defaultChallengeURLString) else {
            return
        }
        requestChallenge(url: url)
    }

    static func requestChallenge(url: URL) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: requestNotification,
                object: nil,
                userInfo: [urlKey: url]
            )
        }
    }

    /// Called when the CF challenge is resolved successfully.
    /// This signals the shared layer to retry the failed request.
    static func signalChallengeResolved() {
        CloudflareRetryHandler.shared.signalResolved()
    }

    /// Called when the CF challenge fails.
    /// This signals the shared layer that the challenge failed.
    static func signalChallengeFailed(reason: String) {
        CloudflareRetryHandler.shared.signalFailed(reason: reason)
    }
}
