import Foundation
import Han1meShared

/// Provides Swift-native async waiting for Cloudflare challenge resolution.
/// Works with [CloudflareRetryHandler] in the shared layer.
enum CloudflareRetryCenter {
    private static let resolutionNotification = Notification.Name("Han1meViewerCloudflareResolved")
    private static let failureNotification = Notification.Name("Han1meViewerCloudflareFailed")
    private static let failureReasonKey = "reason"

    /// Waits for the current CF challenge to be resolved.
    /// Returns `true` if resolved successfully, `false` if failed.
    static func waitForResolution() async -> Bool {
        // Wait for either resolution or failure notification
        let result = await withUnsafeContinuation { (continuation: UnsafeContinuation<Bool, Never>) in
            var token1: NSObjectProtocol?
            var token2: NSObjectProtocol?
            
            token1 = NotificationCenter.default.addObserver(
                forName: resolutionNotification,
                object: nil,
                queue: .main
            ) { _ in
                if let token = token1 { NotificationCenter.default.removeObserver(token) }
                if let token = token2 { NotificationCenter.default.removeObserver(token) }
                continuation.resume(returning: true)
            }
            
            token2 = NotificationCenter.default.addObserver(
                forName: failureNotification,
                object: nil,
                queue: .main
            ) { _ in
                if let token = token1 { NotificationCenter.default.removeObserver(token) }
                if let token = token2 { NotificationCenter.default.removeObserver(token) }
                continuation.resume(returning: false)
            }
        }
        return result
    }

    /// Called by CloudflareChallengeView when CF challenge is resolved.
    static func signalResolved() {
        // Signal KMP handler
        CloudflareRetryHandler.shared.signalResolved()
        // Signal Swift waiters
        NotificationCenter.default.post(name: resolutionNotification, object: nil)
    }

    /// Called when CF challenge fails.
    static func signalFailed(reason: String) {
        CloudflareRetryHandler.shared.signalFailed(reason: reason)
        NotificationCenter.default.post(
            name: failureNotification,
            object: nil,
            userInfo: [failureReasonKey: reason]
        )
    }

    /// Wraps a throwing async block with Cloudflare auto-retry.
    /// If the block throws a Cloudflare error, shows the challenge UI and retries after resolution.
    static func retryOnCloudflare<T>(
        challengeURL: URL? = nil,
        block: @escaping () async throws -> T
    ) async throws -> T {
        do {
            return try await block()
        } catch {
            guard DomainErrorCode.isCloudflare(error) else {
                throw error
            }
            
            // Show CF challenge UI
            CloudflareChallengeCenter.requestChallenge()
            
            // Wait for resolution
            let resolved = await waitForResolution()
            guard resolved else {
                throw error
            }
            
            // Retry
            return try await block()
        }
    }
}
