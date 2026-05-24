import Foundation
import Han1meShared

@MainActor
final class MineViewModel: ObservableObject {
    @Published private(set) var isLoggedIn = false
    @Published private(set) var isCheckingLogin = false
    @Published private(set) var profile = MineProfileSnapshot()
    @Published private(set) var errorMessage: String?

    private let webLoginFeature: WebLoginFeature
    private let homeFeature: HomeFeature
    private var didLoadLoginState = false

    init(webLoginFeature: WebLoginFeature, homeFeature: HomeFeature) {
        self.webLoginFeature = webLoginFeature
        self.homeFeature = homeFeature
    }

    func refreshLoginState(force: Bool = false) {
        guard !isCheckingLogin else {
            return
        }
        guard force || !didLoadLoginState else {
            return
        }

        didLoadLoginState = true
        isCheckingLogin = true
        errorMessage = nil
        Task {
            do {
                let session = try await webLoginFeature.currentSessionSnapshot()
                isLoggedIn = session.isLoggedIn
                if session.isLoggedIn {
                    await loadProfile()
                } else {
                    profile = MineProfileSnapshot()
                }
                isCheckingLogin = false
            } catch {
                CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
                errorMessage = ErrorMessage.userFriendly(error)
                isCheckingLogin = false
            }
        }
    }

    func markLoggedIn() {
        didLoadLoginState = true
        isLoggedIn = true
        Task {
            await loadProfile()
        }
    }

    func logout(clearWebViewCookies: @escaping () async -> Void, onSuccess: @escaping () -> Void) {
        guard !isCheckingLogin else {
            return
        }

        isCheckingLogin = true
        errorMessage = nil
        Task {
            do {
                _ = try await webLoginFeature.logout()
                await clearWebViewCookies()
                didLoadLoginState = true
                isLoggedIn = false
                profile = MineProfileSnapshot()
                isCheckingLogin = false
                onSuccess()
            } catch {
                CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
                errorMessage = ErrorMessage.userFriendly(error)
                isCheckingLogin = false
            }
        }
    }

    private func loadProfile() async {
        do {
            let home = try await homeFeature.loadHome()
            profile = MineProfileSnapshot(
                username: home.username,
                avatarUrl: home.avatarUrl
            )
        } catch {
            CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
            errorMessage = ErrorMessage.userFriendly(error)
        }
    }
}

struct MineProfileSnapshot {
    let username: String?
    let avatarUrl: String?

    init(username: String? = nil, avatarUrl: String? = nil) {
        self.username = username
        self.avatarUrl = avatarUrl
    }
}
