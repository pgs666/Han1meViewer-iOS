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
    private var sessionTask: Task<Void, Never>?
    private var profileTask: Task<Void, Never>?
    private var logoutTask: Task<Void, Never>?
    private var requestGeneration = 0

    init(webLoginFeature: WebLoginFeature, homeFeature: HomeFeature) {
        self.webLoginFeature = webLoginFeature
        self.homeFeature = homeFeature
    }

    deinit {
        sessionTask?.cancel()
        profileTask?.cancel()
        logoutTask?.cancel()
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
        sessionTask?.cancel()
        profileTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        sessionTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if generation == requestGeneration {
                    isCheckingLogin = false
                }
            }
            do {
                let session = try await webLoginFeature.currentSessionSnapshot()
                guard !Task.isCancelled, generation == requestGeneration else { return }
                isLoggedIn = session.isLoggedIn
                if session.isLoggedIn {
                    await loadProfile(generation: generation)
                } else {
                    profile = MineProfileSnapshot()
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, generation == requestGeneration else { return }
                CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
                errorMessage = ErrorMessage.userFriendly(error)
            }
        }
    }

    func markLoggedIn() {
        didLoadLoginState = true
        isLoggedIn = true
        profileTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        profileTask = Task { [weak self] in
            await self?.loadProfile(generation: generation)
        }
    }

    func logout(clearWebViewCookies: @escaping () async -> Void, onSuccess: @escaping () -> Void) {
        guard !isCheckingLogin else {
            return
        }

        isCheckingLogin = true
        errorMessage = nil
        sessionTask?.cancel()
        profileTask?.cancel()
        logoutTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        logoutTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if generation == requestGeneration {
                    isCheckingLogin = false
                }
            }
            do {
                _ = try await webLoginFeature.logout()
                await clearWebViewCookies()
                guard !Task.isCancelled else { return }
                didLoadLoginState = true
                isLoggedIn = false
                profile = MineProfileSnapshot()
                onSuccess()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
                errorMessage = ErrorMessage.userFriendly(error)
            }
        }
    }

    private func loadProfile(generation: Int) async {
        do {
            let home = try await homeFeature.loadHome()
            guard !Task.isCancelled, generation == requestGeneration else { return }
            profile = MineProfileSnapshot(
                username: home.username,
                avatarUrl: home.avatarUrl
            )
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, generation == requestGeneration else { return }
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
