import Foundation

enum CloudflareChallengeCenter {
    static let requestNotification = Notification.Name("Han1meViewerCloudflareChallengeRequested")
    static let urlKey = "url"

    static func requestChallengeIfNeeded(for error: Error) {
        let lowercased = error.localizedDescription.lowercased()
        if lowercased.contains("cloudflare") || lowercased.contains("cf-mitigated") {
            requestChallenge()
        }
    }

    static func requestChallenge(url: URL = URL(string: "https://hanime1.me")!) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: requestNotification,
                object: nil,
                userInfo: [urlKey: url]
            )
        }
    }
}
