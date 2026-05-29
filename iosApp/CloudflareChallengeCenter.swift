import Foundation
import Han1meShared

enum CloudflareChallengeCenter {
    static let requestNotification = Notification.Name("Han1meViewerCloudflareChallengeRequested")
    static let urlKey = "url"
    private static let defaultChallengeURLString = "https://hanime1.me"

    static func requestChallengeIfNeeded(for error: Error) {
        if DomainErrorCode.isCloudflare(error) {
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
}
